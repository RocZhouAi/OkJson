//  UnifiedJsonViewController.swift
//  OkJson
//
//  统一的 JSON 视图控制器 - 通过状态管理切换编辑/查看模式

import AppKit

// MARK: - 视图模式

enum JsonViewMode {
    case editing   // 显示 TextView，用户可编辑
    case viewing   // 显示 TreeView，只读展示
}

// MARK: - UnifiedJsonViewController

class UnifiedJsonViewController: NSViewController {
    
    // MARK: - Properties
    
    private weak var viewModel: FormatterViewModel?
    // private var currentMode: JsonViewMode = .viewing // Removed: Only one mode now
    
    // UI 组件
    // private var textScrollView: NSScrollView! // Removed
    // private var textView: JSONTextView! // Removed
    // private var lineNumberRuler: LineNumberRulerView? // Removed
    
    // Only Tree View
    private var treeScrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var lineNumberColumn: NSTableColumn?
    
    
    private var emptyStateView: NSView?
    private var emptyStateIconView: NSImageView?
    private var emptyStateLabel: NSTextField?
    private var emptyStateHintLabel: NSTextField?
    private var errorLabel: NSTextField?
    
    // Column Header
    public var columnHeaderView: ColumnHeaderView?
    private var contentTopConstraint: NSLayoutConstraint?
    
    // Search Bar
    private var searchBarView: NSView?
    private var searchField: NSSearchField?
    private var searchCountLabel: NSTextField?
    private var searchBarTopConstraint: NSLayoutConstraint?
    private var isSearchBarVisible: Bool = false
    private var searchDebounceTimer: Timer?
    
    // Config
    var isHeaderVisible: Bool = false {
        didSet {
            updateHeaderVisibility()
        }
    }
    
    var isCloseButtonVisible: Bool = true {
        didSet {
            // Re-configure header to update close button
            if let vm = viewModel {
                columnHeaderView?.configure(title: vm.columnTitle, color: vm.columnColor, showClose: isCloseButtonVisible)
            }
        }
    }
    
    var onCloseRequest: (() -> Void)?
    
    // 回调
    var onPasteDetected: (() -> Void)?
    var onFocusRequest: (() -> Void)?
    // var onModeChanged: ((JsonViewMode) -> Void)? // Removed
    
    // 优化标记
    private var debounceTimer: Timer?
    private var lineNumberRefreshTimer: Timer?  // 行号刷新 debounce
    // private var highlightGeneration: Int = 0 // Removed (Text Syntax Highlight)
    // private var textViewNeedsUpdate: Bool = false // Removed
    public var isDirty: Bool = false
    private var needsContentUpdate: Bool = true
    
    // 行号显示设置
    private var showLineNumbers: Bool = true
    
    // 当前需要高亮括号的容器节点
    private weak var highlightedContainerNode: IndexedJSONNode?
    
    // 外部访问
    var scrollView: NSScrollView? {
        return treeScrollView
    }

    /// 估算显示内容所需的最大宽度（用于自动调整列宽）
    func estimatedContentWidth() -> CGFloat? {
        guard let tree = viewModel?.parsedTree else { return nil }

        // 字体宽度常量
        let charWidth: CGFloat = 7.2
        var maxWidth: CGFloat = 0

        // 递归计算所有节点的最大宽度
        func calculateNodeWidth(_ node: IndexedJSONNode, level: Int) -> CGFloat {
            let indentation = CGFloat(level) * 16 // outlineView.indentationPerLevel

            var nodeWidth = indentation

            // Key 宽度
            if let key = node.key {
                nodeWidth += CGFloat(key.count + 3) * charWidth // "key":
            }

            // Value 宽度
            switch node.type {
            case .object:
                nodeWidth += 15 + CGFloat(String(node.childCount).count)
            case .array:
                nodeWidth += 16 + CGFloat(String(node.childCount).count)
            case .string, .number, .boolean:
                nodeWidth += min(CGFloat(node.displayValue.count), 100) * charWidth
            case .null:
                nodeWidth += 4 * charWidth
            }

            // 递归检查子节点
            if node.hasChildren {
                let childCount = min(node.childCount, 50) // 只检查前50个子节点
                for i in 0..<childCount {
                    if let child = node.child(at: i) {
                        let childWidth = calculateNodeWidth(child, level: level + 1)
                        maxWidth = max(maxWidth, childWidth)
                    }
                }
            }

            maxWidth = max(maxWidth, nodeWidth)
            return nodeWidth
        }

        _ = calculateNodeWidth(tree, level: 0)

        // 加上行号列宽度
        let lineNumberWidth: CGFloat = showLineNumbers ? 32 : 0
        // 加上 padding
        let padding: CGFloat = 40

        return maxWidth + lineNumberWidth + padding
    }

    // var mode: JsonViewMode { return .viewing } // Removed
    
