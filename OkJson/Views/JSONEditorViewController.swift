//  JSONEditorViewController.swift
//  OkJson
//
//  每列的 JSON 文本编辑器控制器（重构后取代树形 UnifiedJsonViewController 的显示职责）。
//  布局：左侧独立行号视图 + 右侧滚动文本区（不使用 NSRulerView）。
//  功能：粘贴/打开自动格式化、手敲实时校验、非法 JSON 错误行标红 + 底栏提示。

import AppKit

final class JSONEditorViewController: NSViewController, NSTextViewDelegate {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONEditorTextView!
    private var lineNumberView: EditorLineNumberView?
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
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        let textView = JSONEditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        textView.onPaste = { [weak self] in self?.pendingAutoFormat = true }
        self.textView = textView

        scrollView.documentView = textView
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        let gutter = EditorLineNumberView()
        gutter.translatesAutoresizingMaskIntoConstraints = false
        gutter.textView = textView
        gutter.scrollView = scrollView
        self.lineNumberView = gutter

        errorBar = EditorErrorBar()
        errorBar.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(gutter)
        container.addSubview(scrollView)
        container.addSubview(errorBar)
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: 44),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.heightAnchor.constraint(equalToConstant: 26)
        ])

        self.view = container
        gutter.startObserving()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTimer?.invalidate()
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
        textView.textColor = .labelColor
        clearErrorHighlight()
        errorBar.hide()
        lineNumberView?.needsDisplay = true
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isApplyingProgrammaticText else { return }
        lineNumberView?.needsDisplay = true
        scheduleProcess()
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
