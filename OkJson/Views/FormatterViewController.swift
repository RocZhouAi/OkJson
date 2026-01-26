//  FormatterViewController.swift
//  OkJson
//
//  JSON formatter view controller - Pure AppKit

import AppKit

class FormatterViewController: NSSplitViewController {
    
    // MARK: - Properties
    
    private var inputViewController: InputViewController!
    private var outputViewController: OutputViewController!
    let viewModel = FormatterViewModel()
    
    /// Optional custom orientation (default is vertical)
    var initialOrientation: NSUserInterfaceLayoutOrientation?
    
    /// Whether to sort keys (default is false)

    var shouldSortKeys: Bool = false {
        didSet {
            viewModel.sortKeys = shouldSortKeys
        }
    }
    
    /// Unified mode: Input only, auto-format on paste, replace input text
    var isUnifiedMode: Bool = false
    
    /// Optional: Prefer displaying Tree View even in Unified Mode (for Comparison View)
    var preferTreeInUnifiedMode: Bool = false
    
    var mainScrollView: NSScrollView? {
        // If Output is visible (Tree View), sync scroll should target OutlineView
        if isUnifiedMode && preferTreeInUnifiedMode && !outputViewController.view.isHidden {
             return outputViewController.scrollView
        }
        return inputViewController?.scrollView
    }
    
    /// Focus state for Compare mode (border highlight)
    var isFocused: Bool = false {
        didSet {
            updateFocusBorder()
        }
    }
    
