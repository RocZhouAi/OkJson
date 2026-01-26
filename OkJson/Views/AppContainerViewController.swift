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
    
    // 左侧：设置展示区域
    private lazy var settingsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 中间：功能按钮区域（对比模式专用）
    private lazy var syncScrollButton: NSButton = {
        let button = NSButton(title: "Sync", target: self, action: #selector(onSyncScrollClicked))
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.image = NSImage(systemSymbolName: "lock", accessibilityDescription: "Sync Scroll")
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var swapButton: NSButton = {
        let button = NSButton(title: "Swap", target: self, action: #selector(onSwapClicked))
        button.bezelStyle = .recessed
        button.image = NSImage(systemSymbolName: "arrow.left.and.right", accessibilityDescription: "Swap")
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var compareButton: NSButton = {
        let button = NSButton(title: "Compare", target: self, action: #selector(onCompareClicked))
        button.bezelStyle = .recessed
        button.image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Compare")
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 右侧：Tips 轮播区域
    private lazy var tipsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let tips = [
        "⌘V 粘贴 JSON",
        "⌘F 格式化",
        "⌘⇧C 复制结果"
    ]
    private var currentTipIndex = 0
    private var tipsTimer: Timer?
    
    private var footerHeightConstraint: NSLayoutConstraint!
    private var centerStackView: NSStackView!
    
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
        setupSettingsObservation()
        updateSettingsLabel()
        startTipsTimer()
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
        
        // 左侧：设置展示
        footerView.addSubview(settingsLabel)
        
        // 中间：功能按钮 Stack
        centerStackView = NSStackView(views: [syncScrollButton, swapButton, compareButton])
        centerStackView.orientation = .horizontal
        centerStackView.spacing = 8
        centerStackView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(centerStackView)
        
        // 右侧：Tips 轮播
        footerView.addSubview(tipsLabel)
        
        NSLayoutConstraint.activate([
            // 左侧
            settingsLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 12),
            settingsLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            settingsLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            
            // 中间
            centerStackView.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            centerStackView.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            
            // 右侧
            tipsLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -12),
            tipsLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            tipsLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 150),
        ])
    }
    
    private var isObserving = false
    
    private func setupObservation() {
        if !isObserving {
            mainViewController.addObserver(self, forKeyPath: "selectedTabViewItemIndex", options: [.new, .initial], context: nil)
            isObserving = true
        }
    }
    
    private func setupSettingsObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: Constants.Notifications.formatSettingsChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: Constants.Notifications.displaySettingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettingsChanged() {
        updateSettingsLabel()
    }
    
    private func updateSettingsLabel() {
        let defaults = UserDefaults.standard
        let indentation = defaults.integer(forKey: Constants.UserDefaultsKeys.indentation)
        let spaces = indentation > 0 ? indentation : 2
        let lineNumbers = defaults.bool(forKey: Constants.UserDefaultsKeys.lineNumbers)
        
        settingsLabel.stringValue = "Spaces: \(spaces) | Lines: \(lineNumbers ? "ON" : "OFF")"
    }
    
    private func startTipsTimer() {
        updateTipsLabel()
        tipsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.rotateTip()
        }
    }
    
    private func updateTipsLabel() {
        tipsLabel.stringValue = tips[currentTipIndex]
    }
    
    private func rotateTip() {
        currentTipIndex = (currentTipIndex + 1) % tips.count
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            tipsLabel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.updateTipsLabel()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self?.tipsLabel.animator().alphaValue = 1
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "selectedTabViewItemIndex" {
            updateFooterVisibility()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    deinit {
        tipsTimer?.invalidate()
        if isObserving {
            mainViewController.removeObserver(self, forKeyPath: "selectedTabViewItemIndex")
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Logic
    
    private func updateFooterVisibility() {
        let isCompareMode = mainViewController.selectedTabViewItemIndex == 1
        centerStackView?.isHidden = !isCompareMode
    }
    
    // MARK: - Actions
    
    private var comparisonController: ComparisonSplitViewController? {
        guard mainViewController.tabViewItems.count > 1,
              let vc = mainViewController.tabViewItems[1].viewController as? ComparisonSplitViewController else {
            return nil
        }
        return vc
    }
    
    @objc private func onSyncScrollClicked() {
        comparisonController?.toggleSyncScroll(enabled: syncScrollButton.state == .on)
    }
    
    @objc private func onSwapClicked() {
        comparisonController?.swapContent()
    }
    
    @objc private func onCompareClicked() {
        comparisonController?.performCompare()
    }
}

