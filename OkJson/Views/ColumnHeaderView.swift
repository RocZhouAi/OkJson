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
    
    var onTitleChanged: ((String) -> Void)?
    var onColorChanged: ((NSColor?) -> Void)? // nil represents default/no color
    var onClose: (() -> Void)?
    
    private var currentColor: NSColor?
    
    // UI Elements
    private let titleField = NSTextField()
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
        
        // 4. Title Field
        titleField.stringValue = "Column"
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = NSColor.labelColor
        titleField.drawsBackground = false
        titleField.isBordered = false
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.focusRingType = .none
        titleField.delegate = self
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)
        
        // 5. Separator
        separatorLine.boxType = .separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)
        
        // Layout
        NSLayoutConstraint.activate([
            // StackView: Right aligned
            rightStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rightStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Title: Fills space between Left and StackView
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.trailingAnchor.constraint(equalTo: rightStackView.leadingAnchor, constant: -8),
            
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
}

extension ColumnHeaderView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
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