    /// Callback when this panel gains focus (clicked)
    var onFocusChanged: ((Bool) -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 配置 SplitView
        if let initialOrientation = initialOrientation {
            splitView.isVertical = (initialOrientation == .vertical)
        } else {
            splitView.isVertical = true
        }
        splitView.dividerStyle = .thin
        
        // 创建输入面板
        inputViewController = InputViewController(viewModel: viewModel)
        inputViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
        }
        inputViewController.onPasteDetected = { [weak self] in
            guard let self = self else { return }
            
            // Auto-Format on Paste (Delay Strategy)
            // Wait 0.5s to allow Main Thread to finish layout of the pasted text (Layout 1).
            // This prevents "Double Layout" choke.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // 1. Manual Sync: Force update ViewModel with latest text
                self.viewModel.inputText = self.inputViewController.textView.string
                
                // 2. Clear Dirty Flag: We are handling the new content NOW.
                // This prevents the debounce timer or focus-lost handler from re-parsing it.
                self.inputViewController.isDirty = false
                
                // 3. Trigger Format
                self.viewModel.formatJSON()
                
                // 4. Post-Format Handling
                if self.viewModel.parsedTree != nil {
                    if self.isUnifiedMode {
                        // Unified Mode: Optionally replace input with formatted text
                        if !self.viewModel.formattedText.isEmpty {
                            self.viewModel.inputText = self.viewModel.formattedText
                        }
                        
                        // Auto-switch to tree on unified paste
                        if self.preferTreeInUnifiedMode {
                             self.switchToOutput()
                        }
                    } else {
                        // Split Mode:
                        // The OutputView updates automatically via onParsedTreeChanged.
                    }
                }
            }
        }
        
        let inputItem = NSSplitViewItem(viewController: inputViewController)
        inputItem.minimumThickness = 300
        inputItem.holdingPriority = .defaultLow
        addSplitViewItem(inputItem)
        
        // 创建输出面板
        outputViewController = OutputViewController(viewModel: viewModel)
        outputViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
        }
        
        if isUnifiedMode {
            // Unified Mode: Ensure Input takes full space
            // If preferTreeInUnifiedMode is set, we ALSO add Output item, but handle visibility dynamically
            if preferTreeInUnifiedMode {
                 let outputItem = NSSplitViewItem(viewController: outputViewController)
                 outputItem.minimumThickness = 300
                 // Initially hidden, showing Input
                 outputItem.isCollapsed = true
                 addSplitViewItem(outputItem)
            }
        } else {
            // Standard Mode: Add Output item
            let outputItem = NSSplitViewItem(viewController: outputViewController)
            outputItem.minimumThickness = 300
            // outputItem.isCollapsed = true // 默认隐藏输出 -> 恢复左右分栏，不隐藏
            addSplitViewItem(outputItem)
        }
        
        // 绑定 ViewModel 事件以处理视图切换
        // 注意：这是为了实现"合并"界面的体验，当格式化成功时自动跳转到输出/树状视图
        viewModel.onParsedTreeChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 让 OutputViewController 更新内容
                self.outputViewController.updateContent()
                
                // 如果不是 Unified Mode (纯文本模式)，且有合法数据，则跳转到 Output -> 移除跳转
                // if !self.isUnifiedMode && self.viewModel.parsedTree != nil {
                //    self.switchToOutput()
                // } else if self.isUnifiedMode {
                
                if self.isUnifiedMode {
                    // Unified Mode 下，更新输入框文本
                    // Only update if we have formatted text (skips update for large files to prevent clearing input)
                    if !self.viewModel.formattedText.isEmpty {
                        self.viewModel.inputText = self.viewModel.formattedText
                    }
                    
                    // Smart Switch: If preference enabled and parse successful, switch to Tree View
                    if self.preferTreeInUnifiedMode && self.viewModel.parsedTree != nil {
                        self.switchToOutput()
                    }
                }
            }
        }
        
        viewModel.onParseErrorChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 让 OutputViewController 更新(显示错误)
                self.outputViewController.updateContent()
                
                // 如果有错误，也跳转到 Output 显示错误信息
                // if !self.isUnifiedMode && self.viewModel.parseError != nil {
                //      self.switchToOutput()
                // }
                // 修改：自动输入触发的 Format 如果失败，不自动跳转 Error 界面，以免打断输入
            }
        }        
        // 监听通知
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFormatJSON),
            name: .formatJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMinifyJSON),
            name: .minifyJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePasteJSON),
            name: .pasteJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleClearInput),
            name: .clearInput, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCopyFormattedResult),
            name: .copyFormattedResult, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    
    @objc private func handleFormatJSON() {
        // Optimization: Dirty Check
        // If the input hasn't changed (isDirty == false) and we already have a parsed tree,
        // we can skip the expensive parse/format cycle.
        // This makes switching between Code/Tree views instant.
        if !inputViewController.isDirty && viewModel.parsedTree != nil {
            // Already up to date
            return
        }
        
        // Manual Sync for Large Files (Lazy Sync Strategy)
        // Since we disabled real-time sync in textDidChange for large files,
        // we must ensure ViewModel has the latest text from UI before formatting.
        if inputViewController.isViewLoaded {
            // This assignment triggers a String copy, but it only happens once when user clicks Format
            viewModel.inputText = inputViewController.textView.string
            // Reset dirty flag after sync
            inputViewController.isDirty = false
        }
    
        viewModel.formatJSON()
        
        if isUnifiedMode {
            // In unified mode, replace input text with formatted text if successful
            // Check for empty formattedText (Large files)
            if viewModel.parsedTree != nil && !viewModel.formattedText.isEmpty {
                viewModel.inputText = viewModel.formattedText
            }
        }
    }
    
    @objc private func handleMinifyJSON() {
        viewModel.minifyJSON()
        // Minify 通常也显示在输出框（或替换输入框？）
        // 根据现有逻辑，formattedText 会更新。
        // 如果我们希望 Minify 后也跳到 Output 看结果（虽然 Output 是 TreeView，可能不直观显示 minified text，
        // 但根据 ViewModel，minified text 存在 formattedText 中。
        // 现有 UI OutputView 是 TreeView，可能无法显示 minified text。
        // 仔细看 OutputView updateContent:
        // 它只显示 parsedTree。Minify 操作在 ViewModel 中只更新 formattedText 和 parseError (if any)，并不更新 parsedTree (除非 minified string 被重新 parse)
        // 并在 ViewModel 中 minifyJSON 并没有重新 parse。
        // 所以 Minify 目前可能在 OutputView 中看不到效果，除非 OutputView 有显示 Text 的模式。
        // 目前先保持原样，或者如果 ViewModel logic 改变了再说。
        // 假设用户想看 Tree，那么 Format 才是主要入口。
        // 如果 Minify 是为了复制，那么在 InputView 也可以。
        // 既然 OutputView 是 TreeView，那 Minify 后跳转过去可能只显示 Tree（如果 parsedTree 存在）。
        
        // 修正：ViewModel.minifyJSON 确实只更新 formattedText。
        // 如果用户想要 "Minified View"，可能需要 OutputView 支持显示 Text。
        // 但目前需求是 "格式化完成之后，只显示格式化后的"。
        // 我们假设 "格式化" 是指 Format JSON -> Tree View。
        // Minify 可能不需要跳转，或者跳转也只是显示之前的 Tree？
        // 让我们先只处理 Format JSON 的跳转。
        viewModel.minifyJSON()
    }
    
    @objc private func handlePasteJSON() {
        viewModel.pasteFromClipboard()
        if isUnifiedMode {
            // Auto-format after paste in unified mode
             // pasteFromClipboard already calls formatJSON in ViewModel
            if viewModel.parsedTree != nil && !viewModel.formattedText.isEmpty {
                viewModel.inputText = viewModel.formattedText
            }
        }
    }
    
    @objc private func handleClearInput() {
        viewModel.clear()
        if isUnifiedMode && preferTreeInUnifiedMode {
            switchToInput()
        }
    }
    
    @objc private func handleCopyFormattedResult() {
        // 复制格式化后的结果到剪贴板
        viewModel.copyToClipboard()
    }
    
    // MARK: - View Switching
    
    // MARK: - View Switching
    
    public func switchToOutput() {
        guard isUnifiedMode && preferTreeInUnifiedMode else { return }
        
        autoreleasepool {
            let inputItem = splitViewItems[0]
            let outputItem = splitViewItems[1]
            
            // Remove animation to prevent visual jumping/scrolling and memory spikes (autorelease pool buildup)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                inputItem.isCollapsed = true
                outputItem.isCollapsed = false
            }, completionHandler: nil)
        }
    }
    
    public func switchToInput() {
        guard isUnifiedMode && preferTreeInUnifiedMode else { return }
        
        autoreleasepool {
            let inputItem = splitViewItems[0]
            let outputItem = splitViewItems[1]
            
            // Remove animation to prevent visual jumping/scrolling and memory spikes
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                inputItem.isCollapsed = false
                outputItem.isCollapsed = true
            }, completionHandler: nil)
            
            // Ensure Input takes focus
            view.window?.makeFirstResponder(inputViewController.textView)
        }
    }
    
    // MARK: - Focus Border
    
    private func updateFocusBorder() {
        view.wantsLayer = true
        if isFocused {
            view.layer?.borderColor = NSColor.controlAccentColor.cgColor
            view.layer?.borderWidth = 2
            view.layer?.cornerRadius = 4
        } else {
            view.layer?.borderWidth = 0
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Notify parent that this panel was clicked (for Compare mode focus management)
        onFocusChanged?(true)
    }
}

// MARK: - Input View Controller

class InputViewController: NSViewController {
    
    private weak var viewModel: FormatterViewModel?
    var textView: JSONTextView!
    private var lineNumberRuler: LineNumberRulerView?
    
