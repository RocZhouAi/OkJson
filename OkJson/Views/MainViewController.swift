//  MainViewController.swift
//  OkJson
//
//  Tab view controller - Pure AppKit

import AppKit

class MainViewController: NSTabViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置 Tab 样式
        tabStyle = .unspecified
        
        // 添加 Formatter Tab
        let formatterVC = FormatterViewController()
        // 启用单栏模式 + 智能 Tree 切换
        formatterVC.isUnifiedMode = true
        formatterVC.preferTreeInUnifiedMode = true
        let formatterItem = NSTabViewItem(viewController: formatterVC)
        formatterItem.label = "Formatter"
        formatterItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        addTabViewItem(formatterItem)
        
        // 添加 Compare Tab
        let compareVC = ComparisonSplitViewController()
        let compareItem = NSTabViewItem(viewController: compareVC)
        compareItem.label = "Compare"
        compareItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        addTabViewItem(compareItem)
        
        // 添加 Settings Tab
        let settingsVC = PreferencesViewController()
        let settingsItem = NSTabViewItem(viewController: settingsVC)
        settingsItem.label = "Settings"
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        addTabViewItem(settingsItem)
    }
}

// MARK: - Placeholder View Controller

class PlaceholderViewController: NSViewController {
    
    private let titleText: String
    private let subtitleText: String
    private let iconName: String
    
    init(title: String, subtitle: String, icon: String) {
        self.titleText = title
        self.subtitleText = subtitle
        self.iconName = icon
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        
        // 容器 Stack View
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 图标
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        stackView.addArrangedSubview(iconView)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        stackView.addArrangedSubview(titleLabel)
        
        // 副标题
        let subtitleLabel = NSTextField(labelWithString: subtitleText)
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(subtitleLabel)
    }
}
