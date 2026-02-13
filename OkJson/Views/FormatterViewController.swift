//  FormatterViewController.swift
//  OkJson
//
//  JSON formatter view controller - Pure AppKit

import AppKit

class FormatterViewController: NSSplitViewController {
    
    // MARK: - Properties
    
    private var unifiedViewController: UnifiedJsonViewController!
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
        return unifiedViewController?.scrollView
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
        
        // 创建统一视图控制器
        unifiedViewController = UnifiedJsonViewController(viewModel: viewModel)
        unifiedViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
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
        // onModeChanged removed - Pure Tree Mode
        
        let item = NSSplitViewItem(viewController: unifiedViewController)
        item.minimumThickness = 300
        item.holdingPriority = .defaultLow
        addSplitViewItem(item)
        
        // 绑定 ViewModel 事件
        viewModel.onParsedTreeChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.unifiedViewController.updateContent()
                
                if self.isUnifiedMode {
                    if !self.viewModel.formattedText.isEmpty {
                        self.viewModel.inputText = self.viewModel.formattedText
                    }
                    
                    if self.preferTreeInUnifiedMode && self.viewModel.parsedTree != nil {
                        self.unifiedViewController.switchMode(to: .viewing)
                    }
                }
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    
    @objc private func handleFormatJSON() {
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
        viewModel.minifyJSON()
    }
    
    @objc private func handlePasteJSON() {
        viewModel.pasteFromClipboard()
        if isUnifiedMode {
            if viewModel.parsedTree != nil && !viewModel.formattedText.isEmpty {
                viewModel.inputText = viewModel.formattedText
            }
        }
    }
    
    @objc private func handleClearInput() {
        viewModel.clear()
        unifiedViewController.switchMode(to: .editing)
    }
    
    @objc private func handleCopyFormattedResult() {
        viewModel.copyToClipboard()
    }
    
    @objc private func handleSortKeys() {
        // 手动排序
        viewModel.formatJSON(sortKeysOverride: true)
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
            view.layer?.borderColor = NSColor.controlAccentColor.cgColor
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

struct JSONClosingNode {
    let type: NodeType
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

class JSONCellView: NSTableCellView {

    private(set) var keyTextField: NSTextField!
    private(set) var valueTextField: NSTextField!

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
        keyTextField.textColor = .systemPurple
        keyTextField.isSelectable = false
        keyTextField.isEditable = false
        keyTextField.isBordered = false
        keyTextField.drawsBackground = false
        keyTextField.translatesAutoresizingMaskIntoConstraints = false
        keyTextField.cell?.usesSingleLineMode = true
        keyTextField.cell?.lineBreakMode = .byClipping
        keyTextField.setContentHuggingPriority(.required, for: .horizontal)
        keyTextField.setContentCompressionResistancePriority(.required, for: .horizontal)

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

        addSubview(keyTextField)
        addSubview(valueTextField)
        self.textField = valueTextField

        NSLayoutConstraint.activate([
            // Key: 左对齐，顶部对齐
            keyTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyTextField.topAnchor.constraint(equalTo: topAnchor, constant: 2),

            // Value: 紧跟 Key 后面，顶部对齐，填满右侧空间
            valueTextField.leadingAnchor.constraint(equalTo: keyTextField.trailingAnchor),
            valueTextField.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            valueTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueTextField.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -2)
        ])
    }

    override func layout() {
        let keyWidth = keyTextField.isHidden ? 0 : keyTextField.intrinsicContentSize.width
        let availableWidth = bounds.width - keyWidth
        if availableWidth > 0 {
            valueTextField.preferredMaxLayoutWidth = availableWidth
        }
        super.layout()
    }

    // 点击穿透到 OutlineView，行选中/取消选中由 OutlineView 处理
    // 文本复制通过右键菜单 Copy Key / Copy Value 实现
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)

        // 三角箭头（NSButton）必须正常处理展开/折叠
        if let button = hit as? NSButton {
            return button
        }

        return nil
    }

    func configure(key: String?, value: String, valueColor: NSColor, isContainer: Bool) {
        if let key = key {
            keyTextField.stringValue = key + " "
            keyTextField.isHidden = false
        } else {
            keyTextField.stringValue = ""
            keyTextField.isHidden = true
        }

        valueTextField.stringValue = value
        valueTextField.textColor = valueColor
    }
}

// MARK: - IndexedJSONNode + AppKit Display

extension IndexedJSONNode {
    
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
        
        if let key = key {
            result.append(NSAttributedString(string: "\"\(key)\"", attributes: keyAttributes))
            result.append(NSAttributedString(string: ": ", attributes: punctuationAttributes))
        }
        
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

// MARK: - AlwaysEmphasizedRowView

/// 自定义行视图：选中时始终显示高亮背景（修复 usesAutomaticRowHeights 多行行高亮失效问题）
class AlwaysEmphasizedRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { return true }
        set { }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if isSelected {
            // 使用系统强调色，覆盖整个 bounds（而非 dirtyRect），确保多行行完整高亮
            NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
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
        
        var isEmptyArea = false
        
        if clickedRow == -1 {
            isEmptyArea = true
        } else if let _ = tableColumns.first {
            let level = self.level(forRow: clickedRow)
            let indentation = CGFloat(level + 1) * self.indentationPerLevel
            let estimatedContentWidth = indentation + 300
            
            if localPoint.x > estimatedContentWidth {
                isEmptyArea = true
            }
        }
        
        if isEmptyArea {
            onDoubleClickEmptyArea?()
        }
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
        print("[PastableOutlineView] mouseDown - clickCount: \(event.clickCount)")
        let locationInWindow = event.locationInWindow
        let locationInView = self.convert(locationInWindow, from: nil)
        let row = self.row(at: locationInView)
        print("[PastableOutlineView] mouseDown - location: \(locationInView), row at point: \(row)")
        
        if event.clickCount == 1 {
            isAllSelected = false
        }
        super.mouseDown(with: event)
        print("[PastableOutlineView] mouseDown - after super, selectedRow: \(self.selectedRow)")
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
            enclosingScrollView?.layer?.borderColor = NSColor.controlAccentColor.cgColor
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