    // MARK: - Initialization
    
    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        // 读取行号显示设置
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            showLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            showLineNumbers = true
        }
        
        // 监听显示设置变化
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
            selector: #selector(outlineViewItemDidCollapseNotification),
            name: NSOutlineView.itemDidCollapseNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Constants.Notifications.themeChanged,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTimer?.invalidate()
        lineNumberRefreshTimer?.invalidate()
        searchDebounceTimer?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        setupColumnHeader()
        setupSearchBar()
        setupTreeView()
        setupEmptyStateView()
        setupErrorLabel()
        setupViewModelBindings() // Simplifed bindings
        
        // 初始状态
        // updateModeDisplay() // Removed
        updateContent()
        updateHeaderVisibility() // Apply initial visibility
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure theme colors are applied correctly when view loads
        handleThemeChanged()
    }
    
    private var hasSetInitialFocus = false
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if needsContentUpdate {
            updateContent()
        }
        
        // Fix initial focus issue: Force focus to Content View once, overriding Header
        if !hasSetInitialFocus, let window = view.window {
            hasSetInitialFocus = true
            
            if !emptyStateView!.isHidden {
                window.makeFirstResponder(emptyStateView)
            } else if !treeScrollView.isHidden {
                window.makeFirstResponder(outlineView)
            }
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()

        // 确保 TreeView 列宽始终填满视图
        guard let outlineView = outlineView,
              let column = outlineView.tableColumns.last else { return }

        if column.width < outlineView.visibleRect.width {
            column.width = outlineView.visibleRect.width
            let rowCount = outlineView.numberOfRows
            if rowCount > 0 {
                outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<rowCount))
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupColumnHeader() {
        let header = ColumnHeaderView()
        header.isHidden = true
        header.translatesAutoresizingMaskIntoConstraints = false
        
        // Bindings
        header.onTitleChanged = { [weak self] newTitle in
            self?.viewModel?.columnTitle = newTitle
        }
        header.onColorChanged = { [weak self] newColor in
            self?.viewModel?.columnColor = newColor
        }
        header.onClose = { [weak self] in
            self?.onCloseRequest?()
        }
        
        view.addSubview(header)
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Initial State
        if let vm = viewModel {
            header.configure(title: vm.columnTitle, color: vm.columnColor, showClose: true)
        }
        
        columnHeaderView = header
    }

    private func setupSearchBar() {
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.isHidden = true
        view.addSubview(bar)
        
        searchBarTopConstraint = bar.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        NSLayoutConstraint.activate([
            searchBarTopConstraint!,
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        let field = NSSearchField()
        field.placeholderString = "搜索 Key 或 Value…"
        field.font = .systemFont(ofSize: 12)
        field.controlSize = .small
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let countLabel = NSTextField(labelWithString: "")
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let prevButton = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "上一个")!, target: self, action: #selector(searchPreviousAction))
        prevButton.bezelStyle = .recessed
        prevButton.isBordered = false
        prevButton.setContentHuggingPriority(.required, for: .horizontal)
        
        let nextButton = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "下一个")!, target: self, action: #selector(searchNextAction))
        nextButton.bezelStyle = .recessed
        nextButton.isBordered = false
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        
        let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭搜索")!, target: self, action: #selector(closeSearchBarAction))
        closeButton.bezelStyle = .recessed
        closeButton.isBordered = false
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        
        let stack = NSStackView(views: [field, countLabel, prevButton, nextButton, closeButton])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        searchBarView = bar
        searchField = field
        searchCountLabel = countLabel
    }
    
    private func setupTreeView() {
        treeScrollView = NSScrollView()
        treeScrollView.hasVerticalScroller = true
        treeScrollView.hasHorizontalScroller = true
        treeScrollView.autohidesScrollers = true
        treeScrollView.borderType = .noBorder
        treeScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(treeScrollView)
        
        // Store top constraint for dynamic adjustment
        contentTopConstraint = treeScrollView.topAnchor.constraint(equalTo: view.topAnchor)
        
        NSLayoutConstraint.activate([
            contentTopConstraint!,
            treeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            treeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            treeScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 创建 OutlineView
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
        pastableOutlineView.onDeleteSelectedItem = { [weak self] in
            self?.deleteSelectedNode()
        }
        pastableOutlineView.onDoubleClickNode = { [weak self] (row: Int, point: NSPoint) in
            self?.handleDoubleClickOnNode(row: row, localPoint: point)
        }
        outlineView = pastableOutlineView
        outlineView.headerView = nil
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        outlineView.selectionHighlightStyle = .regular
        outlineView.usesAutomaticRowHeights = true
        
        // 添加行号列
        lineNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lineNumber"))
        lineNumberColumn?.title = "#"
        lineNumberColumn?.width = showLineNumbers ? 32 : 0
        lineNumberColumn?.minWidth = 0
        lineNumberColumn?.maxWidth = 32
        lineNumberColumn?.isHidden = !showLineNumbers
        outlineView.addTableColumn(lineNumberColumn!)
        
        // 添加内容列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("json"))
        column.title = "JSON Structure"
        column.width = 400
        column.minWidth = 400
        column.maxWidth = 100000
        column.resizingMask = [.userResizingMask]
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.indentationPerLevel = 16
        outlineView.intercellSpacing = NSSize(width: 2, height: 0)
        
        treeScrollView.documentView = outlineView
        
        // 设置右键菜单
        setupContextMenu()
    }
    
    private func setupEmptyStateView() {
        let container = PastableEmptyView()
        container.onPaste = { [weak self] in
            self?.handlePasteFromClipboard()
        }
        container.onMouseDown = { [weak self] in
            self?.onFocusRequest?()
        }
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: treeScrollView.topAnchor), // Align with treeScrollView top (respects header)
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .thin)
        iconView.contentTintColor = Theme.emptyStateIconColor
        stackView.addArrangedSubview(iconView)
        emptyStateIconView = iconView
        
        let label = NSTextField(labelWithString: "粘贴 JSON 开始格式化")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Theme.emptyStateColor
        label.alignment = .center
        stackView.addArrangedSubview(label)
        emptyStateLabel = label
        
        let hintLabel = NSTextField(labelWithString: "⌘V 粘贴")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = Theme.emptyStateHintColor
        hintLabel.alignment = .center
        stackView.addArrangedSubview(hintLabel)
        emptyStateHintLabel = hintLabel
        
        emptyStateView = container
    }
    
    private func setupErrorLabel() {
        errorLabel = NSTextField(wrappingLabelWithString: "")
        errorLabel?.textColor = Theme.errorColor
        errorLabel?.font = .systemFont(ofSize: 13)
        errorLabel?.isHidden = true
        errorLabel?.translatesAutoresizingMaskIntoConstraints = false
        if let cell = errorLabel?.cell as? NSTextFieldCell {
            cell.isSelectable = true // Ensure error can be copied
            cell.allowsEditingTextAttributes = true
        }
        
        view.addSubview(errorLabel!)

        NSLayoutConstraint.activate([
            errorLabel!.topAnchor.constraint(equalTo: treeScrollView.topAnchor, constant: 20), // Align with treeScrollView
            errorLabel!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupViewModelBindings() {
        viewModel?.onInputTextChanged = { [weak self] text in
            self?.updatePlaceholderVisibility()
        }
        
        viewModel?.onColumnMetadataChanged = { [weak self] in
            guard let self = self, let vm = self.viewModel else { return }
            self.columnHeaderView?.configure(title: vm.columnTitle, color: vm.columnColor, showClose: self.isCloseButtonVisible)
        }
        
        viewModel?.onSearchStateChanged = { [weak self] in
            self?.handleSearchStateChanged()
        }
    }
    
    private func updateHeaderVisibility() {
        columnHeaderView?.isHidden = !isHeaderVisible
        updateContentLayout()
    }
    
    private func updateContentLayout() {
        let headerHeight: CGFloat = isHeaderVisible ? 32 : 0
        let searchBarHeight: CGFloat = isSearchBarVisible ? 28 : 0
        searchBarTopConstraint?.constant = headerHeight
        searchBarView?.isHidden = !isSearchBarVisible
        contentTopConstraint?.constant = headerHeight + searchBarHeight
    }
    
    // MARK: - Content Update
    
    func updateContent() {
        if !isViewLoaded {
            needsContentUpdate = true
            return
        }
        
        needsContentUpdate = false
        
        let hasError = viewModel?.parseError != nil
        let hasTree = viewModel?.parsedTree != nil
        let isEmpty = (viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ?? true
        
        // Update Header Visibility based on Content
        updateHeaderVisibility()
        
        // 当输入为空时，显示空状态，不显示错误
        if isEmpty {
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = false
            treeScrollView.isHidden = true
            return
        }
        
        if hasError {
            // 显示错误
            errorLabel?.stringValue = "❌ 解析错误：\n\(viewModel?.parseError?.message ?? "Invalid JSON")"
            errorLabel?.isHidden = false
            emptyStateView?.isHidden = true
            treeScrollView.isHidden = true
            
            // "Fallback" - user might want to see what they pasted.
            // But we removed TextView. Maybe we can rely on error label to show context?
            // Or, user just pastes again.
            // Given "Extreme Performance", we assume user just wants to see result.
            
        } else if hasTree {
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = true
            treeScrollView.isHidden = false
            
            outlineView.reloadData()
            
            if viewModel?.parsedTree != nil {
                outlineView.expandItem(nil, expandChildren: true)
            }
            adjustColumnWidth()
            outlineView.scroll(NSPoint.zero)
            
            if let vm = viewModel, !vm.searchQuery.isEmpty {
                vm.performSearch()
            }
        } else {
            // 应该不会到这里，除非 parsing...
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = false
            treeScrollView.isHidden = true
        }
    }
    
    private func updatePlaceholderVisibility() {
        let isEmpty = viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        emptyStateView?.isHidden = !isEmpty
        if isEmpty {
             treeScrollView.isHidden = true
        }
        updateHeaderVisibility()
    }
    
    // MARK: - Paste Handling
    
    func handlePasteFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }
        
        errorLabel?.isHidden = true
        emptyStateView?.isHidden = true
        
        viewModel?.inputText = clipboardString
        viewModel?.markAsModified()
        viewModel?.formatJSON()
        onPasteDetected?()
    }
    
    func switchMode(to mode: JsonViewMode) {
        // No-Op for API compatibility if needed
    }
    
    func handleClearContent() {
        viewModel?.clear()
        updateContent()
    }
    
    // MARK: - Settings
    
    @objc private func displaySettingsDidChange(_ notification: Notification) {
        let newShowLineNumbers: Bool
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            newShowLineNumbers = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        } else {
            newShowLineNumbers = true
        }
        
        if newShowLineNumbers != showLineNumbers {
            showLineNumbers = newShowLineNumbers
            updateLineNumberVisibility()
        }
    }
    
    private func updateLineNumberVisibility() {
        // TreeView 行号列
        if let lineNumberColumn = lineNumberColumn {
            lineNumberColumn.isHidden = !showLineNumbers
            lineNumberColumn.width = showLineNumbers ? 32 : 0
        }
        outlineView?.reloadData()
    }
    
    @objc private func outlineViewItemDidExpandOrCollapse(_ notification: Notification) {
        refreshLineNumberColumn()
    }
    
    @objc private func outlineViewItemDidCollapseNotification(_ notification: Notification) {
        refreshLineNumberColumn()
    }
    
    @objc private func handleThemeChanged() {
        let appearance = NSApp.effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        }
        
        emptyStateIconView?.contentTintColor = Theme.emptyStateIconColor
        emptyStateLabel?.textColor = Theme.emptyStateColor
        emptyStateHintLabel?.textColor = Theme.emptyStateHintColor
        errorLabel?.textColor = Theme.errorColor
        
        // 刷新 TreeView 颜色
        outlineView.needsDisplay = true
    }
    
    private func refreshLineNumberColumn() {
        guard showLineNumbers else { return }
        
        // Debounce: 合并 50ms 内的多次刷新请求
        lineNumberRefreshTimer?.invalidate()
        lineNumberRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let visibleRows = self.outlineView.rows(in: self.outlineView.visibleRect)
            if visibleRows.length > 0 {
                self.outlineView.reloadData(forRowIndexes: IndexSet(integersIn: visibleRows.location..<(visibleRows.location + visibleRows.length)),
                                           columnIndexes: IndexSet(integer: 0))
            }
        }
    }
    
    // MARK: - TreeView Helpers
    
    private func adjustColumnWidth() {
        guard let outlineView = outlineView,
              let column = outlineView.tableColumns.last else { return }

        var maxWidth: CGFloat = outlineView.visibleRect.width > 300 ? outlineView.visibleRect.width : 300

        let rowCount = outlineView.numberOfRows
        let sampleCount = min(rowCount, 100)

        let charWidth: CGFloat = 7.2

        for i in 0..<sampleCount {
            guard let item = outlineView.item(atRow: i) as? IndexedJSONNode else { continue }

            var charCount = 0
            if let key = item.key {
                charCount += key.count + 4
            }

            switch item.type {
            case .object:
                charCount += 15 + String(item.childCount).count
            case .array:
                charCount += 16 + String(item.childCount).count
            case .string, .number, .boolean:
                charCount += min(item.displayValue.count, 100)
            case .null:
                charCount += 4
            }

            let level = outlineView.level(forRow: i)
            let indentation = CGFloat(level) * outlineView.indentationPerLevel
            let estimatedWidth = indentation + CGFloat(charCount) * charWidth + 60

            if estimatedWidth > maxWidth {
                maxWidth = estimatedWidth
            }
        }

        if column.width != maxWidth {
            column.width = maxWidth
            // 列宽变化后，通知 OutlineView 重新计算所有行高
            // 避免行高基于旧列宽缓存导致底部空白
            if rowCount > 0 {
                outlineView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<rowCount))
            }
        }
    }
    
    // MARK: - Context Menu
    
    private func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }

    // MARK: - 删除节点
    
    /// 删除当前选中的节点
    private func deleteSelectedNode() {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0,
              let node = outlineView.item(atRow: selectedRow) as? IndexedJSONNode else {
            return
        }
        deleteNode(node)
    }
    
    private func deleteNode(_ node: IndexedJSONNode) {
        guard let viewModel = viewModel,
              let root = viewModel.parsedTree else { return }
        
        if node.startOffset == 0 && node.endOffset >= root.endOffset {
            handleClearContent()
            return
        }
        
        let shouldSortKeys = root.shouldSortKeys
        let originalData = root.jsonData
        
        var collapsedPaths = saveCollapsedPaths()
        collapsedPaths = adjustPathsForDeletion(collapsedPaths, deletedNode: node)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let start = node.fullStartOffset
            let end = node.endOffset
            let totalCount = originalData.count
            
            guard start >= 0, end <= totalCount, start < end else { return }
            
            var removeStart = start
            var removeEnd = end
            var foundComma = false
            
            var i = start - 1
            while i >= 0 {
                let b = originalData[i]
                if b == 32 || b == 10 || b == 13 || b == 9 {
                    i -= 1
                    continue
                }
                if b == 44 {
                    foundComma = true
                    removeStart = i
                }
                break
            }
            
            if !foundComma {
                i = end
                while i < totalCount {
                    let b = originalData[i]
                    if b == 32 || b == 10 || b == 13 || b == 9 {
                        i += 1
                        continue
                    }
                    if b == 44 {
                        foundComma = true
                        removeEnd = i + 1
                    }
                    break
                }
            }
            
            var newData = Data()
            newData.reserveCapacity(totalCount - (removeEnd - removeStart))
            newData.append(originalData[0..<removeStart])
            newData.append(originalData[removeEnd..<totalCount])
            
            if let newTree = IndexedJSONNode.fromData(newData, shouldSortKeys: shouldSortKeys) {
                let newString = String(decoding: newData, as: UTF8.self)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let savedTreeCb = viewModel.onParsedTreeChanged
                    let savedErrorCb = viewModel.onParseErrorChanged
                    viewModel.onParsedTreeChanged = nil
                    viewModel.onParseErrorChanged = nil
                    
                    viewModel.inputText = newString
                    viewModel.formattedText = ""
                    viewModel.parseError = nil
                    viewModel.parsedTree = newTree
                    viewModel.markAsModified()
                    
                    viewModel.onParsedTreeChanged = savedTreeCb
                    viewModel.onParseErrorChanged = savedErrorCb
                    
                    self.outlineView.reloadData()
                    self.outlineView.expandItem(nil, expandChildren: true)
                    self.restoreCollapsedPaths(collapsedPaths)
                    self.adjustColumnWidth()
                }
            }
        }
    }
    
    // MARK: - 编辑节点

    /// 处理双击节点：确定编辑 key 还是 value
    private func handleDoubleClickOnNode(row: Int, localPoint: NSPoint) {
        guard let item = outlineView.item(atRow: row) as? IndexedJSONNode else { return }

        // 容器节点只允许编辑 key
        let jsonColIndex = outlineView.column(withIdentifier: NSUserInterfaceItemIdentifier("json"))
        guard jsonColIndex >= 0 else { return }
        guard let cellView = outlineView.view(atColumn: jsonColIndex, row: row, makeIfNecessary: false) as? JSONCellView else { return }

        let cellPoint = cellView.convert(localPoint, from: outlineView)

        // 判断点击在 key 还是 value 区域
        if !cellView.keyTextField.isHidden, cellView.keyTextField.frame.contains(cellPoint) {
            startEditing(cellView: cellView, node: item, field: "key")
        } else if !item.type.isContainer {
            startEditing(cellView: cellView, node: item, field: "value")
        }
    }

    /// 启动编辑
    private func startEditing(cellView: JSONCellView, node: IndexedJSONNode, field: String) {
        cellView.node = node
        cellView.onEditCommitted = { [weak self] editedNode, editedField, newText in
            self?.commitNodeEdit(node: editedNode, field: editedField, newText: newText)
        }
        cellView.enterEditMode(field: field)
    }

    /// 通过右键菜单触发编辑
    private func editNodeFromMenu(_ node: IndexedJSONNode, field: String) {
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        let jsonColIndex = outlineView.column(withIdentifier: NSUserInterfaceItemIdentifier("json"))
        guard jsonColIndex >= 0 else { return }
        guard let cellView = outlineView.view(atColumn: jsonColIndex, row: row, makeIfNecessary: false) as? JSONCellView else { return }
        startEditing(cellView: cellView, node: node, field: field)
    }

    /// 提交编辑：替换原始 Data 中的字节并重新解析
    private func commitNodeEdit(node: IndexedJSONNode, field: String, newText: String) {
        guard let viewModel = viewModel,
              let root = viewModel.parsedTree else { return }

        let shouldSortKeys = root.shouldSortKeys
        let originalData = root.jsonData

        let collapsedPaths = saveCollapsedPaths()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var newData: Data

            if field == "key" {
                guard let keyRange = node.keyByteRange else { return }
                // 替换 key 内容（范围是不含引号的 key 字节）
                let newKeyBytes = Data(newText.utf8)
                newData = Data()
                newData.reserveCapacity(originalData.count)
                newData.append(originalData[0..<keyRange.start])
                newData.append(newKeyBytes)
                newData.append(originalData[keyRange.end..<originalData.count])
            } else {
                let valueRange = node.valueByteRange
                // 根据类型构建新的 JSON 值
                let newJsonValue: String
                switch node.type {
                case .string:
                    // 用户输入的是纯文本，需要加引号并转义
                    let escaped = newText
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                        .replacingOccurrences(of: "\t", with: "\\t")
                    newJsonValue = "\"\(escaped)\""
                case .number:
                    // 验证数字格式
                    let trimmed = newText.trimmingCharacters(in: .whitespaces)
                    if Double(trimmed) != nil || Int(trimmed) != nil {
                        newJsonValue = trimmed
                    } else {
                        return // 无效数字，放弃编辑
                    }
                case .boolean:
                    let trimmed = newText.trimmingCharacters(in: .whitespaces).lowercased()
                    if trimmed == "true" || trimmed == "false" {
                        newJsonValue = trimmed
                    } else {
                        return
                    }
                case .null:
                    let trimmed = newText.trimmingCharacters(in: .whitespaces).lowercased()
                    if trimmed == "null" {
                        newJsonValue = "null"
                    } else {
                        // 允许类型变更：尝试解析为其他类型
                        newJsonValue = Self.inferJsonValue(from: newText)
                    }
                default:
                    return
                }

                let newValueBytes = Data(newJsonValue.utf8)
                newData = Data()
                newData.reserveCapacity(originalData.count)
                newData.append(originalData[0..<valueRange.start])
                newData.append(newValueBytes)
                newData.append(originalData[valueRange.end..<originalData.count])
            }

            // 验证新 JSON 仍然有效
            guard let newTree = IndexedJSONNode.fromData(newData, shouldSortKeys: shouldSortKeys) else { return }
            let newString = String(decoding: newData, as: UTF8.self)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let savedTreeCb = viewModel.onParsedTreeChanged
                let savedErrorCb = viewModel.onParseErrorChanged
                viewModel.onParsedTreeChanged = nil
                viewModel.onParseErrorChanged = nil

                viewModel.inputText = newString
                viewModel.formattedText = ""
                viewModel.parseError = nil
                viewModel.parsedTree = newTree
                viewModel.markAsModified()

                viewModel.onParsedTreeChanged = savedTreeCb
                viewModel.onParseErrorChanged = savedErrorCb

                self.outlineView.reloadData()
                self.outlineView.expandItem(nil, expandChildren: true)
                self.restoreCollapsedPaths(collapsedPaths)
                self.adjustColumnWidth()
            }
        }
    }

    /// 从用户输入推断 JSON 值类型
    private static func inferJsonValue(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "true" || trimmed == "false" { return trimmed }
        if trimmed == "null" { return trimmed }
        if Double(trimmed) != nil { return trimmed }
        // 默认作为字符串
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    // MARK: - Expansion State Preservation
    
    private func saveCollapsedPaths() -> Set<String> {
        var result = Set<String>()
        guard let root = viewModel?.parsedTree else { return result }
        collectCollapsedPaths(node: root, path: "$", result: &result)
        return result
    }
    
    private func collectCollapsedPaths(node: IndexedJSONNode, path: String, result: inout Set<String>) {
        guard node.hasChildren else { return }
        if !outlineView.isItemExpanded(node) {
            result.insert(path)
            return
        }
        for i in 0..<node.childCount {
            guard let child = node.child(at: i), child.hasChildren else { continue }
            let childPath = path + "." + (child.key ?? "[\(i)]")
            collectCollapsedPaths(node: child, path: childPath, result: &result)
        }
    }
    
    private func adjustPathsForDeletion(_ paths: Set<String>, deletedNode: IndexedJSONNode) -> Set<String> {
        guard let parent = outlineView.parent(forItem: deletedNode) as? IndexedJSONNode,
              parent.type == .array else {
            return paths
        }
        
        var deletedIndex = -1
        for i in 0..<parent.childCount {
            if parent.child(at: i) === deletedNode {
                deletedIndex = i
                break
            }
        }
        guard deletedIndex >= 0 else { return paths }
        
        let deletedPath = buildNodePath(deletedNode)
        guard let lastDot = deletedPath.lastIndex(of: ".") else { return paths }
        let prefix = String(deletedPath[deletedPath.startIndex...lastDot]) + "["
        
        var adjusted = Set<String>()
        for path in paths {
            guard path.hasPrefix(prefix) else {
                adjusted.insert(path)
                continue
            }
            let rest = path[path.index(path.startIndex, offsetBy: prefix.count)...]
            guard let bracket = rest.firstIndex(of: "]"),
                  let idx = Int(rest[rest.startIndex..<bracket]) else {
                adjusted.insert(path)
                continue
            }
            if idx == deletedIndex {
                continue
            } else if idx > deletedIndex {
                let suffix = rest[bracket...]
                adjusted.insert(prefix + "\(idx - 1)" + suffix)
            } else {
                adjusted.insert(path)
            }
        }
        return adjusted
    }
    
    private func buildNodePath(_ node: IndexedJSONNode) -> String {
        var components: [String] = []
        var current: Any = node
        while let parent = outlineView.parent(forItem: current) as? IndexedJSONNode {
            if let cur = current as? IndexedJSONNode {
                if let key = cur.key {
                    components.append(key)
                } else {
                    for i in 0..<parent.childCount {
                        if parent.child(at: i) === cur {
                            components.append("[\(i)]")
                            break
                        }
                    }
                }
            }
            current = parent
        }
        return "$." + components.reversed().joined(separator: ".")
    }
    
    private func restoreCollapsedPaths(_ collapsed: Set<String>) {
        guard !collapsed.isEmpty, let root = viewModel?.parsedTree else { return }
        applyCollapsedPaths(node: root, path: "$", collapsed: collapsed)
    }
    
    private func applyCollapsedPaths(node: IndexedJSONNode, path: String, collapsed: Set<String>) {
        guard node.hasChildren else { return }
        if collapsed.contains(path) {
            outlineView.collapseItem(node)
            return
        }
        for i in 0..<node.childCount {
            guard let child = node.child(at: i), child.hasChildren else { continue }
            let childPath = path + "." + (child.key ?? "[\(i)]")
            applyCollapsedPaths(node: child, path: childPath, collapsed: collapsed)
        }
    }
}


