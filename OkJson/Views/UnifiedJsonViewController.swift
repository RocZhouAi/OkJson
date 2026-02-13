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
    private var errorLabel: NSTextField?
    
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
    
    // 外部访问
    var scrollView: NSScrollView? {
        return treeScrollView
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTimer?.invalidate()
        lineNumberRefreshTimer?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        // setupTextView() // Removed
        setupTreeView()
        setupEmptyStateView()
        setupErrorLabel()
        setupViewModelBindings() // Simplifed bindings
        
        // 初始状态
        // updateModeDisplay() // Removed
        updateContent()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if needsContentUpdate {
            updateContent()
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()

        // 确保 TreeView 列宽始终填满视图
        guard let outlineView = outlineView,
              let column = outlineView.tableColumns.last else { return }

        if column.width < outlineView.visibleRect.width {
            column.width = outlineView.visibleRect.width
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupTreeView() {
        treeScrollView = NSScrollView()
        treeScrollView.hasVerticalScroller = true
        treeScrollView.hasHorizontalScroller = true
        treeScrollView.autohidesScrollers = true
        treeScrollView.borderType = .noBorder
        treeScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(treeScrollView)
        
        NSLayoutConstraint.activate([
            treeScrollView.topAnchor.constraint(equalTo: view.topAnchor),
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
        // Removed double click to switch mode
        /*
        pastableOutlineView.onDoubleClickEmptyArea = { [weak self] in
            self?.switchMode(to: .editing)
        }
        */
        pastableOutlineView.onDeleteSelectedItem = { [weak self] in
            self?.deleteSelectedNode()
        }
        outlineView = pastableOutlineView
        outlineView.headerView = nil
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        outlineView.selectionHighlightStyle = .regular
        outlineView.usesAutomaticRowHeights = true
        
        // 添加行号列
        lineNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lineNumber"))
        lineNumberColumn?.title = "#"
        lineNumberColumn?.width = showLineNumbers ? 40 : 0
        lineNumberColumn?.minWidth = 0
        lineNumberColumn?.maxWidth = 40
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
            container.topAnchor.constraint(equalTo: view.topAnchor),
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
        iconView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        iconView.contentTintColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)
        stackView.addArrangedSubview(iconView)
        
        let label = NSTextField(labelWithString: "粘贴 JSON 开始格式化")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        stackView.addArrangedSubview(label)
        
        let hintLabel = NSTextField(labelWithString: "⌘V 粘贴")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        stackView.addArrangedSubview(hintLabel)
        
        emptyStateView = container
    }
    
    private func setupErrorLabel() {
        errorLabel = NSTextField(wrappingLabelWithString: "")
        errorLabel?.textColor = .systemRed
        errorLabel?.font = .systemFont(ofSize: 13)
        errorLabel?.isHidden = true
        errorLabel?.translatesAutoresizingMaskIntoConstraints = false
        if let cell = errorLabel?.cell as? NSTextFieldCell {
            cell.isSelectable = true // Ensure error can be copied
            cell.allowsEditingTextAttributes = true
        }
        
        view.addSubview(errorLabel!)
        
        NSLayoutConstraint.activate([
            errorLabel!.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            errorLabel!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupViewModelBindings() {
        // No need to bind TextView
        viewModel?.onInputTextChanged = { [weak self] text in
            // Do nothing for view update here, layout is updated via updateContent (Tree)
            // Or if we had a simplified text view for errors.
            self?.updatePlaceholderVisibility()
        }
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
            // 显示树形视图
            errorLabel?.isHidden = true
            emptyStateView?.isHidden = true
            treeScrollView.isHidden = false
            
            outlineView.reloadData()
            
            // 直接展开全部节点
            if viewModel?.parsedTree != nil {
                outlineView.expandItem(nil, expandChildren: true)
            }
            adjustColumnWidth()
            outlineView.scroll(NSPoint.zero)
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
    }
    
    // MARK: - Paste Handling
    
    func handlePasteFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }
        
        // 粘贴后立即隐藏错误和空状态，避免闪烁
        errorLabel?.isHidden = true
        emptyStateView?.isHidden = true
        
        // Direct to ViewModel
        viewModel?.inputText = clipboardString
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
            lineNumberColumn.width = showLineNumbers ? 40 : 0
        }
        outlineView?.reloadData()
    }
    
    @objc private func outlineViewItemDidExpandOrCollapse(_ notification: Notification) {
        refreshLineNumberColumn()
    }
    
    @objc private func outlineViewItemDidCollapseNotification(_ notification: Notification) {
        refreshLineNumberColumn()
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
        }
    }
    
    // MARK: - Context Menu
    
    private func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }
    
    // REMOVED: highlightSyntax()

    
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
        
        // Root node deletion is just clear
        if node.startOffset == 0 && node.endOffset >= root.endOffset {
            handleClearContent()
            return
        }
        
        // 使用当前树的排序状态，而非全局设置
        let shouldSortKeys = root.shouldSortKeys
        // Direct Access to Data from Tree
        let originalData = root.jsonData
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Validate offsets
            // Use fullStartOffset to include the key (for object properties)
            let start = node.fullStartOffset
            let end = node.endOffset
            let totalCount = originalData.count
            
            guard start >= 0, end <= totalCount, start < end else { return }
            
            // Logic to remove comma: Same logic, but on Data directly
            var removeStart = start
            var removeEnd = end
            
            // Look specific deletion range extended to commas
            // Strategy:
            // 1. Check Previous generic char (skipping whitespace)
            // 2. If it is ',', include it.
            // 3. Else, check Next generic char (skipping whitespace).
            // 4. If it is ',' include it.
            
            var foundComma = false
            
            // Backward Scan in Data (using simple subscription, Data is fast)
            var i = start - 1
            while i >= 0 {
                let b = originalData[i]
                if b == 32 || b == 10 || b == 13 || b == 9 {
                    i -= 1
                    continue
                }
                if b == 44 { // ,
                    foundComma = true
                    removeStart = i
                }
                break
            }
            
            if !foundComma {
                // Forward Scan
                i = end
                while i < totalCount {
                    let b = originalData[i]
                    if b == 32 || b == 10 || b == 13 || b == 9 {
                        i += 1
                        continue
                    }
                    if b == 44 { // ,
                        foundComma = true
                        removeEnd = i + 1
                    }
                    break
                }
            }
            
            // Create New Data
            var newData = Data()
            newData.reserveCapacity(totalCount - (removeEnd - removeStart))
            newData.append(originalData[0..<removeStart])
            newData.append(originalData[removeEnd..<totalCount])
            
            // 1. Parse New Tree (Zero Copy of String)
            if let newTree = IndexedJSONNode.fromData(newData, shouldSortKeys: shouldSortKeys) {
                
                // 2. We still need String for TextView (Inevitably)
                // Use String(decoding:) which is generally optimized
                let newString = String(decoding: newData, as: UTF8.self)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 更新 ViewModel（临时禁用回调）
                    viewModel.inputText = newString
                    viewModel.formattedText = ""
                    viewModel.parseError = nil
                    
                    let savedCallback = viewModel.onParsedTreeChanged
                    viewModel.onParsedTreeChanged = nil
                    viewModel.parsedTree = newTree
                    viewModel.onParsedTreeChanged = savedCallback
                    
                    // 刷新并直接展开全部
                    self.outlineView.reloadData()
                    self.outlineView.expandItem(nil, expandChildren: true)
                    self.adjustColumnWidth()
                }
            }
        }
    }
    }


