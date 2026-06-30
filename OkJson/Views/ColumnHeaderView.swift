//
//  ColumnHeaderView.swift
//  OkJson
//
//  Created by OkJson on 2026/02/13.
//

import AppKit

class ColumnHeaderView: NSView {
    
    // MARK: - Properties
    
    var title: String {
        get { return titleField.stringValue }
        set {
            titleField.stringValue = newValue
            titleField.needsDisplay = true
        }
    }
    
    /// 是否有未保存改动：true 时文件名左侧显示橙色提示圆点
    var isModified: Bool = false {
        didSet { modifiedDot.isHidden = !isModified }
    }

    var onTitleChanged: ((String) -> Void)?
    var onColorChanged: ((NSColor?) -> Void)? // nil represents default/no color
    var onClose: (() -> Void)?
    
    private var currentColor: NSColor?

    // UI Elements
    private let titleField = EditableTitleField()
    private let modifiedDot = NSView()
    private let colorButton = NSButton()
    private let closeButton = NSButton()
    private let rightStackView = NSStackView()
    private let separatorLine = NSBox()
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // 1. Right StackView (Color + Close)
        rightStackView.orientation = .horizontal
        rightStackView.spacing = 8
        rightStackView.distribution = .fill
        rightStackView.alignment = .centerY
        rightStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightStackView)
        
        // 2. Color Tag Button
        colorButton.bezelStyle = .circular
        colorButton.isBordered = false
        colorButton.title = ""
        colorButton.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Color Tag")
        colorButton.contentTintColor = NSColor.tertiaryLabelColor
        colorButton.target = self
        colorButton.action = #selector(handleColorButtonClick)
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        colorButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        colorButton.heightAnchor.constraint(equalToConstant: 16).isActive = true
        rightStackView.addArrangedSubview(colorButton)
        
        // 3. Close Button
        closeButton.bezelStyle = .inline
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Column")
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(handleCloseButtonClick)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        rightStackView.addArrangedSubview(closeButton)
        
        // 4. Modified Dot —— 未保存提示圆点（橙色，默认隐藏）
        modifiedDot.wantsLayer = true
        modifiedDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        modifiedDot.layer?.cornerRadius = 4
        modifiedDot.isHidden = true
        modifiedDot.translatesAutoresizingMaskIntoConstraints = false
        modifiedDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        modifiedDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        // 5. Title Field —— 默认只读展示态，单击后才进入可编辑态
        titleField.stringValue = "Column"
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = NSColor.labelColor
        titleField.drawsBackground = false
        titleField.isBordered = false
        titleField.isEditable = false
        titleField.isSelectable = false
        titleField.focusRingType = .none
        titleField.delegate = self
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false
        // 长文件名可被压缩截断，不撑破列宽
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // 只读态被单击 → 进入编辑态
        titleField.onClickWhenReadOnly = { [weak self] in
            self?.beginEditing()
        }

        // 6. Leading StackView（圆点 + 文件名）：圆点隐藏时自动收起空间
        let leadingStack = NSStackView(views: [modifiedDot, titleField])
        leadingStack.orientation = .horizontal
        leadingStack.spacing = 6
        leadingStack.distribution = .fill
        leadingStack.alignment = .centerY
        leadingStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leadingStack)

        // 7. Separator
        separatorLine.boxType = .separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)

        // Layout
        NSLayoutConstraint.activate([
            // StackView: Right aligned
            rightStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rightStackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Leading: Fills space between Left and right StackView
            leadingStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leadingStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingStack.trailingAnchor.constraint(equalTo: rightStackView.leadingAnchor, constant: -8),

            // Highlight Line
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(title: String, color: NSColor?, showClose: Bool) {
        self.title = title
        self.closeButton.isHidden = !showClose
        updateColorVisuals(color: color)
    }
    
    /// 单独控制关闭按钮显隐（多列时显示，单列时隐藏）
    func setCloseVisible(_ visible: Bool) {
        closeButton.isHidden = !visible
    }

    private func updateColorVisuals(color: NSColor?) {
        currentColor = color
        if let color = color {
            colorButton.contentTintColor = color
        } else {
            colorButton.contentTintColor = NSColor.tertiaryLabelColor
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleColorButtonClick() {
        // Cycle colors: Gray -> Red -> Green -> Blue -> Gray
        let nextColor: NSColor?
        
        if currentColor == nil {
            nextColor = .systemRed // Start with "Original/Old"
        } else if currentColor == .systemRed {
            nextColor = .systemGreen // Then "New/Current"
        } else if currentColor == .systemGreen {
            nextColor = .systemBlue // Just another option
        } else {
            nextColor = nil // Reset
        }
        
        updateColorVisuals(color: nextColor)
        onColorChanged?(nextColor)
    }
    
    @objc private func handleCloseButtonClick() {
        onClose?()
    }

    // MARK: - Editing State

    /// 进入可编辑态：打开编辑 + 选中全部文本，便于直接重命名
    private func beginEditing() {
        guard !titleField.isEditable else { return }
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.drawsBackground = true
        titleField.backgroundColor = NSColor.textBackgroundColor
        titleField.selectText(nil) // 成为 first responder 并全选
    }

    /// 退出可编辑态，恢复只读展示
    private func endEditing() {
        titleField.isEditable = false
        titleField.isSelectable = false
        titleField.drawsBackground = false
    }
}

extension ColumnHeaderView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        endEditing() // 回到只读展示态
        onTitleChanged?(titleField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            window?.makeFirstResponder(nil) // Commit editing
            return true
        }
        return false
    }
}

/// 文件名标题输入框：只读态下单击触发回调（请求进入编辑态），编辑态保持原生文本交互
private final class EditableTitleField: NSTextField {
    var onClickWhenReadOnly: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard isEditable else {
            onClickWhenReadOnly?()
            return
        }
        super.mouseDown(with: event)
    }
}
