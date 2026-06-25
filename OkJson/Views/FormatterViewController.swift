//  FormatterViewController.swift
//  OkJson
//
//  JSON formatter view controller - Pure AppKit

import AppKit

class FormatterViewController: NSSplitViewController {
    
    // MARK: - Properties

    var unifiedViewController: UnifiedJsonViewController!
    /// 重构后的文本编辑器控制器（负责显示；树形 unifiedViewController 暂保留但不显示，计划③删）
    var editorViewController: JSONEditorViewController!
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
        return editorViewController?.scrollView
    }
    
    /// Focus state for Compare mode (border highlight)
    var isFocused: Bool = false {
        didSet {
            updateFocusBorder()
        }
    }
    
    /// 是否显示列头（包含标题、颜色标记、关闭按钮）
    var showHeader: Bool = false {
        didSet {
            unifiedViewController.isHeaderVisible = showHeader
        }
    }
    
    /// 是否显示关闭按钮
    var showCloseButton: Bool = true {
        didSet {
            unifiedViewController.isCloseButtonVisible = showCloseButton
        }
    }

    /// 关闭列的回调
    var onCloseRequest: (() -> Void)?

    /// Callback when this panel gains focus (clicked)
    var onFocusChanged: ((Bool) -> Void)?

    /// Callback when JSON is formatted and tree is ready
    var onFormatted: (() -> Void)?
    
    // Legacy close button removed in favor of ColumnHeaderView
    
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
        
        // 创建统一视图控制器
        unifiedViewController = UnifiedJsonViewController(viewModel: viewModel)
        unifiedViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
        }
        unifiedViewController.onCloseRequest = { [weak self] in
            self?.onCloseRequest?() // Forward close request from header
        }
        unifiedViewController.onPasteDetected = { [weak self] in
            guard let self = self else { return }

            // Auto-Format on Paste (Delay Strategy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                self.unifiedViewController.isDirty = false
                self.viewModel.formatJSON()

                if self.viewModel.parsedTree != nil {
                    if self.isUnifiedMode {
                        if !self.viewModel.formattedText.isEmpty {
                            self.viewModel.inputText = self.viewModel.formattedText
                        }

                        if self.preferTreeInUnifiedMode {
                            self.unifiedViewController.switchMode(to: .viewing)
                        }
                    }
                }
            }
        }

        // 重构：创建文本编辑器并作为列显示内容（树形 unifiedViewController 暂保留但不显示）
        editorViewController = JSONEditorViewController(viewModel: viewModel)
        editorViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
        }

        let item = NSSplitViewItem(viewController: editorViewController)
        item.minimumThickness = 300
        item.holdingPriority = .defaultLow
        addSplitViewItem(item)

        // 绑定 ViewModel 事件
        viewModel.onParsedTreeChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.unifiedViewController.updateContent()

                // 重构：把格式化结果推给文本编辑器显示
                if !self.viewModel.formattedText.isEmpty {
                    self.editorViewController.setText(self.viewModel.formattedText)
                }

                if self.isUnifiedMode {
                    if !self.viewModel.formattedText.isEmpty {
                        self.viewModel.inputText = self.viewModel.formattedText
                    }

                    if self.preferTreeInUnifiedMode && self.viewModel.parsedTree != nil {
                        self.unifiedViewController.switchMode(to: .viewing)
                    }
                }

                self.onFormatted?()
            }
        }
        
        viewModel.onParseErrorChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.unifiedViewController.updateContent()
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
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSortKeys),
            name: .sortKeys, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFindInJSON),
            name: .findInJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFindNextInJSON),
            name: .findNextInJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFindPreviousInJSON),
            name: .findPreviousInJSON, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions（只有焦点列响应全局通知）
    
    @objc private func handleFormatJSON() {
        guard isFocused else { return }
        
        if !unifiedViewController.isDirty && viewModel.parsedTree != nil {
            return
        }
        
        unifiedViewController.isDirty = false
        viewModel.formatJSON()
        
        if isUnifiedMode {
            if viewModel.parsedTree != nil && !viewModel.formattedText.isEmpty {
                viewModel.inputText = viewModel.formattedText
            }
        }
    }
    
    @objc private func handleMinifyJSON() {
        guard isFocused else { return }
        viewModel.minifyJSON()
    }
    
    @objc private func handlePasteJSON() {
        guard isFocused else { return }
        viewModel.pasteFromClipboard()
        if isUnifiedMode {
            if viewModel.parsedTree != nil && !viewModel.formattedText.isEmpty {
                viewModel.inputText = viewModel.formattedText
            }
        }
    }
    
    @objc private func handleClearInput() {
        guard isFocused else { return }
        viewModel.clear()
        unifiedViewController.switchMode(to: .editing)
    }
    
    @objc private func handleCopyFormattedResult() {
        guard isFocused else { return }
        viewModel.copyToClipboard()
    }
    
    @objc private func handleSortKeys() {
        guard isFocused else { return }
        viewModel.markAsModified()
        viewModel.formatJSON(sortKeysOverride: true)
    }
    
    @objc private func handleFindInJSON() {
        guard isFocused else { return }
        editorViewController.showFind(1)  // showFindInterface
    }

    @objc private func handleFindNextInJSON() {
        guard isFocused else { return }
        editorViewController.showFind(2)  // nextMatch
    }

    @objc private func handleFindPreviousInJSON() {
        guard isFocused else { return }
        editorViewController.showFind(3)  // previousMatch
    }
    
    // MARK: - View Switching
    
    public func switchToOutput() {
        guard isUnifiedMode && preferTreeInUnifiedMode else { return }
        unifiedViewController.switchMode(to: .viewing)
    }
    
    public func switchToInput() {
        guard isUnifiedMode && preferTreeInUnifiedMode else { return }
        unifiedViewController.switchMode(to: .editing)
    }
    
    // MARK: - Focus Border
    
    private func updateFocusBorder() {
        view.wantsLayer = true
        if isFocused {
            view.layer?.borderColor = Theme.focusBorderColor.cgColor
            view.layer?.borderWidth = 2
            view.layer?.cornerRadius = 4
        } else {
            view.layer?.borderWidth = 0
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onFocusChanged?(true)
    }
}