// MARK: - NSOutlineViewDataSource

extension UnifiedJsonViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return viewModel?.parsedTree != nil ? 1 : 0
        }
        if let node = item as? IndexedJSONNode {
            if node.hasChildren {
                // 极致优化：小对象直接加载全部，不显示 Load more
                // 只有超过 50 个子项的容器才显示 Load more
                let count = node.childCount
                if count < 50 {
                    // 小对象，加载全部子节点
                    node.loadMore(count: Int.max)
                }
                
                var total = node.childCount + 1 // +1 for closing bracket
                // 只有大容器且还有更多未加载的才显示 Load more
                if node.hasMoreChildren && node.childCount >= 50 {
                    total += 1
                }
                return total
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
            
            if index < childCount {
                return node.child(at: index) as Any
            }
            
            // 只有大容器才显示 Load more
            if node.hasMoreChildren && childCount >= 50 && index == childCount {
                return JSONLoadMoreNode(parent: node)
            }
            
            return JSONClosingNode(type: node.type, parentNode: node)
        }
        return "Unknown"
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? IndexedJSONNode {
            return node.hasChildren
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }
}

// MARK: - NSOutlineViewDelegate

extension UnifiedJsonViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        // 处理行号列
        if tableColumn?.identifier.rawValue == "lineNumber" {
            let cellId = NSUserInterfaceItemIdentifier("LineNumberCell")
            var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if view == nil {
                view = NSTableCellView()
                view?.identifier = cellId
                
                let textField = NSTextField(labelWithString: "")
                textField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                textField.textColor = Theme.lineNumberColor
                textField.alignment = .right
                textField.isSelectable = false
                textField.isEditable = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(textField)
                view?.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 0),
                    textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor, constant: -2),
                    textField.topAnchor.constraint(equalTo: view!.topAnchor, constant: 2)
                ])
            }
            
            let row = outlineView.row(forItem: item)
            view?.textField?.stringValue = row >= 0 ? "\(row + 1)" : ""
            return view
        }
        
        // Load More 节点
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
        
        // Closing 节点
        if let closingNode = item as? JSONClosingNode {
            let cellId = NSUserInterfaceItemIdentifier("ClosingCell")
            var view = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if view == nil {
                view = NSTableCellView()
                view?.identifier = cellId
                
                let textField = NSTextField(labelWithString: "")
                textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                textField.textColor = Theme.punctuationColor
                textField.isSelectable = false
                textField.isEditable = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                view?.addSubview(textField)
                view?.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: -outlineView.indentationPerLevel),
                    textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
                    textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor)
                ])
            }
            
            view?.textField?.stringValue = closingNode.type == .object ? "}" : "]"
            // 括号高亮：闭合括号的父节点是当前高亮容器时变色
            let isHighlighted = (highlightedContainerNode != nil && closingNode.parentNode === highlightedContainerNode)
            view?.textField?.textColor = isHighlighted ? Theme.bracketHighlightColor : Theme.punctuationColor
            return view
        }
        
        // 正常 JSON 节点
        guard let node = item as? IndexedJSONNode else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("JSONCell")
        var cellView = outlineView.makeView(withIdentifier: cellId, owner: self) as? JSONCellView

        if cellView == nil {
            cellView = JSONCellView()
            cellView?.identifier = cellId
        }

        // 分别设置 key 和 value
        let keyText: String? = node.key != nil ? "\"\(node.key!)\":" : nil

        var valueText = ""
        var valueColor: NSColor = Theme.punctuationColor
        var isContainer = false

        let isExpanded = outlineView.isItemExpanded(item)

        // 括号高亮：当前节点是高亮的容器时变色
        let isBracketHighlighted = (highlightedContainerNode != nil && node === highlightedContainerNode)

        var isTruncated = false

        switch node.type {
        case .object:
            isContainer = true
            valueText = isExpanded ? "{" : "{...} (\(node.childCount) keys)"
            if isBracketHighlighted { valueColor = Theme.bracketHighlightColor }
        case .array:
            isContainer = true
            valueText = isExpanded ? "[" : "[...] (\(node.childCount) items)"
            if isBracketHighlighted { valueColor = Theme.bracketHighlightColor }
        case .string:
            isTruncated = node.isTruncated
            valueText = isTruncated ? node.truncatedDisplayValue : node.displayValue
            valueColor = Theme.stringColor
        case .number:
            isTruncated = node.isTruncated
            valueText = isTruncated ? node.truncatedDisplayValue : node.displayValue
            valueColor = Theme.numberColor
        case .boolean:
            valueText = node.displayValue
            valueColor = Theme.booleanColor
        case .null:
            valueText = "null"
            valueColor = Theme.nullColor
        }

        cellView?.node = node
        cellView?.configure(key: keyText, value: valueText, valueColor: valueColor, isContainer: isContainer, truncated: isTruncated)

        if let vm = viewModel, !vm.searchQuery.isEmpty,
           vm.searchMatchNodeIDs.contains(ObjectIdentifier(node)),
           let cell = cellView {
            applySearchTextHighlight(to: cell, query: vm.searchQuery.lowercased())
        }

        return cellView
    }
    
    private func applySearchTextHighlight(to cellView: JSONCellView, query: String) {
        highlightMatchesInTextField(cellView.keyTextField, query: query)
        highlightMatchesInTextField(cellView.valueTextField, query: query)
    }
    
    private func highlightMatchesInTextField(_ textField: NSTextField, query: String) {
        let text = textField.stringValue
        guard !text.isEmpty else { return }
        let lowerText = text.lowercased()
        guard lowerText.contains(query) else { return }
        
        let font = textField.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let color = textField.textColor ?? .labelColor
        
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: font
        ])
        
        var searchStart = lowerText.startIndex
        while let range = lowerText.range(of: query, range: searchStart..<lowerText.endIndex) {
            let nsRange = NSRange(range, in: text)
            attributed.addAttribute(.backgroundColor, value: Theme.searchTextHighlightColor, range: nsRange)
            searchStart = range.upperBound
        }
        
        textField.attributedStringValue = attributed
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] else { return }
        outlineView.reloadItem(item, reloadChildren: false)
    }
    
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] else { return }
        outlineView.reloadItem(item, reloadChildren: false)
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // 允许选中 JSON 节点和闭合括号节点
        return item is IndexedJSONNode || item is JSONClosingNode
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let oldContainer = highlightedContainerNode
        let selectedRow = outlineView.selectedRow
        
        // 确定新的高亮容器
        var newContainer: IndexedJSONNode? = nil
        if selectedRow >= 0 {
            if let node = outlineView.item(atRow: selectedRow) as? IndexedJSONNode,
               node.type.isContainer {
                newContainer = node
            } else if let closingNode = outlineView.item(atRow: selectedRow) as? JSONClosingNode {
                newContainer = closingNode.parentNode
            }
        }
        
        // 无变化则跳过
        if oldContainer === newContainer { return }
        highlightedContainerNode = newContainer
        
        // 只刷新受影响的行（旧+新容器的开始行和闭合行）
        var rowsToRefresh = IndexSet()
        let totalRows = outlineView.numberOfRows
        for container in [oldContainer, newContainer] {
            guard let c = container else { continue }
            let openRow = outlineView.row(forItem: c)
            if openRow >= 0 {
                rowsToRefresh.insert(openRow)
                
                // 向下扫描找到匹配的闭合括号行
                for r in (openRow + 1)..<totalRows {
                    if let closing = outlineView.item(atRow: r) as? JSONClosingNode,
                       closing.parentNode === c {
                        rowsToRefresh.insert(r)
                        break
                    }
                }
            }
        }
        
        if !rowsToRefresh.isEmpty {
            let jsonColIndex = outlineView.column(withIdentifier: NSUserInterfaceItemIdentifier("json"))
            if jsonColIndex >= 0 {
                outlineView.reloadData(forRowIndexes: rowsToRefresh, columnIndexes: IndexSet(integer: jsonColIndex))
            }
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let rowView = AlwaysEmphasizedRowView()
        configureSearchHighlight(rowView: rowView, item: item)
        return rowView
    }
    
    private func configureSearchHighlight(rowView: AlwaysEmphasizedRowView, item: Any) {
        guard let vm = viewModel, !vm.searchMatchNodeIDs.isEmpty else {
            rowView.isSearchMatch = false
            rowView.isCurrentSearchMatch = false
            return
        }
        if let node = item as? IndexedJSONNode {
            let nodeID = ObjectIdentifier(node)
            rowView.isSearchMatch = vm.searchMatchNodeIDs.contains(nodeID)
            rowView.isCurrentSearchMatch = (node === vm.currentSearchMatch)
        } else {
            rowView.isSearchMatch = false
            rowView.isCurrentSearchMatch = false
        }
    }
    
    @objc private func loadMoreAction(_ sender: NSButton) {
        // 按钮嵌套在 NSTableCellView 中，需要获取父视图来找到正确的行
        guard let cellView = sender.superview else { return }
        let row = outlineView.row(for: cellView)
        guard row >= 0, let item = outlineView.item(atRow: row) as? JSONLoadMoreNode else { return }

        _ = item.parent.loadMore()
        outlineView.reloadItem(item.parent, reloadChildren: true)
    }
}

