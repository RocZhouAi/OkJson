//  ComparisonSplitViewController.swift
//  OkJson
//
//  Split view controller for comparing two JSON documents
//

import AppKit

class ComparisonSplitViewController: NSSplitViewController {
    
    // MARK: - Properties
    
    private let leftVC = FormatterViewController()
    private let rightVC = FormatterViewController()
    
    // Sync Scroll State
    private var isSyncScrollEnabled: Bool = false
    private var isScrollLocked: Bool = false // Internal lock to prevent recursive scroll events
    
    // Focus State: which panel is currently focused (default: left)
    private var focusedPanel: FocusedPanel = .left {
        didSet {
            updateFocusState()
        }
    }
    
    private enum FocusedPanel {
        case left, right
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Main split is vertical (Left | Right)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        
        // Settings for Left Panel
        leftVC.initialOrientation = .horizontal
        leftVC.shouldSortKeys = true
        leftVC.isUnifiedMode = true
        leftVC.preferTreeInUnifiedMode = true
        
        // Settings for Right Panel
        rightVC.initialOrientation = .horizontal
        rightVC.shouldSortKeys = true
        rightVC.isUnifiedMode = true
        rightVC.preferTreeInUnifiedMode = true
        
        // Setup focus change callbacks
        leftVC.onFocusChanged = { [weak self] _ in
            self?.focusedPanel = .left
        }
        rightVC.onFocusChanged = { [weak self] _ in
            self?.focusedPanel = .right
        }
        
        let leftItem = NSSplitViewItem(viewController: leftVC)
        leftItem.minimumThickness = 300
        addSplitViewItem(leftItem)
        
        let rightItem = NSSplitViewItem(viewController: rightVC)
        rightItem.minimumThickness = 300
        addSplitViewItem(rightItem)
        
        // Set initial focus to left panel
        updateFocusState()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    // MARK: - Focus Management
    
    private func updateFocusState() {
        switch focusedPanel {
        case .left:
            leftVC.isFocused = true
            rightVC.isFocused = false
        case .right:
            leftVC.isFocused = false
            rightVC.isFocused = true
        }
    }
    
    // Handle Cmd+V at the ComparisonSplitViewController level
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+V
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            handlePaste()
            return
        }
        super.keyDown(with: event)
    }
    
    private func handlePaste() {
        // Paste to the focused panel
        switch focusedPanel {
        case .left:
            pasteToLeftPanel()
        case .right:
            pasteToRightPanel()
        }
    }
    
    private func pasteToLeftPanel() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }
        
        leftVC.viewModel.inputText = clipboardString
        leftVC.viewModel.formatJSON()
    }
    
    private func pasteToRightPanel() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }
        
        rightVC.viewModel.inputText = clipboardString
        rightVC.viewModel.formatJSON()
    }
    
    // MARK: - Actions
    
    @objc func performCompare() {
        leftVC.viewModel.formatJSON()
        rightVC.viewModel.formatJSON()
    }
    
    @objc func swapContent() {
        let leftText = leftVC.viewModel.inputText
        let rightText = rightVC.viewModel.inputText
        
        leftVC.viewModel.inputText = rightText
        rightVC.viewModel.inputText = leftText
        
        // Trigger re-format if needed
        if !rightText.isEmpty { leftVC.viewModel.formatJSON() }
        if !leftText.isEmpty { rightVC.viewModel.formatJSON() }
    }
    
    /// Enable or disable sync scrolling
    func toggleSyncScroll(enabled: Bool) {
        // Only update if changed
        guard isSyncScrollEnabled != enabled else { return }
        
        isSyncScrollEnabled = enabled
        
        if isSyncScrollEnabled {
            startSyncScrolling()
        } else {
            stopSyncScrolling()
        }
    }
    
    // MARK: - Sync Scroll Logic
    
    private func startSyncScrolling() {
        guard let leftScroll = leftVC.mainScrollView,
              let rightScroll = rightVC.mainScrollView else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: leftScroll)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScroll(_:)), name: NSScrollView.boundsDidChangeNotification, object: leftScroll.contentView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: rightScroll)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScroll(_:)), name: NSScrollView.boundsDidChangeNotification, object: rightScroll.contentView)
    }
    
    private func stopSyncScrolling() {
        NotificationCenter.default.removeObserver(self, name: NSScrollView.didLiveScrollNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSScrollView.boundsDidChangeNotification, object: nil)
    }
    
    @objc private func handleScroll(_ notification: Notification) {
        guard isSyncScrollEnabled, !isScrollLocked else { return }
        
        // Identify source
        guard let sourceObject = notification.object as? AnyObject else { return }
        
        let leftScroll = leftVC.mainScrollView
        let rightScroll = rightVC.mainScrollView
        
        isScrollLocked = true
        defer { isScrollLocked = false }
        
        if (sourceObject === leftScroll || sourceObject === leftScroll?.contentView), let target = rightScroll {
             sync(source: leftScroll!, to: target)
        } else if (sourceObject === rightScroll || sourceObject === rightScroll?.contentView), let target = leftScroll {
             sync(source: rightScroll!, to: target)
        }
    }
    
    private func sync(source: NSScrollView, to target: NSScrollView) {
        // Sync vertical scroll position
        let visibleRect = source.documentVisibleRect
        let targetVisibleRect = target.documentVisibleRect
        
        let newOrigin = NSPoint(x: targetVisibleRect.origin.x, y: visibleRect.origin.y)
        
        // Only scroll if changed
        if newOrigin.y != targetVisibleRect.origin.y {
             target.documentView?.scroll(newOrigin)
        }
    }
}