// MARK: - Helper Views and Types (保留必要的辅助类)

class JSONClosingNode {
    let type: NodeType
    // 关联的父容器节点（用于括号高亮配对）
    weak var parentNode: IndexedJSONNode?
    init(type: NodeType, parentNode: IndexedJSONNode? = nil) {
        self.type = type
        self.parentNode = parentNode
    }
}

struct JSONLoadMoreNode {
    let parent: IndexedJSONNode
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

// MARK: - JSONCellView (Key/Value 分离布局)

class JSONCellView: NSTableCellView, NSTextFieldDelegate {

    private(set) var keyTextField: NSTextField!
    private(set) var valueTextField: NSTextField!
    private var showFullButton: NSButton!

    /// 当前关联的节点
    weak var node: IndexedJSONNode?
    /// 是否为容器节点
    private var isContainerNode: Bool = false
    /// 当前值是否被截断
    private var isValueTruncated: Bool = false
    /// 编辑完成回调: (node, editedField, newText)
    /// editedField: "key" 或 "value"
    var onEditCommitted: ((IndexedJSONNode, String, String) -> Void)?
    /// 当前正在编辑的字段
    private var editingField: String?
    /// 编辑前的原始值（用于取消编辑时恢复）
    private var originalEditValue: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Key TextField: 单行，不换行
        keyTextField = NSTextField(labelWithString: "")
        keyTextField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        keyTextField.textColor = Theme.keyColor
        keyTextField.isSelectable = false
        keyTextField.isEditable = false
        keyTextField.isBordered = false
        keyTextField.drawsBackground = false
        keyTextField.translatesAutoresizingMaskIntoConstraints = false
        keyTextField.cell?.usesSingleLineMode = true
        keyTextField.cell?.lineBreakMode = .byClipping
        keyTextField.setContentHuggingPriority(.required, for: .horizontal)
        keyTextField.setContentCompressionResistancePriority(.required, for: .horizontal)
        keyTextField.delegate = self

        // Value TextField: 多行自动换行
        valueTextField = NSTextField(labelWithString: "")
        valueTextField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        valueTextField.isSelectable = false
        valueTextField.isEditable = false
        valueTextField.isBordered = false
        valueTextField.drawsBackground = false
        valueTextField.backgroundColor = .clear
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        valueTextField.cell?.wraps = true
        valueTextField.cell?.lineBreakMode = .byCharWrapping
        valueTextField.cell?.usesSingleLineMode = false
        valueTextField.maximumNumberOfLines = 0
        valueTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueTextField.delegate = self