// MARK: - NSMenuDelegate

extension UnifiedJsonViewController: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0,
              let item = outlineView.item(atRow: clickedRow) as? IndexedJSONNode else {
            return
        }
        
        if item.key != nil {
            let copyKeyItem = NSMenuItem(title: "Copy Key", action: #selector(copyKeyAction), keyEquivalent: "")
            copyKeyItem.representedObject = item
            menu.addItem(copyKeyItem)
        }
        
        if !item.type.isContainer {
            let copyValueItem = NSMenuItem(title: "Copy Value", action: #selector(copyValueAction), keyEquivalent: "")
            copyValueItem.representedObject = item
            menu.addItem(copyValueItem)
        }
        
        if item.key != nil {
            let copyPairItem = NSMenuItem(title: "Copy Key-Value", action: #selector(copyKeyPairAction), keyEquivalent: "")
            copyPairItem.representedObject = item
            menu.addItem(copyPairItem)
        }
        
        let copyJSONItem = NSMenuItem(title: "Copy JSON", action: #selector(copyJSONAction), keyEquivalent: "")
        copyJSONItem.representedObject = item
        menu.addItem(copyJSONItem)
        
        // 编辑选项
        menu.addItem(NSMenuItem.separator())

        if item.key != nil {
            let editKeyItem = NSMenuItem(title: "编辑 Key", action: #selector(editKeyAction), keyEquivalent: "")
            editKeyItem.representedObject = item
            menu.addItem(editKeyItem)
        }

        if !item.type.isContainer {
            let editValueItem = NSMenuItem(title: "编辑 Value", action: #selector(editValueAction), keyEquivalent: "")
            editValueItem.representedObject = item
            menu.addItem(editValueItem)
        }

        // 添加分隔线和删除选项
        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "删除", action: #selector(deleteNodeAction), keyEquivalent: "")
        deleteItem.representedObject = item
        menu.addItem(deleteItem)
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
        // 去除字符串类型的引号
        let value = item.displayValue
        let cleanValue: String
        if item.type == .string && value.count >= 2 && value.first == "\"" && value.last == "\"" {
            cleanValue = String(value.dropFirst().dropLast())
        } else {
            cleanValue = value
        }
        pasteboard.setString(cleanValue, forType: .string)
    }
    
    @objc private func copyKeyPairAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode,
              let key = item.key else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // 去除字符串类型的引号
        let rawValue = item.rawString
        let cleanValue: String
        if item.type == .string && rawValue.count >= 2 && rawValue.first == "\"" && rawValue.last == "\"" {
            cleanValue = String(rawValue.dropFirst().dropLast())
        } else {
            cleanValue = rawValue
        }
        let text = "\(key): \(cleanValue)"
        pasteboard.setString(text, forType: .string)
    }
    
    @objc private func copyJSONAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.rawString, forType: .string)
    }
    
    @objc private func deleteNodeAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        deleteNode(item)
    }

    @objc private func editKeyAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        editNodeFromMenu(item, field: "key")
    }

    @objc private func editValueAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode else { return }
        editNodeFromMenu(item, field: "value")
    }
}