    var onPasteDetected: (() -> Void)?
    var onFocusRequest: (() -> Void)?  // 焦点请求回调
    private var debounceTimer: Timer?
 
    // 用于确保异步高亮的一致性
    private var highlightGeneration: Int = 0
    
    // Dirty Flag for optimization
    public var isDirty: Bool = false
    
    // 行号显示设置
    private var showLineNumbers: Bool = true
    
    var scrollView: NSScrollView? {
        return textView?.enclosingScrollView
    }
    
    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        // 读取行号显示设置（使用 object(forKey:) 更高效）
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            showLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            showLineNumbers = true // 默认值
        }
        
        // 监听显示设置变化（只在设置页面修改时触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaySettingsDidChange),
            name: Constants.Notifications.displaySettingsChanged,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func displaySettingsDidChange(_ notification: Notification) {
        // 使用 object(forKey:) 检查是否存在，比 dictionaryRepresentation() 更高效
        let newShowLineNumbers: Bool
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            newShowLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            newShowLineNumbers = true // 默认值
        }
        
        if newShowLineNumbers != showLineNumbers {
            showLineNumbers = newShowLineNumbers
            updateLineNumberVisibility()
        }
    }
    
    private func updateLineNumberVisibility() {
        guard let scrollView = textView?.enclosingScrollView else { return }
        
        if showLineNumbers {
            if lineNumberRuler == nil {
                lineNumberRuler = LineNumberRulerView(textView: textView)
            }
            scrollView.verticalRulerView = lineNumberRuler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        } else {
            scrollView.rulersVisible = false
            scrollView.hasVerticalRuler = false
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        // 创建主容器
        let containerView = NSStackView()
        containerView.orientation = .vertical
        containerView.spacing = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 标题栏
        let headerView = createHeaderView(title: "Input")
        containerView.addArrangedSubview(headerView)
        headerView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        
        // 分隔线
        let divider = NSBox()
        divider.boxType = .separator
        containerView.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        
        // 文本编辑器
        let scrollView = createTextView()
        containerView.addArrangedSubview(scrollView)
        scrollView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        
        // 设置文本视图填满剩余空间
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // 绑定 ViewModel
        viewModel?.onInputTextChanged = { [weak self] text in
            guard let self = self else { return }
            // 性能优化：先检查长度，再检查内容，避免大字符串的不必要比较
            if self.textView.string.count != text.count || self.textView.string != text {
                self.textView.string = text
                
                // Reset scroll and selection to top to prevent auto-scrolling to bottom
                self.textView.setSelectedRange(NSRange(location: 0, length: 0))
                self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                
                // Programmatic change doesn't trigger delegate, highlight manually
                self.highlightSyntax()
            }
        }
        
        // Initial highlight
        highlightSyntax()
    }
    
    // MARK: - Header
    private func createHeaderView(title: String) -> NSView {
        let headerView = ClickableHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        // Title (Leading)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        return headerView
    }
    


    

    private func createTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 使用自定义 TextContainer
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        
        // 注意：虽然 allowsNonContiguousLayout 可以提升性能，但它可能导致滚动条行为异常（只能滑一部分）
        // 对于大文件，这是避免全量布局卡死必须的 trade-off
        layoutManager.allowsNonContiguousLayout = true
        
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        textView = JSONTextView(frame: .zero, textContainer: textContainer)
        textView.onPaste = { [weak self] in
            // Paste action detected
            // We rely on textDidChange's debounce timer (0.8s) to trigger format
            // to avoid freezing UI on large pastes.
            
            // Notify parent
            self?.onPasteDetected?()
        }
        textView.onMouseDown = { [weak self] in
            self?.onFocusRequest?()
        }
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        
        // 禁用所有自动功能以提升性能
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        textView.delegate = self
        
        // 设置初始内容
        textView.string = viewModel?.inputText ?? ""
        
        scrollView.documentView = textView
        
        // 添加行号视图
        if showLineNumbers {
            lineNumberRuler = LineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = lineNumberRuler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }
        
        return scrollView
    }
    
    // MARK: - Actions
    
//    @objc private func formatAction() {
//        viewModel?.formatJSON()
//    }
//    
//    @objc private func minifyAction() {
//        viewModel?.minifyJSON()
//    }
//    
//    @objc private func pasteAction() {
//        viewModel?.pasteFromClipboard()
//    }
//    
//    @objc private func clearAction() {
//        viewModel?.clear()
//    }
}