        // 完整显示按钮
        showFullButton = NSButton(title: "完整显示", target: self, action: #selector(showFullValue))
        showFullButton.bezelStyle = .inline
        showFullButton.controlSize = .small
        showFullButton.font = NSFont.systemFont(ofSize: 10)
        showFullButton.translatesAutoresizingMaskIntoConstraints = false
        showFullButton.isHidden = true
        showFullButton.setContentHuggingPriority(.required, for: .horizontal)
        showFullButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(keyTextField)
        addSubview(valueTextField)
        addSubview(showFullButton)
        self.textField = valueTextField

        NSLayoutConstraint.activate([
            // Key: 左对齐，顶部对齐
            keyTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyTextField.topAnchor.constraint(equalTo: topAnchor, constant: 2),

            // Value: 紧跟 Key 后面，顶部对齐
            valueTextField.leadingAnchor.constraint(equalTo: keyTextField.trailingAnchor),
            valueTextField.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            valueTextField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            // 按钮: 紧跟 Value 后面，垂直居中
            showFullButton.leadingAnchor.constraint(equalTo: valueTextField.trailingAnchor, constant: 4),
            showFullButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
            showFullButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 10),
        ])
    }

    @objc private func showFullValue() {
        guard let node = node else { return }
        let fullValue = node.displayValue
        LargeValuePopover.show(relativeTo: showFullButton.bounds, of: showFullButton, value: fullValue, size: node.formattedSize)
    }

    // 点击穿透到 OutlineView，行选中/取消选中由 OutlineView 处理
    // 编辑中的 TextField 需要正常接收事件
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)

        // 三角箭头（NSButton）必须正常处理展开/折叠
        if let button = hit as? NSButton {
            return button
        }

        // 编辑中的 TextField 必须接收鼠标事件
        if let tf = hit as? NSTextField, tf.isEditable {
            return tf
        }

        return nil
    }

    func configure(key: String?, value: String, valueColor: NSColor, isContainer: Bool, truncated: Bool = false) {
        // 退出编辑状态
        endEditing()

        isContainerNode = isContainer
        isValueTruncated = truncated

        if let key = key {
            keyTextField.stringValue = key + " "
            keyTextField.isHidden = false
        } else {
            keyTextField.stringValue = ""
            keyTextField.isHidden = true
        }

        valueTextField.stringValue = value
        valueTextField.textColor = truncated ? Theme.punctuationColor : valueColor
        showFullButton.isHidden = !truncated
    }

    // MARK: - 编辑模式

    /// 进入编辑模式
    /// - Parameter field: "key" 或 "value"
    func enterEditMode(field: String) {
        guard let node = node else { return }

        let targetField: NSTextField
        if field == "key" {
            guard node.key != nil else { return }
            targetField = keyTextField
            // 显示纯 key 内容（去掉引号和冒号）
            let rawKey = node.key ?? ""
            originalEditValue = keyTextField.stringValue
            targetField.stringValue = rawKey
        } else {
            // 容器节点不允许编辑 value
            guard !isContainerNode else { return }
            targetField = valueTextField
            originalEditValue = valueTextField.stringValue
            // 字符串类型去掉外层引号
            if node.type == .string {
                let raw = node.displayValue
                if raw.count >= 2, raw.first == "\"", raw.last == "\"" {
                    targetField.stringValue = String(raw.dropFirst().dropLast())
                }
            }
        }

        editingField = field
        targetField.isEditable = true
        targetField.isSelectable = true
        targetField.isBordered = true
        targetField.drawsBackground = true
        targetField.backgroundColor = .textBackgroundColor
        targetField.becomeFirstResponder()
        // 全选文本
        targetField.currentEditor()?.selectAll(nil)
    }

    /// 退出编辑模式（不提交）
    func endEditing() {
        for tf in [keyTextField, valueTextField] {
            guard let tf = tf else { continue }
            tf.isEditable = false
            tf.isSelectable = false
            tf.isBordered = false
            tf.drawsBackground = false
        }
        editingField = nil
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter 提交编辑
            commitEdit(control as? NSTextField)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape 取消编辑
            cancelEdit(control as? NSTextField)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField,
              editingField != nil else { return }
        commitEdit(tf)
    }

    private func commitEdit(_ textField: NSTextField?) {
        guard let textField = textField,
              let field = editingField,
              let node = node else {
            endEditing()
            return
        }

        let newText = textField.stringValue
        endEditing()
        onEditCommitted?(node, field, newText)
    }

    private func cancelEdit(_ textField: NSTextField?) {
        guard let textField = textField else {
            endEditing()
            return
        }
        textField.stringValue = originalEditValue
        endEditing()
        window?.makeFirstResponder(superview)
    }
}

// MARK: - IndexedJSONNode + AppKit Display

extension IndexedJSONNode {
    
