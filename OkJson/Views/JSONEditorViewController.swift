//  JSONEditorViewController.swift
//  OkJson
//
//  每列的 JSON 文本编辑器控制器（重构后取代树形 UnifiedJsonViewController 的显示职责）。
//  布局：左侧独立行号视图 + 右侧滚动文本区（不使用 NSRulerView）。
//  功能：粘贴/打开自动格式化、手敲实时校验、非法 JSON 错误行标红 + 底栏提示、
//        语法高亮、原生查找栏、底栏设置(缩进/排序/行号/主题)响应。

import AppKit

final class JSONEditorViewController: NSViewController, NSTextViewDelegate {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONEditorTextView!
    private var lineNumberView: EditorLineNumberView?
    private var gutterWidthConstraint: NSLayoutConstraint?
    private var errorBar: EditorErrorBar!
    private var headerView: ColumnHeaderView!

    /// 点击获得焦点回调
    var onFocusRequest: (() -> Void)?

    /// 关闭列回调（由 FormatterViewController 转发到 MainViewController.removeColumn）
    var onCloseRequest: (() -> Void)?

    private var debounceTimer: Timer?
    /// 粘贴/打开后置 true：下一次处理会自动格式化（手敲不置）
    private var pendingAutoFormat = false
    /// 程序化设置文本时为 true：不触发自动处理
    private var isApplyingProgrammaticText = false
    /// 当前是否有错误行高亮：避免无错误的常见路径上也做全文档属性清除
    private var hasErrorHighlight = false

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
        // 防止超长不折行内容把列撑宽：内容宽度不参与外层分栏尺寸竞争
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)

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
        textView.onOpenFile = { [weak self] path in
            _ = (self?.view.window?.windowController as? MainWindowController)?.openFile(path)
        }
        textView.onBecomeFirstResponder = { [weak self] in self?.onFocusRequest?() }
        self.textView = textView
        viewModel.editorTextProvider = { [weak textView] in textView?.string ?? "" }

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

        // 列头：文件名(可编辑) + 关闭× + 颜色标记，复用 ColumnHeaderView
        let header = ColumnHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.title = viewModel.columnTitle
        header.onClose = { [weak self] in self?.onCloseRequest?() }
        header.onTitleChanged = { [weak self] newTitle in self?.viewModel.columnTitle = newTitle }
        header.onColorChanged = { [weak self] color in self?.viewModel.columnColor = color }
        self.headerView = header
        header.setCloseVisible(closeButtonVisible)
        viewModel.onColumnMetadataChanged = { [weak self] in
            guard let self = self else { return }
            let dot = self.viewModel.isModifiedSinceFileOpen ? "● " : ""
            self.headerView.title = dot + self.viewModel.columnTitle
        }

        container.addSubview(header)
        container.addSubview(gutter)
        container.addSubview(scrollView)
        container.addSubview(errorBar)
        let gutterWidth = gutter.widthAnchor.constraint(equalToConstant: 44)
        self.gutterWidthConstraint = gutterWidth
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 28),

            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: header.bottomAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterWidth,
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            errorBar.heightAnchor.constraint(equalToConstant: 26)
        ])

        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.view = container
        gutter.startObserving()
        applyDisplaySettings()
        registerSettingObservers()
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
        applyHighlight()
        lineNumberView?.needsDisplay = true
    }

    /// 打开文件用：先同步显示原文（瞬间可见，杜绝"先空白再渲染"），
    /// 再后台格式化合法 JSON 后回填；非法则保留原文并标红、弹错误条。
    func loadContent(_ content: String) {
        setText(content)
        pendingAutoFormat = true
        processText()
    }

    /// 关闭按钮目标显隐状态（视图加载前先记住，加载后在 loadView 应用）
    private var closeButtonVisible = false

    /// 设置列头关闭按钮显隐（多列显示，单列隐藏）
    func setCloseButtonVisible(_ visible: Bool) {
        closeButtonVisible = visible
        headerView?.setCloseVisible(visible)
    }

    /// 清空编辑器内容
    func clearContent() {
        setText("")
    }

    /// 重新格式化当前文本（菜单 Format ⌘R）：合法 JSON 才格式化、回填
    func formatCurrent() {
        pendingAutoFormat = true
        processText()
    }

    /// 估算内容宽度（最长行）用于自适应列宽。文本视图非折行，其布局宽度即最长行宽。
    func estimatedContentWidth() -> CGFloat {
        let textWidth = textView.frame.width
        let gutter = gutterWidthConstraint?.constant ?? 0
        return textWidth + gutter + 40
    }

    /// 唤出/操作原生查找栏。每次都先把 textView 设为 first responder，
    /// 确保关闭查找栏后仍能反复用 ⌘F 唤出。action: 1=显示查找 2=下一个 3=上一个
    func showFind(_ action: Int) {
        view.window?.makeFirstResponder(textView)
        let item = NSMenuItem()
        item.tag = action
        textView.performTextFinderAction(item)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isApplyingProgrammaticText else { return }
        lineNumberView?.needsDisplay = true
        viewModel.markAsModified()
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
        let indent = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.indentation) == 4 ? 4 : 2
        let sortKeys = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.sortKeys)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let err = JSONParser.shared.parseError(from: text)
            // 合法 + 粘贴/打开态 → 自动美化（缩进/排序按底栏设置；排序默认关，保留原序）
            let formatted: String? = (err == nil && autoFormat)
                ? JSONFormatter.format(text, indent: indent, sortKeys: sortKeys)
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
                    } else {
                        self.applyHighlight()
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
        textView.textStorage?.addAttribute(
            .backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.15), range: lineRange
        )
        hasErrorHighlight = true
        errorBar.show(message: "第 \(error.line) 行：\(error.message)") { [weak self] in
            guard let self = self else { return }
            let target = NSRange(location: offset, length: 0)
            self.textView.setSelectedRange(target)
            self.textView.scrollRangeToVisible(target)
            self.view.window?.makeFirstResponder(self.textView)
        }
    }

    private func clearErrorHighlight() {
        // 仅在确有错误高亮时才清除，避免无错误的常见路径上对大文档做全文档属性清除
        guard hasErrorHighlight else { return }
        hasErrorHighlight = false
        // 错误行红色背景是编辑器文本中 backgroundColor 的唯一用途；全量清除，
        // 避免用编辑后已失真的 range 快照导致红底残留清不掉
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.removeAttribute(.backgroundColor,
                                range: NSRange(location: 0, length: storage.length))
    }

    // MARK: - 语法高亮（全文着色，不访问 textView.layoutManager）

    private func applyHighlight() {
        guard let storage = textView.textStorage else { return }
        let nsLen = (textView.string as NSString).length
        guard nsLen > 0 else { return }
        let dark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let highlights = SyntaxHighlightService.shared.calculateHighlights(for: textView.string, isDark: dark)
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor,
                             range: NSRange(location: 0, length: nsLen))
        for (range, color) in highlights where NSMaxRange(range) <= nsLen {
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
    }

    // MARK: - 底栏设置响应

    private var lineNumbersEnabled: Bool {
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) == nil { return true }
        return UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
    }

    private func applyDisplaySettings() {
        let show = lineNumbersEnabled
        gutterWidthConstraint?.constant = show ? 44 : 0
        lineNumberView?.isHidden = !show
    }

    private func registerSettingObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(onFormatSettingsChanged),
            name: Constants.Notifications.formatSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onThemeChanged),
            name: Constants.Notifications.themeChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onDisplaySettingsChanged),
            name: Constants.Notifications.displaySettingsChanged, object: nil)
    }

    @objc private func onFormatSettingsChanged() {
        let text = textView.string
        guard !text.isEmpty else { return }
        let ind = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.indentation) == 4 ? 4 : 2
        let sort = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.sortKeys)
        if let formatted = JSONFormatter.format(text, indent: ind, sortKeys: sort) {
            setText(formatted)
        }
    }

    @objc private func onThemeChanged() {
        applyHighlight()
        lineNumberView?.needsDisplay = true
    }

    @objc private func onDisplaySettingsChanged() {
        applyDisplaySettings()
    }
}
