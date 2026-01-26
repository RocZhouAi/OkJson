//  PreferencesViewController.swift
//  OkJson
//
//  Settings view controller - Pure AppKit

import AppKit

class PreferencesViewController: NSViewController {
    
    // MARK: - UserDefaults Keys
    
    private let indentationKey = "indentation"
    private let sortKeysKey = "sortKeys"
    private let syncScrollKey = "syncScroll"
    private let colorSchemeKey = "colorScheme"
    private let maxDepthKey = "maxDepth"
    private let lineNumbersKey = "lineNumbers"
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let contentView = createSettingsView()
        scrollView.documentView = contentView
        
        // 设置 contentView 宽度跟随 scrollView
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -20)
        ])
    }
    
    private func createSettingsView() -> NSView {
        let containerView = FlippedStackView()
        containerView.orientation = .vertical
        containerView.alignment = .leading
        containerView.spacing = 20
        containerView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Formatting Section
        containerView.addArrangedSubview(createSectionHeader("Formatting"))
        containerView.addArrangedSubview(createIndentationPicker())
        containerView.addArrangedSubview(createCheckbox(
            title: "Sort object keys alphabetically",
            key: sortKeysKey
        ))
        
    
        // Display Section
        containerView.addArrangedSubview(createSectionHeader("Display"))
        containerView.addArrangedSubview(createColorSchemePicker())
        containerView.addArrangedSubview(createCheckbox(
            title: "Show line numbers",
            key: lineNumbersKey
        ))

        
        return containerView
    }
    
    private func createSectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        return label
    }
    
    private func createCheckbox(title: String, key: String) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
        checkbox.identifier = NSUserInterfaceItemIdentifier(key)
        checkbox.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
        return checkbox
    }
    
    private func createIndentationPicker() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 10
        
        let label = NSTextField(labelWithString: "Indentation:")
        container.addArrangedSubview(label)
        
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["2 spaces", "4 spaces"])
        popup.identifier = NSUserInterfaceItemIdentifier(indentationKey)
        popup.target = self
        popup.action = #selector(indentationChanged(_:))
        
        let currentValue = UserDefaults.standard.integer(forKey: indentationKey)
        popup.selectItem(at: currentValue == 4 ? 1 : 0)
        
        container.addArrangedSubview(popup)
        
        return container
    }
    
    private func createColorSchemePicker() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 10
        
        let label = NSTextField(labelWithString: "Color scheme:")
        container.addArrangedSubview(label)
        
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["Default", "Dark", "High Contrast"])
        popup.identifier = NSUserInterfaceItemIdentifier(colorSchemeKey)
        popup.target = self
        popup.action = #selector(colorSchemeChanged(_:))
        
        let currentValue = UserDefaults.standard.string(forKey: colorSchemeKey) ?? "default"
        switch currentValue {
        case "dark": popup.selectItem(at: 1)
        case "highContrast": popup.selectItem(at: 2)
        default: popup.selectItem(at: 0)
        }
        
        container.addArrangedSubview(popup)
        
        return container
    }
    
    private func createDepthPicker() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 10
        
        let label = NSTextField(labelWithString: "Default collapse depth:")
        container.addArrangedSubview(label)
        
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["1 level", "2 levels", "3 levels", "4 levels", "5 levels"])
        popup.identifier = NSUserInterfaceItemIdentifier(maxDepthKey)
        popup.target = self
        popup.action = #selector(depthChanged(_:))
        
        let currentValue = UserDefaults.standard.integer(forKey: maxDepthKey)
        let index = max(0, min(4, currentValue - 1))
        popup.selectItem(at: index)
        
        container.addArrangedSubview(popup)
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func checkboxChanged(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        UserDefaults.standard.set(sender.state == .on, forKey: key)
        
        // 发送自定义通知
        if key == sortKeysKey {
            NotificationCenter.default.post(name: Constants.Notifications.formatSettingsChanged, object: nil)
        } else if key == lineNumbersKey {
            NotificationCenter.default.post(name: Constants.Notifications.displaySettingsChanged, object: nil)
        }
    }
    
    @objc private func indentationChanged(_ sender: NSPopUpButton) {
        let value = sender.indexOfSelectedItem == 1 ? 4 : 2
        UserDefaults.standard.set(value, forKey: indentationKey)
        NotificationCenter.default.post(name: Constants.Notifications.formatSettingsChanged, object: nil)
    }
    
    @objc private func colorSchemeChanged(_ sender: NSPopUpButton) {
        let values = ["default", "dark", "highContrast"]
        let value = values[sender.indexOfSelectedItem]
        UserDefaults.standard.set(value, forKey: colorSchemeKey)
        NotificationCenter.default.post(name: Constants.Notifications.displaySettingsChanged, object: nil)
    }
    
    @objc private func depthChanged(_ sender: NSPopUpButton) {
        let value = sender.indexOfSelectedItem + 1
        UserDefaults.standard.set(value, forKey: maxDepthKey)
        NotificationCenter.default.post(name: Constants.Notifications.displaySettingsChanged, object: nil)
    }
    
}

// MARK: - Helper Views

class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        return true
    }
}