extension InputViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // Mark as dirty whenever text changes
        isDirty = true
        
        let textLen = textView.string.count
        
        // Lazy Sync: 如果文件过大 (> 100KB)，不实时同步 ViewModel，不负责高亮
        if textLen > 100_000 {
             // Do nothing. Text stays in NSTextView.
             // User must click "Format" to trigger sync & parse.
             return
        }
        
        // 小文件：正常实时同步和高亮
        viewModel?.inputText = textView.string
        highlightGeneration += 1
        highlightSyntax()
        
        // Debounce auto-format (Small files only)
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.viewModel?.formatJSON()
        }
    }
    
    func textDidEndEditing(_ notification: Notification) {
        // Lost focus: trigger immediate format. 
        // If "preferTreeInUnifiedMode" is on in the parent, this might trigger a view switch.
        debounceTimer?.invalidate()
        
        // Fix: Only format if dirty.
        // Switching views causes input to lose focus, we must NOT re-parse
        // if the content hasn't changed. This prevents memory spikes and redundant work.
        if isDirty {
            // Ensure ViewModel has latest text (crucial for large files where lazy sync is active)
            viewModel?.inputText = textView.string
            viewModel?.formatJSON()
            isDirty = false
        }
    }
    
    private func highlightSyntax() {
        let text = textView.string
        let count = text.count
        
        // 1. 如果文件 > 20KB，为了绝对性能，完全禁用输入框高亮
        // 输入框只作为"Raw Input"，不承担高亮任务
        if count > 20_000 {
            return
        }
        
        // 2. 对于小文件 (< 100KB)，保持主线程同步高亮，响应最快
        if count < 100_000 {
            SyntaxHighlightService.shared.highlight(textView.textStorage!)
            return
        }
        
        // 3. 对于中等大小文件 (100KB - 2MB)，使用异步高亮防止阻塞 UI
        let currentGeneration = highlightGeneration
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 计算高亮属性
            let highlights = SyntaxHighlightService.shared.calculateHighlights(for: text, isDark: isDark)
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 检查版本，如果文本已更改，则丢弃本次结果
                if self.highlightGeneration != currentGeneration {
                    return
                }
                
                // 应用高亮
                let textStorage = self.textView.textStorage!
                
                // 确保范围仍然有效（虽然 generation 检查应该通过，但安全第一）
                if textStorage.length != text.utf16.count {
                    return
                }
                
                textStorage.beginEditing()
                
                // 清除现有颜色
                let fullRange = NSRange(location: 0, length: textStorage.length)
                textStorage.removeAttribute(.foregroundColor, range: fullRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
                
                // 应用新颜色
                for (range, color) in highlights {
                    if range.upperBound <= textStorage.length {
                        textStorage.addAttribute(.foregroundColor, value: color, range: range)
                    }
                }
                
                textStorage.endEditing()
            }
        }
    }
}

// MARK: - Output View Controller

class OutputViewController: NSViewController {
    
    private weak var viewModel: FormatterViewModel?
    private var outlineView: NSOutlineView!
    private var errorLabel: NSTextField?
    private var emptyStateView: NSView?
    private var lineNumberColumn: NSTableColumn?
    
    // 行号显示设置
    private var showLineNumbers: Bool = true
    
    // Callback specifically for requesting Edit mode (switch back to Input)
    var onEditRequested: (() -> Void)?
    var onFocusRequest: (() -> Void)?  // 焦点请求回调
    
