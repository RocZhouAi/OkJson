//  AppContainerViewController.swift
//  OkJson
//
//  Root container view controller that manages the main content and the footer bar.
//

import AppKit

class AppContainerViewController: NSViewController {
    
    // MARK: - Properties
    
    let mainViewController: MainViewController
    
    // Footer Container
    private let footerView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        return view
    }()
    
    // 左侧：内联设置控件
    private lazy var themeButton: NSButton = {
        let button = NSButton(image: NSImage(systemSymbolName: Theme.current.iconName, accessibilityDescription: "切换主题")!, target: self, action: #selector(onThemeClicked))
        button.bezelStyle = .recessed
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.toolTip = "切换亮色/暗色主题"
        return button
    }()
    
    private lazy var indentButton: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["2 sp", "4 sp"])
        popup.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        popup.controlSize = .small
        popup.bezelStyle = .recessed
        popup.isBordered = false
        popup.target = self
        popup.action = #selector(onIndentChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.toolTip = "缩进空格数"
        
        let current = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.indentation)
        popup.selectItem(at: current == 4 ? 1 : 0)
        return popup
    }()
    
    private lazy var sortButton: NSButton = {
        let button = NSButton(image: NSImage(systemSymbolName: "textformat.abc", accessibilityDescription: "按字母排序 Key")!, target: self, action: #selector(onSortClicked))
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.toolTip = "按字母排序 JSON Key"
        button.state = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.sortKeys) ? .on : .off
        return button
    }()
    
    private lazy var lineNumberButton: NSButton = {
        let button = NSButton(image: NSImage(systemSymbolName: "list.number", accessibilityDescription: "显示行号")!, target: self, action: #selector(onLineNumberClicked))
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.toolTip = "显示/隐藏行号"
        
        // 读取初始值
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Constants.UserDefaultsKeys.lineNumbers) != nil {
            button.state = defaults.bool(forKey: Constants.UserDefaultsKeys.lineNumbers) ? .on : .off
        } else {
            button.state = .on // 默认开启
        }
        return button
    }()
    
    // 中央悬浮按钮（FAB，多列模式专用）：核心功能「同步滚动」
    private lazy var syncScrollButton: SyncScrollFloatingButton = {
        let button = SyncScrollFloatingButton()
        button.onClick = { [weak self] in self?.onSyncScrollClicked() }
        return button
    }()
    

    
    // 右侧：快捷键提示区域（固定显示，不轮播）
    private lazy var shortcutsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "⌘V 粘贴 · ⌘F 搜索 · ⌘R 格式化 · ⌘D 添加列 · ⌘⇧W 适应宽度")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var footerHeightConstraint: NSLayoutConstraint!
    private var leftStackView: NSStackView!
    
    // MARK: - Initialization
    
    init(mainViewController: MainViewController) {
        self.mainViewController = mainViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservation()

        // 监听列数变化，更新底栏按钮可见性
        mainViewController.onColumnCountChanged = { [weak self] count in
            self?.updateFooterVisibility()
        }

        // 初始状态
        updateFooterVisibility()

        // 应用保存的主题
        Theme.current.apply()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // 1. Add Main View Controller
        addChild(mainViewController)
        mainViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainViewController.view)
        
        // 2. Add Footer
        view.addSubview(footerView)
        
        footerHeightConstraint = footerView.heightAnchor.constraint(equalToConstant: 28)
        
        NSLayoutConstraint.activate([
            mainViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            mainViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerHeightConstraint,
            
            mainViewController.view.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
        
        setupFooterContent()
        
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 800).isActive = true
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: 600).isActive = true
    }
    
    private func setupFooterContent() {
        // 分隔线
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: footerView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])
        
        // 左侧：内联设置控件
        leftStackView = NSStackView(views: [themeButton, indentButton, sortButton, lineNumberButton])
        leftStackView.orientation = .horizontal
        leftStackView.spacing = 12
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(leftStackView)
        
        // 右侧：快捷键提示
        footerView.addSubview(shortcutsLabel)

        // 中央悬浮按钮（FAB）：加到根 view，凸出于底栏上沿、浮在最上层
        view.addSubview(syncScrollButton)

        NSLayoutConstraint.activate([
            // 左侧
            leftStackView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 8),
            leftStackView.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            // 右侧
            shortcutsLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -12),
            shortcutsLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            // 中央 FAB：水平居中，垂直骑在底栏上沿（凸出约一半）
            syncScrollButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            syncScrollButton.centerYAnchor.constraint(equalTo: footerView.topAnchor),
        ])
    }
    
    private func setupObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Constants.Notifications.themeChanged,
            object: nil
        )
    }
    
    @objc private func handleThemeChanged() {
        let appearance = NSApp.effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            footerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Logic
    
    private func updateFooterVisibility() {
        let isMultiColumn = mainViewController.columnCount > 1
        syncScrollButton.isHidden = !isMultiColumn
    }
    
    // MARK: - Actions
    
    @objc private func onThemeClicked() {
        let next = Theme.current.next
        Theme.current = next
        themeButton.image = NSImage(systemSymbolName: next.iconName, accessibilityDescription: "切换主题")
    }
    
    @objc private func onIndentChanged(_ sender: NSPopUpButton) {
        let value = sender.indexOfSelectedItem == 1 ? 4 : 2
        UserDefaults.standard.set(value, forKey: Constants.UserDefaultsKeys.indentation)
        NotificationCenter.default.post(name: Constants.Notifications.formatSettingsChanged, object: nil)
    }
    
    @objc private func onSortClicked() {
        let isOn = sortButton.state == .on
        UserDefaults.standard.set(isOn, forKey: Constants.UserDefaultsKeys.sortKeys)
        NotificationCenter.default.post(name: Constants.Notifications.formatSettingsChanged, object: nil)
    }
    
    @objc private func onLineNumberClicked() {
        let isOn = lineNumberButton.state == .on
        UserDefaults.standard.set(isOn, forKey: Constants.UserDefaultsKeys.lineNumbers)
        NotificationCenter.default.post(name: Constants.Notifications.displaySettingsChanged, object: nil)
    }
    
    @objc private func onSyncScrollClicked() {
        syncScrollButton.isSyncOn.toggle()
        mainViewController.toggleSyncScroll(enabled: syncScrollButton.isSyncOn)
    }
    

}