// MARK: - Search Bar Public API

extension UnifiedJsonViewController {
    
    func toggleSearchBar() {
        isSearchBarVisible = !isSearchBarVisible
        updateContentLayout()
        if isSearchBarVisible {
            view.window?.makeFirstResponder(searchField)
            if let query = viewModel?.searchQuery, !query.isEmpty {
                searchField?.stringValue = query
            }
        } else {
            viewModel?.clearSearch()
            searchField?.stringValue = ""
            updateSearchHighlighting()
        }
    }
    
    func navigateToNextMatch() {
        guard let vm = viewModel, !vm.searchResults.isEmpty else { return }
        vm.nextSearchMatch()
    }
    
    func navigateToPreviousMatch() {
        guard let vm = viewModel, !vm.searchResults.isEmpty else { return }
        vm.previousSearchMatch()
    }
    
    private func handleSearchStateChanged() {
        updateSearchCountLabel()
        updateSearchHighlighting()
        scrollToCurrentMatch()
    }
    
    private func updateSearchCountLabel() {
        guard let vm = viewModel else {
            searchCountLabel?.stringValue = ""
            return
        }
        if vm.searchQuery.isEmpty {
            searchCountLabel?.stringValue = ""
        } else if vm.searchResults.isEmpty {
            searchCountLabel?.stringValue = "无匹配"
        } else {
            searchCountLabel?.stringValue = "\(vm.currentSearchIndex + 1) / \(vm.searchResults.count)"
        }
    }
    