    var scrollView: NSScrollView? {
        return outlineView?.enclosingScrollView
    }
    
    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        // 读取行号显示设置（使用 object(forKey:) 更高效）
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            showLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            showLineNumbers = true // 默认值
        }
        
        // 监听显示设置变化（只在设置页面修改时触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaySettingsDidChange),
            name: Constants.Notifications.displaySettingsChanged,
            object: nil
        )
        
        // 监听展开/折叠事件以刷新行号
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(outlineViewItemDidExpandOrCollapse),
            name: NSOutlineView.itemDidExpandNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(outlineViewItemDidExpandOrCollapse),
            name: NSOutlineView.itemDidCollapseNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func displaySettingsDidChange(_ notification: Notification) {
        // 使用 object(forKey:) 检查是否存在，比 dictionaryRepresentation() 更高效
        let newShowLineNumbers: Bool
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            newShowLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            newShowLineNumbers = true // 默认值
        }
        
        if newShowLineNumbers != showLineNumbers {
            showLineNumbers = newShowLineNumbers
            updateLineNumberColumnVisibility()
        }
    }
    
    @objc private func outlineViewItemDidExpandOrCollapse(_ notification: Notification) {
        // 折叠/展开后刷新行号列
        guard showLineNumbers else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let visibleRows = self.outlineView.rows(in: self.outlineView.visibleRect)
            if visibleRows.length > 0 {
                self.outlineView.reloadData(forRowIndexes: IndexSet(integersIn: visibleRows.location..<(visibleRows.location + visibleRows.length)),
                                           columnIndexes: IndexSet(integer: 0))
            }
        }
    }
    
    private func updateLineNumberColumnVisibility() {
        guard let lineNumberColumn = lineNumberColumn else { return }
        
        if showLineNumbers {
            lineNumberColumn.isHidden = false
            lineNumberColumn.width = 40
        } else {
            lineNumberColumn.isHidden = true
            lineNumberColumn.width = 0
        }
        outlineView?.reloadData()
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 主容器
        let containerView = NSStackView()
        containerView.orientation = .vertical
        containerView.spacing = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 内容区域（OutlineView 或 空状态）- 直接作为顶层视图
        let contentView = createContentView()
        containerView.addArrangedSubview(contentView)
        contentView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        contentView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // 绑定 ViewModel 移交给了 FormatterViewController 统一管理
        // 这样可以确保 updateContent 和 switchToOutput 同步进行
//        viewModel?.onParsedTreeChanged = { [weak self] in
//            self?.updateContent()
//        }
        // 设置右键菜单
        setupContextMenu()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure content is up to date when view loads
        updateContent()
    }
    
    // 确保列宽始终填满视图
    override func viewDidLayout() {
        super.viewDidLayout()
        
        guard let outlineView = outlineView,
              let column = outlineView.tableColumns.first else { return }
        
        // 只有当列宽小于视图宽度时，才强制拉伸到视图宽度
        // 这样既能实现"占满"，又不会在用户手动把列拖宽（或内容撑宽）后强制缩回去
        if column.width < outlineView.visibleRect.width {
            column.width = outlineView.visibleRect.width
        }
    }
    
    // MARK: - Header
    
    // Callback for paste events (used by parent to coordinate focus in Compare mode)
    var onPasteDetected: (() -> Void)?
    
    // MARK: - Paste Handling
    
    /// Handle Cmd+V paste in Tree view
    func handlePasteFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }
        
        // Update ViewModel with pasted content
        viewModel?.inputText = clipboardString
        viewModel?.formatJSON()
        
        // Notify parent (for Compare mode focus coordination)
        onPasteDetected?()
        
        // Update Tree display
        updateContent()
    }
    
    /// Handle Delete key when all content is selected
    func handleClearContent() {
        viewModel?.clear()
        updateContent()
    }
    
    private func createHeaderView(title: String) -> NSView {
        let headerView = ClickableHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        // Title (Leading)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        return headerView
    }
    
    // @objc private func editAction() { ... } -> Removed
    private func createContentView() -> NSView {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建 OutlineView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // 创建 OutlineView - 使用支持粘贴的自定义 OutlineView
        let pastableOutlineView = PastableOutlineView()
        pastableOutlineView.onPaste = { [weak self] in
            self?.handlePasteFromClipboard()
        }
        pastableOutlineView.onClear = { [weak self] in
            self?.handleClearContent()
        }
        pastableOutlineView.onMouseDown = { [weak self] in
            self?.onFocusRequest?()
        }
        outlineView = pastableOutlineView
        outlineView.headerView = nil
        // 不自动调整列宽，允许水平滚动
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        // 允许选中以支持全选功能
        outlineView.selectionHighlightStyle = .regular
        // Set baseline row height
        outlineView.rowHeight = 20
        outlineView.usesAutomaticRowHeights = false
        
        // 添加行号列
        lineNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lineNumber"))
        lineNumberColumn?.title = "#"
        lineNumberColumn?.width = showLineNumbers ? 40 : 0
        lineNumberColumn?.minWidth = 0
        lineNumberColumn?.maxWidth = 40
        lineNumberColumn?.isHidden = !showLineNumbers
        outlineView.addTableColumn(lineNumberColumn!)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("json"))
        column.title = "JSON Structure"
        // 初始设置一个较小的值，adjustColumnWidth 会把它撑开
        column.width = 400
        column.minWidth = 400
        column.maxWidth = 100000 // 允许非常宽的列
        column.resizingMask = [.userResizingMask]
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        outlineView.dataSource = self
        outlineView.delegate = self
        
        // 优化缩进，保持层级感但不过分浪费空间
        outlineView.indentationPerLevel = 16
        
        scrollView.documentView = outlineView
        
        // ... (省略 emptyStateView 和 errorLabel 创建代码，保持不变) ...
        
        emptyStateView = createEmptyStateView()
        emptyStateView?.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emptyStateView!)
        
        NSLayoutConstraint.activate([
            emptyStateView!.topAnchor.constraint(equalTo: contentView.topAnchor),
            emptyStateView!.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emptyStateView!.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emptyStateView!.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        errorLabel = NSTextField(wrappingLabelWithString: "")
        errorLabel?.textColor = .systemRed
        errorLabel?.font = .systemFont(ofSize: 13)
        errorLabel?.isHidden = true
        errorLabel?.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(errorLabel!)
        
        NSLayoutConstraint.activate([
            errorLabel!.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            errorLabel!.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            errorLabel!.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        return contentView
    }
    
    // mouseDown removed from here, moved to JSONOutlineView
    
    private func createEmptyStateView() -> NSView {
        let container = PastableEmptyView()
        container.onPaste = { [weak self] in
            self?.handlePasteFromClipboard()
        }
        container.onMouseDown = { [weak self] in
            self?.onFocusRequest?()
        }
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        iconView.contentTintColor = NSColor.secondaryLabelColor.withAlphaComponent(0.5)
        stackView.addArrangedSubview(iconView)
        
        let label = NSTextField(labelWithString: "Enter or paste JSON to format")
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(label)
        
        return container
    }
    
    private func adjustColumnWidth() {
        guard let outlineView = outlineView,
              let column = outlineView.tableColumns.first else { return }
        
        // 1. 基础宽度：当前视图宽度的可见部分，保证不留白
        var maxWidth: CGFloat = outlineView.visibleRect.width > 300 ? outlineView.visibleRect.width : 300
        
        // 2. 采样计算内容宽度
        let rowCount = outlineView.numberOfRows
        let sampleCount = min(rowCount, 100) // 采样前100行
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        for i in 0..<sampleCount {
            guard let item = outlineView.item(atRow: i) as? IndexedJSONNode else { continue }
            
            // 计算文本内容
            var text = ""
            if let key = item.key {
                text = "\"\(key)\": "
            }
            
            switch item.type {
            case .object:
                text += "{...} (\(item.childCount) keys)"
            case .array:
                text += "[...] (\(item.childCount) items)"
            case .string:
                text += item.displayValue
            case .number, .boolean:
                text += item.displayValue
            case .null:
                text += "null"
            }
            
            // 计算宽度: 缩进 + 文本宽度 + 额外padding (图标+间距)
            // 计算宽度: 缩进 + 文本宽度 + 额外padding (图标+间距)
            let level = outlineView.level(forRow: i)
            let indentation = CGFloat(level) * outlineView.indentationPerLevel
            // 使用更精确的宽度计算
            let textWidth = (text as NSString).size(withAttributes: attributes).width
            let updateWidth = indentation + textWidth + 60 // 60 预留给图标、Cell间距等
            
            // 40 预留给可能的图标、Cell间距等
            if updateWidth > maxWidth {
                maxWidth = updateWidth
            }
        }
        
        // 3. 应用宽度
        if column.width != maxWidth {
            column.width = maxWidth
        }
    }
    
    func updateContent() {
        guard isViewLoaded else { return }
        
        if let error = viewModel?.parseError {
            // 显示错误
            errorLabel?.stringValue = "❌ \(error.message)"
            errorLabel?.isHidden = false
            emptyStateView?.isHidden = true
            outlineView.enclosingScrollView?.isHidden = true
        } else if viewModel?.parsedTree != nil {
            // 显示树
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = true
            outlineView.enclosingScrollView?.isHidden = false
            
            // Invalidate cache before reload
            // cache removed
            outlineView.reloadData()
            
            // 智能默认展开：展开所有 Object，但折叠过大的 Array (> 50)
            if let root = viewModel?.parsedTree {
                smartExpand(root)
            }
            
            // 调整列宽以适应内容
            adjustColumnWidth()
            
            // 重置滚动位置到左上角
            outlineView.scroll(NSPoint.zero)
        } else {
            // 显示空状态
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = false
            outlineView.enclosingScrollView?.isHidden = true
        }
    }
    
    // 智能展开：默认展开结构，但遇到大型数组则停止
    private func smartExpand(_ item: IndexedJSONNode, depth: Int = 0) {
        // 防止过深递归导致堆栈溢出或性能问题 (e.g. max depth 20)
        guard depth < 20 else { return }
        
        // 展开当前节点
        outlineView.expandItem(item)
        
        // 检查子节点
        // 只有 Object 才默认递归展开
        // Array 只有在子节点数量较少时才展开 (< 50)
        
        if item.type == .array {
            if item.childCount > 50 {
                // 大型数组，保持折叠（即不继续递归展开子项，但 item 本身已经 expand 了？）
                // 不，expandItem(item) 会显示 item 的子项。
                // 此时用户看到的是 [ ... (100 items) ] 的列表。
                // 用户希望的是：如果数组很大，连 [ ... ] 这一层都不要展开，即保持 [...] 状态。
                
                // Revert expansion for large arrays
                outlineView.collapseItem(item)
                return
            }
        }
        
        // 继续递归展开子节点
        // 注意：我们需要遍历子节点对象，这需要 ensure Loaded
        item.loadMore(count: Int.max) // 确保索引加载
        
        let count = item.childCount
        // 限制递归遍历的数量，避免主线程卡死 (如果 Object 有 10000 个 key，还是别全展开了)
        if count > 200 {
            // 即使是 Object，如果 key 太多，也折叠吧
             outlineView.collapseItem(item)
             return
        }
        
        for i in 0..<count {
            if let child = item.child(at: i) {
                // 只有容器节点需要考虑展开
                if child.type.isContainer {
                    smartExpand(child, depth: depth + 1)
                }
            }
        }
    }
    
}

struct JSONClosingNode {
    let type: NodeType
}

struct JSONLoadMoreNode {
    let parent: IndexedJSONNode
}


// MARK: - NSOutlineViewDataSource

extension OutputViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return viewModel?.parsedTree != nil ? 1 : 0
        }
        if let node = item as? IndexedJSONNode {
            // 如果是容器且有子节点
            if node.hasChildren {
                var count = node.childCount + 1 // 默认有一个 closing bracket
                if node.hasMoreChildren {
                    count += 1 // 还有一个 Load More 节点
                }
                // print("DEBUG: numberOfChildren for \(node.path): childCount=\(node.childCount), hasMore=\(node.hasMoreChildren), total=\(count)")
                return count
            }
            return node.childCount
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return viewModel?.parsedTree as Any
        }
        if let node = item as? IndexedJSONNode {
            let childCount = node.childCount
            
            // 正常子节点
            if index < childCount {
                return node.child(at: index) as Any
            }
            
            // Load More 节点
            if node.hasMoreChildren && index == childCount {
                return JSONLoadMoreNode(parent: node)
            }
            
            // Closing Node
            return JSONClosingNode(type: node.type)
        }
        return "Unknown"
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item == nil { return true }
        if let node = item as? IndexedJSONNode {
            return node.hasChildren
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        // NSOutlineView requires this method to return something (even nil) for it to work properly,
        // although we are using a view-based outline view.
        return item
    }
    

}



