//  FormatterViewController.swift
//  OkJson
//
//  JSON formatter view controller - Pure AppKit

import AppKit

class FormatterViewController: NSSplitViewController {
    
    // MARK: - Properties

    /// 每列的文本编辑器控制器（列的显示主体）
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

    var mainScrollView: NSScrollView? {
        return editorViewController?.scrollView
    }
    
    /// Focus state for Compare mode (border highlight)
    var isFocused: Bool = false {
        didSet {
            updateFocusBorder()
        }
    }
    
    /// 是否显示列头（列头已由编辑器常驻显示，此标记保留以兼容 MainViewController）
    var showHeader: Bool = false

    /// 是否显示关闭按钮（多列显示，单列隐藏）
    var showCloseButton: Bool = true {
        didSet {
            editorViewController?.setCloseButtonVisible(showCloseButton)
        }
    }

    /// 关闭列的回调
    var onCloseRequest: (() -> Void)?

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
        
        // 创建文本编辑器作为列的显示主体
        editorViewController = JSONEditorViewController(viewModel: viewModel)
        editorViewController.onFocusRequest = { [weak self] in
            self?.onFocusChanged?(true)
        }
        editorViewController.onCloseRequest = { [weak self] in
            self?.onCloseRequest?()
        }
        editorViewController.setCloseButtonVisible(showCloseButton)

        let item = NSSplitViewItem(viewController: editorViewController)
        item.minimumThickness = 150
        item.holdingPriority = .defaultLow
        addSplitViewItem(item)

        // 监听通知
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFormatJSON),
            name: .formatJSON, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleClearInput),
            name: .clearInput, object: nil
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
        editorViewController.formatCurrent()
    }

    @objc private func handleClearInput() {
        guard isFocused else { return }
        editorViewController.clearContent()
        viewModel.clear()
    }

    @objc private func handleSortKeys() {
        guard isFocused else { return }
        // 切换 Key 排序（与底栏开关共用 UserDefaults），再广播让各列按新设置重排
        let cur = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.sortKeys)
        UserDefaults.standard.set(!cur, forKey: Constants.UserDefaultsKeys.sortKeys)
        viewModel.markAsModified()
        NotificationCenter.default.post(name: Constants.Notifications.formatSettingsChanged, object: nil)
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