// MARK: - NSTextViewDelegate

// MARK: - NSTextViewDelegate - REMOVED

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
            
            return JSONClosingNode(type: node.type)
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
                textField.textColor = .labelColor
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
        var valueColor: NSColor = .labelColor
        var isContainer = false

        let isExpanded = outlineView.isItemExpanded(item)

        switch node.type {
        case .object:
            isContainer = true
            valueText = isExpanded ? "{" : "{...} (\(node.childCount) keys)"
        case .array:
            isContainer = true
            valueText = isExpanded ? "[" : "[...] (\(node.childCount) items)"
        case .string:
            valueText = node.displayValue
            valueColor = .systemGreen
        case .number:
            valueText = node.displayValue
            valueColor = .systemBlue
        case .boolean:
            valueText = node.displayValue
            valueColor = .systemOrange
        case .null:
            valueText = "null"
            valueColor = .systemGray
        }

        cellView?.configure(key: keyText, value: valueText, valueColor: valueColor, isContainer: isContainer)

        return cellView
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
        // 只允许选中 JSON 节点，不允许选中加载更多等其他类型
        return item is IndexedJSONNode
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        // 使用自定义行视图，确保选中高亮始终可见（包括非 first responder 状态）
        let rowView = AlwaysEmphasizedRowView()
        return rowView
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
        
        if let key = item.key {
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
        pasteboard.setString(item.displayValue, forType: .string)
    }
    
    @objc private func copyKeyPairAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? IndexedJSONNode,
              let key = item.key else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let text = "\"\(key)\": \(item.rawString)"
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
}

// MARK: - JSONPathComponent (Private)

private enum JSONPathComponent {
    case objectKey(String)
    case arrayIndex(Int)
}