// MARK: - NSOutlineViewDelegate

extension OutputViewController: NSOutlineViewDelegate {
    
    // heightOfRowByItem removed for fixed row height strategy
    
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        // 0. 处理行号列
        if tableColumn?.identifier.rawValue == "lineNumber" {
            let cellId = NSUserInterfaceItemIdentifier("LineNumberCell")
            var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if view == nil {
                view = NSTableCellView()
                view?.identifier = cellId
                
                let textField = NSTextField(labelWithString: "")
                textField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .right
                textField.isSelectable = false
                textField.isEditable = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(textField)
                view?.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
                ])
            }
            
            // 获取当前行号
            let row = outlineView.row(forItem: item)
            view?.textField?.stringValue = row >= 0 ? "\(row + 1)" : ""
            return view
        }
        
        // 1. Check for LoadMoreNode
        if let _ = item as? JSONLoadMoreNode {
            let cellId = NSUserInterfaceItemIdentifier("LoadMoreCell")
            var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if view == nil {
                view = NSTableCellView()
                view?.identifier = cellId
                
                let button = NSButton(title: "Load more...", target: self, action: #selector(loadMoreAction(_:)))
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.font = NSFont.systemFont(ofSize: 11)
                button.translatesAutoresizingMaskIntoConstraints = false
                
                view?.addSubview(button)
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: view!.leadingAnchor),
                    button.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
                ])
            }
            return view
        }
        
        // 2. Check for ClosingNode
        if let closingNode = item as? JSONClosingNode {
            let cellId = NSUserInterfaceItemIdentifier("ClosingCell")
            var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if view == nil {
                view = NSTableCellView()
                view?.identifier = cellId
                
                let textField = NSTextField(labelWithString: "")
                textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                textField.textColor = .labelColor
                textField.isSelectable = false // Usually don't need to select closing brackets
                textField.isEditable = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(textField)
                view?.textField = textField
                
                NSLayoutConstraint.activate([
                    // Apply negative indentation permanently to this cell type
                    textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: -outlineView.indentationPerLevel),
                    textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
                    textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
                ])
            }
            
            view?.textField?.stringValue = closingNode.type == .object ? "}" : "]"
            return view
        }
        
        // 3. Normal IndexedJSONNode
        guard let node = item as? IndexedJSONNode else { return nil }
        
        let cellId = NSUserInterfaceItemIdentifier("JSONCell")
        var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if view == nil {
            view = NSTableCellView()
            view?.identifier = cellId
            
            let textField = NSTextField(wrappingLabelWithString: "")
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.cell?.usesSingleLineMode = true
            textField.cell?.lineBreakMode = .byClipping
            textField.isSelectable = true
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            view?.addSubview(textField)
            view?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor), // Standard indentation (0)
                textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
            ])
        }
        
        let cell = view?.textField
        
        // 构建显示文本
        var text = ""
        if let key = node.key {
            text = "\"\(key)\": "
        }
        
        // 获取展开状态
        let isExpanded = outlineView.isItemExpanded(item)
        
        switch node.type {
        case .object:
            if isExpanded {
                text += "{"
            } else {
                text += "{...} (\(node.childCount) keys)"
            }
            cell?.textColor = .labelColor
        case .array:
            if isExpanded {
                text += "["
            } else {
                text += "[...] (\(node.childCount) items)"
            }
            cell?.textColor = .labelColor
        case .string:
            // displayValue now returns raw string which includes quotes
            text += node.displayValue
            cell?.textColor = .systemGreen
        case .number:
            text += node.displayValue
            cell?.textColor = .systemBlue
        case .boolean:
            text += node.displayValue
            cell?.textColor = .systemOrange
        case .null:
            text += "null"
            cell?.textColor = .systemGray
        }
        
        cell?.stringValue = text
        
        return view
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] else { return }
        // 刷新该行以更新显示的文本（从 {...} 变为 {）
        outlineView.reloadItem(item, reloadChildren: false)
    }
    
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] else { return }
        // 刷新该行以更新显示的文本（从 { 变为 {...}）
        outlineView.reloadItem(item, reloadChildren: false)
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return false
    }
    
    // MARK: - Actions
    
    @objc private func loadMoreAction(_ sender: NSButton) {
        let row = outlineView.row(for: sender)
        guard row >= 0, let item = outlineView.item(atRow: row) as? JSONLoadMoreNode else { return }
        
        print("DEBUG: Loading more. Current childCount: \(item.parent.childCount)")
        let loaded = item.parent.loadMore()
        print("DEBUG: Loaded \(loaded) more items. New childCount: \(item.parent.childCount)")
        
        // Reload parent: this will update the child count and refresh the list
        // Note: Using reloadItem(parent, reloadChildren: true) allows expansion state to be somewhat preserved
        // but note that child identity changes so new children will be collapsed.
        outlineView.reloadItem(item.parent, reloadChildren: true)
    }
}

