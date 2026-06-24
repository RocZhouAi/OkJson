//  JSONEditorViewController.swift
//  OkJson
//
//  每列的 JSON 文本编辑器控制器（重构后取代树形 UnifiedJsonViewController 的显示职责）。
//  集成：行号、视口语法着色、自动格式化(粘贴/打开)、实时校验、错误标记+底栏提示。

import AppKit

final class JSONEditorViewController: NSViewController, NSTextViewDelegate {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONEditorTextView!
    private var errorBar: EditorErrorBar!

    /// 点击获得焦点回调
    var onFocusRequest: (() -> Void)?

    private var debounceTimer: Timer?
    /// 粘贴/打开后置 true：下一次处理会自动格式化（手敲不置）
    private var pendingAutoFormat = false
    /// 程序化设置文本时为 true：不触发自动处理
    private var isApplyingProgrammaticText = false
    /// 当前错误行高亮范围
    private var currentErrorRange: NSRange?

    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    override func loadView() {
        let container = NSView()

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // 手动搭建 TextKit 1 文本栈
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = JSONEditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = self
        textView.onPaste = { [weak self] in self?.pendingAutoFormat = true }
        self.textView = textView
        scrollView.documentView = textView

        // 行号标尺（复用现有 LineNumberRulerView）
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        // 底部错误提示条
        errorBar = EditorErrorBar()
        errorBar.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)
        container.addSubview(errorBar)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.heightAnchor.constraint(equalToConstant: 26)
        ])

        self.view = container

        // 滚动时给新进入可见区的内容着色
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(visibleAreaChanged),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTimer?.invalidate()
    }

    private var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var text: String {
        get { textView.string }
        set { setText(newValue) }
    }

    /// 程序化设置文本（外部回填/格式化结果），不触发自动处理
    func setText(_ value: String) {
        isApplyingProgrammaticText = true
        textView.string = value
        isApplyingProgrammaticText = false
        clearErrorHighlight()
        errorBar.hide()
        applyHighlight()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isApplyingProgrammaticText else { return }
        applyHighlight()        // 即时给可见区上色
        scheduleProcess()       // 防抖后解析/校验/(粘贴时)格式化
    }

    @objc private func visibleAreaChanged() {
        applyHighlight()
    }

    private func scheduleProcess() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.processText()
        }
    }

    private func processText() {
        let text = textView.string
        let autoFormat = pendingAutoFormat
        pendingAutoFormat = false
        let indent = viewModel.indentation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let err = JSONParser.shared.parseError(from: text)
            // 合法 + 粘贴/打开态 → 自动美化（默认不排序，保留原始字段顺序）
            let formatted: String? = (err == nil && autoFormat)
                ? JSONFormatter.format(text, indent: indent, sortKeys: false)
                : nil
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = err {
                    self.showError(err, in: text)
                } else {
                    self.clearErrorHighlight()
                    self.errorBar.hide()
                    if let formatted = formatted, formatted != text {
                        self.setText(formatted)
                    }
                }
            }
        }
    }

    // MARK: - 视口语法着色

    private func applyHighlight() {
        guard let lm = textView.layoutManager,
              let tc = textView.textContainer,
              let storage = textView.textStorage else { return }
        let full = textView.string as NSString
        guard full.length > 0 else { return }

        var rect = textView.visibleRect
        rect = rect.insetBy(dx: 0, dy: -rect.height) // 上下各扩一屏缓冲
        let glyphRange = lm.glyphRange(forBoundingRect: rect, in: tc)
        let range = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard range.length > 0, NSMaxRange(range) <= full.length else { return }

        let sub = full.substring(with: range)
        let highlights = SyntaxHighlightService.shared.calculateHighlights(for: sub, isDark: isDark)

        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        for (r, color) in highlights {
            let abs = NSRange(location: range.location + r.location, length: r.length)
            if NSMaxRange(abs) <= full.length {
                storage.addAttribute(.foregroundColor, value: color, range: abs)
            }
        }
        storage.endEditing()
    }

    // MARK: - 错误标记

    private func showError(_ error: ParseError, in text: String) {
        clearErrorHighlight()
        let ns = text as NSString
        let offset = min(max(0, error.offset), ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: offset, length: 0))
        currentErrorRange = lineRange
        textView.textStorage?.addAttribute(
            .backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.15), range: lineRange
        )
        errorBar.show(message: "第 \(error.line) 行：\(error.message)") { [weak self] in
            guard let self = self else { return }
            let target = NSRange(location: offset, length: 0)
            self.textView.setSelectedRange(target)
            self.textView.scrollRangeToVisible(target)
            self.view.window?.makeFirstResponder(self.textView)
        }
    }

    private func clearErrorHighlight() {
        if let r = currentErrorRange,
           let storage = textView.textStorage,
           NSMaxRange(r) <= storage.length {
            storage.removeAttribute(.backgroundColor, range: r)
        }
        currentErrorRange = nil
    }
}