    private func updateSearchHighlighting() {
        let visibleRange = outlineView.rows(in: outlineView.visibleRect)
        guard visibleRange.length > 0 else { return }
        
        for row in visibleRange.location..<(visibleRange.location + visibleRange.length) {
            guard let rowView = outlineView.rowView(atRow: row, makeIfNecessary: false) as? AlwaysEmphasizedRowView else { continue }
            if let item = outlineView.item(atRow: row) {
                configureSearchHighlight(rowView: rowView, item: item)
            }
            rowView.needsDisplay = true
        }
    }
    
    private func scrollToCurrentMatch() {
        guard let vm = viewModel, let matchNode = vm.currentSearchMatch else { return }
        
        expandAncestors(of: matchNode)
        
        let row = outlineView.row(forItem: matchNode)
        guard row >= 0 else { return }
        
        outlineView.scrollRowToVisible(row)
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    private func expandAncestors(of node: IndexedJSONNode) {
        guard let vm = viewModel else { return }
        var ancestors: [IndexedJSONNode] = []
        var current = node
        while let parent = vm.nodeParentMap[ObjectIdentifier(current)] {
            ancestors.append(parent)
            current = parent
        }
        for ancestor in ancestors.reversed() {
            outlineView.expandItem(ancestor)
        }
    }
    
    @objc private func searchNextAction() {
        navigateToNextMatch()
    }
    
    @objc private func searchPreviousAction() {
        navigateToPreviousMatch()
    }
    
    @objc private func closeSearchBarAction() {
        isSearchBarVisible = false
        updateContentLayout()
        viewModel?.clearSearch()
        searchField?.stringValue = ""
        updateSearchHighlighting()
    }
}

// MARK: - NSSearchFieldDelegate

extension UnifiedJsonViewController: NSSearchFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        
        searchDebounceTimer?.invalidate()
        let query = field.stringValue
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel?.searchQuery = query
            self.viewModel?.performSearch()
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField else { return false }
        
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                navigateToPreviousMatch()
            } else {
                navigateToNextMatch()
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            closeSearchBarAction()
            return true
        }
        return false
    }
}

// MARK: - JSONPathComponent (Private)

private enum JSONPathComponent {
    case objectKey(String)
    case arrayIndex(Int)
}