// MARK: - NSMenuDelegate (Context Menu)

extension OutputViewController: NSMenuDelegate {
    
    // 初始化菜单的方法，需要在 viewDidLoad 中调用
    func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0,
              let item = outlineView.item(atRow: clickedRow) as? IndexedJSONNode else {
            return
        }
        
        // Copy Key
        if let key = item.key {
            let copyKeyItem = NSMenuItem(title: "Copy Key", action: #selector(copyKeyAction), keyEquivalent: "")
            copyKeyItem.representedObject = item
            menu.addItem(copyKeyItem)
        }
        
        // Copy Value
        if !item.type.isContainer {
            let copyValueItem = NSMenuItem(title: "Copy Value", action: #selector(copyValueAction), keyEquivalent: "")
            copyValueItem.representedObject = item
            menu.addItem(copyValueItem)
        }
        
        // Copy Key-Value
        if let _ = item.key {
             let copyPairItem = NSMenuItem(title: "Copy Key-Value", action: #selector(copyKeyPairAction), keyEquivalent: "")
             copyPairItem.representedObject = item
             menu.addItem(copyPairItem)
        }
        
        // Copy JSON Fragment
        let copyJSONItem = NSMenuItem(title: "Copy JSON", action: #selector(copyJSONAction), keyEquivalent: "")
        copyJSONItem.representedObject = item
        menu.addItem(copyJSONItem)
    }
    
    @objc private func copyKeyAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode,
              let key = item.key else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(key, forType: .string)
    }
    
    @objc private func copyValueAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.displayValue, forType: .string)
    }
    
    @objc private func copyKeyPairAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode,
              let key = item.key else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // 构造简单的 "key": value 形式
        let text = "\"\(key)\": \(item.rawString)"
        pasteboard.setString(text, forType: .string)
    }
    
    @objc private func copyJSONAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.rawString, forType: .string)
    }
}



// MARK: - JSONTextView

class JSONTextView: NSTextView {
    var onPaste: (() -> Void)?
    var onMouseDown: (() -> Void)?
    
    override func paste(_ sender: Any?) {
        super.paste(sender)
        onPaste?()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onMouseDown?()
    }
}

// MARK: - IndexedJSONNode + AppKit Display

extension IndexedJSONNode {
    
    /// 用于在 NSOutlineView 中显示的富文本
    var attributedDisplayString: NSAttributedString {
        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemPurple,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let stringAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemGreen,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let booleanAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemOrange,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let nullAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let punctuationAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let result = NSMutableAttributedString()
        
        // Key
        if let key = key {
            result.append(NSAttributedString(string: "\"\(key)\"", attributes: keyAttributes))
            result.append(NSAttributedString(string: ": ", attributes: punctuationAttributes))
        }
        
        // Value
        switch type {
        case .object:
            result.append(NSAttributedString(string: "{...}", attributes: punctuationAttributes))
            result.append(NSAttributedString(string: " (\(childCount) keys)", attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 11)]))
            