    var attributedDisplayString: NSAttributedString {
        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.keyColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let stringAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.stringColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.numberColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let booleanAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.booleanColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let nullAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.errorColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        ]
        
        let punctuationAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.punctuationColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let result = NSMutableAttributedString()
        
        if let key = key {
            result.append(NSAttributedString(string: "\"\(key)\"", attributes: keyAttributes))
            result.append(NSAttributedString(string: ": ", attributes: punctuationAttributes))
        }
        
        switch type {
        case .object:
            result.append(NSAttributedString(string: "{...}", attributes: punctuationAttributes))
            result.append(NSAttributedString(string: " (\(childCount) keys)", attributes: [.foregroundColor: Theme.containerInfoColor, .font: NSFont.systemFont(ofSize: 11)]))
            
        case .array:
            result.append(NSAttributedString(string: "[...]", attributes: punctuationAttributes))
            result.append(NSAttributedString(string: " (\(childCount) items)", attributes: [.foregroundColor: Theme.containerInfoColor, .font: NSFont.systemFont(ofSize: 11)]))
            
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

// MARK: - AlwaysEmphasizedRowView

/// 自定义行视图：选中时始终显示高亮背景（修复 usesAutomaticRowHeights 多行行高亮失效问题）
class AlwaysEmphasizedRowView: NSTableRowView {
    var isSearchMatch: Bool = false
    var isCurrentSearchMatch: Bool = false
    
    override var isEmphasized: Bool {
        get { return true }
        set { }
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        if isCurrentSearchMatch {
            Theme.currentSearchMatchColor.setFill()
            bounds.fill()
        } else if isSearchMatch {
            Theme.searchMatchColor.setFill()
            bounds.fill()
        } else {
            super.drawBackground(in: dirtyRect)
        }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if isSelected {
            Theme.selectionColor.setFill()
            bounds.fill()
        }
    }
}

// MARK: - PastableOutlineView

class PastableOutlineView: NSOutlineView {
    var onPaste: (() -> Void)?
    var onClear: (() -> Void)?
    var onMouseDown: (() -> Void)?
    /// 删除选中节点的回调
    var onDeleteSelectedItem: (() -> Void)?
    
    private(set) var isAllSelected: Bool = false {
        didSet {
            if isAllSelected != oldValue {
                updateSelectionVisual()
            }
        }
    }
    
    var onDoubleClickEmptyArea: (() -> Void)?
    /// 双击节点编辑回调: (row, clickPoint)
    var onDoubleClickNode: ((Int, NSPoint) -> Void)?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        self.target = self
        self.doubleAction = #selector(handleDoubleClick(_:))
    }

    @objc private func handleDoubleClick(_ sender: Any?) {
        let clickedRow = self.clickedRow

        guard let window = self.window else { return }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        let localPoint = self.convert(windowPoint, from: nil)

        if clickedRow == -1 {
            onDoubleClickEmptyArea?()
            return
        }

        // 双击在有效行上 → 触发编辑
        onDoubleClickNode?(clickedRow, localPoint)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            onPaste?()
            return
        }
        
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectAllContent()
            return
        }
        
        // 处理 Delete 键
        let deleteKeyCode: UInt16 = 51
        let forwardDeleteKeyCode: UInt16 = 117
        if event.keyCode == deleteKeyCode || event.keyCode == forwardDeleteKeyCode {
            if isAllSelected {
                // 全选状态下删除所有内容
                clearContent()
            } else if selectedRow >= 0 {
                // 有选中单个节点时删除该节点
                onDeleteSelectedItem?()
            }
            return
        }
        
        isAllSelected = false
        
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            isAllSelected = false
        }
        super.mouseDown(with: event)
        onMouseDown?()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func selectAllContent() {
        isAllSelected = true
        let allRows = IndexSet(integersIn: 0..<numberOfRows)
        selectRowIndexes(allRows, byExtendingSelection: false)
    }
    
    private func clearContent() {
        isAllSelected = false
        onClear?()
    }
    
    private func updateSelectionVisual() {
        if isAllSelected {
            enclosingScrollView?.wantsLayer = true
            enclosingScrollView?.layer?.borderColor = Theme.focusBorderColor.cgColor
            enclosingScrollView?.layer?.borderWidth = 2
            enclosingScrollView?.layer?.cornerRadius = 4
        } else {
            enclosingScrollView?.layer?.borderWidth = 0
            deselectAll(nil)
        }
    }
}

// MARK: - Clickable Header View

class ClickableHeaderView: NSView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
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
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            onPaste?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
        onMouseDown?()
    }
}