        case .array:
            result.append(NSAttributedString(string: "[...]", attributes: punctuationAttributes))
            result.append(NSAttributedString(string: " (\(childCount) items)", attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 11)]))
            
        case .string:
            result.append(NSAttributedString(string: "\"\(displayValue)\"", attributes: stringAttributes))
            
        case .number:
            result.append(NSAttributedString(string: displayValue, attributes: numberAttributes))
            
        case .boolean:
            result.append(NSAttributedString(string: displayValue, attributes: booleanAttributes))
            
        case .null:
            result.append(NSAttributedString(string: "null", attributes: nullAttributes))
        }
        
        return result
    }
}


// MARK: - PastableOutlineView

class PastableOutlineView: NSOutlineView {
    var onPaste: (() -> Void)?
    var onClear: (() -> Void)?
    var onMouseDown: (() -> Void)?
    
    // 全选状态
    private(set) var isAllSelected: Bool = false {
        didSet {
            if isAllSelected != oldValue {
                updateSelectionVisual()
            }
        }
    }
    
    // 双击回调
    var onDoubleClickEmptyArea: (() -> Void)?
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        
        // 设置双击动作 - 使用 NSOutlineView 原生的 doubleAction
        self.target = self
        self.doubleAction = #selector(handleDoubleClick(_:))
        print("DEBUG: doubleAction set up")
    }
    
    @objc private func handleDoubleClick(_ sender: Any?) {
        let clickedRow = self.clickedRow
        let clickedColumn = self.clickedColumn
        
        // 获取点击位置
        guard let window = self.window else { return }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        let localPoint = self.convert(windowPoint, from: nil)
        
        print("DEBUG: handleDoubleClick - row=\(clickedRow), col=\(clickedColumn), localPoint=\(localPoint)")
        
        // 判断是否是"空白区域"：
        // 1. clickedRow == -1：点击在所有行的下方
        // 2. 点击位置 x 超过了列的内容宽度（即右侧空白区域）
        var isEmptyArea = false
        
        if clickedRow == -1 {
            // 点击在行下方的空白区域
            isEmptyArea = true
            print("DEBUG: Below all rows")
        } else if let column = tableColumns.first {
            // 检查是否点击在内容区域的右侧
            // 获取该行的实际内容宽度（缩进 + 内容）
            let level = self.level(forRow: clickedRow)
            let indentation = CGFloat(level + 1) * self.indentationPerLevel
            let estimatedContentWidth = indentation + 300 // 估算内容宽度
            
            // 如果点击位置 x 超过内容区域，认为是空白
            if localPoint.x > estimatedContentWidth {
                isEmptyArea = true
                print("DEBUG: Right of content area (x=\(localPoint.x) > \(estimatedContentWidth))")
            }
        }
        
        if isEmptyArea {
            print("DEBUG: Empty area detected, selecting all")
            selectAllContent()
        } else {
            // 双击内容区域：让 TextField 选中文本
            print("DEBUG: Content area clicked, selecting text in row")
            selectTextInRow(clickedRow)
        }
    }
    
    /// 让指定行的 TextField 选中所有文本并复制到剪贴板
    private func selectTextInRow(_ row: Int) {
        guard row >= 0, let cellView = view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
              let textField = cellView.textField else { 
            print("DEBUG: selectTextInRow failed - no cell view or text field")
            return 
        }
        
        let text = textField.stringValue
        print("DEBUG: Copying text: \(text)")
        
        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 选中该行并保持
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+V (Paste)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            onPaste?()
            return
        }
        
        // Check for Cmd+A (Select All)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectAllContent()
            return
        }
        
        // Check for Delete or Backspace (Clear when all selected)
        if isAllSelected {
            let deleteKeyCode: UInt16 = 51 // Backspace
            let forwardDeleteKeyCode: UInt16 = 117 // Forward Delete
            if event.keyCode == deleteKeyCode || event.keyCode == forwardDeleteKeyCode {
                clearContent()
                return
            }
        }
        
        // Any other key press clears the selection state
        isAllSelected = false
        
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        // 单击任何区域取消全选状态
        if event.clickCount == 1 {
            isAllSelected = false
        }
        super.mouseDown(with: event)
        onMouseDown?()
    }
    
    // Allow first responder to receive keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // MARK: - Selection Actions
    
    private func selectAllContent() {
        isAllSelected = true
        // 选中所有行以提供视觉反馈
        let allRows = IndexSet(integersIn: 0..<numberOfRows)
        selectRowIndexes(allRows, byExtendingSelection: false)
    }
    
    private func clearContent() {
        isAllSelected = false
        onClear?()
    }
    
    private func updateSelectionVisual() {
        if isAllSelected {
            // 高亮边框表示全选
            enclosingScrollView?.wantsLayer = true
            enclosingScrollView?.layer?.borderColor = NSColor.controlAccentColor.cgColor
            enclosingScrollView?.layer?.borderWidth = 2
            enclosingScrollView?.layer?.cornerRadius = 4
        } else {
            // 移除高亮
            enclosingScrollView?.layer?.borderWidth = 0
            deselectAll(nil)
        }
    }
}

// JSONOutlineView removed in favor of SegmentedControl

// MARK: - Clickable Header View

class ClickableHeaderView: NSView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Resign focus from any text field/view when header is clicked
        window?.makeFirstResponder(nil)
    }
}

// MARK: - PastableEmptyView

class PastableEmptyView: NSView {
    var onPaste: (() -> Void)?
    var onMouseDown: (() -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+V (Paste)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            onPaste?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // 让空状态视图获取焦点
        window?.makeFirstResponder(self)
        onMouseDown?()
    }
}
