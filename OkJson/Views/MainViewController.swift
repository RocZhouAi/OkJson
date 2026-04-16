//  MainViewController.swift
//  OkJson
//
//  动态多列工作区控制器 - 管理 JSON 列的增删和同步滚动

import AppKit

class MainViewController: NSSplitViewController {

    // MARK: - Properties

    /// 当前焦点列索引
    private(set) var focusedColumnIndex: Int = 0

    /// 同步滚动状态
    private var isSyncScrollEnabled: Bool = false
    private var isScrollLocked: Bool = false

    /// 列数变化回调（通知 AppContainer 更新底栏）
    var onColumnCountChanged: ((Int) -> Void)?

    /// 窗口 resize 时的 debounce 计时器
    private var resizeDebounceTimer: Timer?

    /// 标记是否正在拖拽 divider（避免拖拽时自动均分）
    private var isDraggingDivider: Bool = false

    /// 标记是否需要均分（用于窗口 resize）
    private var needsEqualization: Bool = false
    
    /// 所有列的 FormatterViewController
    var columns: [FormatterViewController] {
        return splitViewItems.compactMap { $0.viewController as? FormatterViewController }
    }
    
    var columnCount: Int {
        return columns.count
    }
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // 配置 SplitView
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        // 添加初始列
        let initialColumn = createColumn()
        let item = NSSplitViewItem(viewController: initialColumn)
        item.minimumThickness = 50  // 极小值
        addSplitViewItem(item)

        // 设置 splitView delegate
        splitView.delegate = self

        // 设置焦点
        updateFocusState()

        // 监听窗口 resize 事件
        setupWindowResizeObserver()

        // 在布局完成后均分列宽
        DispatchQueue.main.async { [weak self] in
            self?.equalizeColumnWidths()
        }
    }
    
    // MARK: - 列管理

    /// 添加新列
    @objc func addColumn(content: String? = nil, title: String? = nil) {
        // 保存当前窗口宽度
        guard let window = view.window else { return }
        let originalWidth = window.frame.width
        let originalFrame = window.frame

        // 创建新列 - 不设置 minimumThickness，让列宽完全由容器决定
        let column = createColumn()
        let item = NSSplitViewItem(viewController: column)
        item.minimumThickness = 50  // 极小值，不阻止均分
        addSplitViewItem(item)

        // 如果提供了内容，加载到新列
        if let content = content {
            column.viewModel.inputText = content
            column.viewModel.formatJSON()
        }
        // 如果提供了标题，设置列标题
        if let title = title {
            column.viewModel.columnTitle = title
        }

        // 新列获得焦点
        focusedColumnIndex = columns.count - 1
        updateFocusState()
        onColumnCountChanged?(columnCount)

        // 立即强制恢复窗口宽度（防止窗口扩展）
        window.setFrame(
            NSRect(x: originalFrame.origin.x, y: originalFrame.origin.y, width: originalWidth, height: originalFrame.height),
            display: false
        )

        // 均分列宽
        DispatchQueue.main.async { [weak self] in
            self?.equalizeColumnWidths()
        }
    }
    
    /// 移除指定列
    func removeColumn(at index: Int) {
        guard columnCount > 1, index >= 0, index < splitViewItems.count else { return }

        // 停止同步滚动（会重新注册）
        if isSyncScrollEnabled {
            stopSyncScrolling()
        }

        let item = splitViewItems[index]
        removeSplitViewItem(item)

        // 调整焦点
        if focusedColumnIndex >= columnCount {
            focusedColumnIndex = columnCount - 1
        }
        updateFocusState()
        onColumnCountChanged?(columnCount)

        // 均分列宽
        DispatchQueue.main.async { [weak self] in
            self?.equalizeColumnWidths()
        }

        // 重新启动同步滚动
        if isSyncScrollEnabled && columnCount > 1 {
            startSyncScrolling()
        }
    }

    /// 均分所有列的宽度
    private func equalizeColumnWidths() {
        guard columnCount > 1 else { return }

        guard let window = view.window else { return }
        let contentRect = window.contentLayoutRect
        let totalWidth = contentRect.width
        guard totalWidth > 0 else { return }

        let count = CGFloat(columnCount)
        let dividerCount = CGFloat(columnCount - 1)
        let dividerWidth = splitView.dividerThickness
        let columnWidth = (totalWidth - dividerWidth * dividerCount) / count

        // 设置分隔线位置
        for i in 0..<splitViewItems.count - 1 {
            let position = columnWidth * CGFloat(i + 1) + dividerWidth * CGFloat(i)
            splitView.setPosition(position, ofDividerAt: i)
        }
    }

    /// 创建新列
    private func createColumn() -> FormatterViewController {
        let vc = FormatterViewController()
        vc.isUnifiedMode = true
        vc.preferTreeInUnifiedMode = true
        vc.shouldSortKeys = true

        let columnIndex = columns.count
        vc.onFocusChanged = { [weak self] _ in
            guard let self = self else { return }
            // 找到当前列的索引
            if let idx = self.columns.firstIndex(where: { $0 === vc }) {
                self.focusedColumnIndex = idx
                self.updateFocusState()
            }
        }

        // 设置关闭回调
        vc.onCloseRequest = { [weak self] in
            guard let self = self else { return }
            if let idx = self.columns.firstIndex(where: { $0 === vc }) {
                self.removeColumn(at: idx)
            }
        }

        vc.viewModel.columnTitle = "Column \(columnIndex + 1)"

        return vc
    }
    
    // MARK: - 焦点管理
    
    private func updateFocusState() {
        for (index, column) in columns.enumerated() {
            column.isFocused = (index == focusedColumnIndex)
            // 始终显示列头
            column.showHeader = true
            // 只有多列时才显示关闭按钮
            column.showCloseButton = columnCount > 1
        }
    }
    
    /// 获取焦点列
    var focusedColumn: FormatterViewController? {
        guard focusedColumnIndex >= 0, focusedColumnIndex < columns.count else { return nil }
        return columns[focusedColumnIndex]
    }
    
    // MARK: - 同步滚动
    
    func toggleSyncScroll(enabled: Bool) {
        guard isSyncScrollEnabled != enabled else { return }
        isSyncScrollEnabled = enabled
        
        if isSyncScrollEnabled && columnCount > 1 {
            startSyncScrolling()
        } else {
            stopSyncScrolling()
        }
    }
    
    private func startSyncScrolling() {
        for column in columns {
            guard let scrollView = column.mainScrollView else { continue }
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScroll(_:)),
                name: NSScrollView.didLiveScrollNotification,
                object: scrollView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScroll(_:)),
                name: NSScrollView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }
    
    private func stopSyncScrolling() {
        NotificationCenter.default.removeObserver(self, name: NSScrollView.didLiveScrollNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSScrollView.boundsDidChangeNotification, object: nil)
    }
    
    @objc private func handleScroll(_ notification: Notification) {
        guard isSyncScrollEnabled, !isScrollLocked else { return }
        guard let sourceObject = notification.object as? AnyObject else { return }
        
        // 找到源列
        var sourceScrollView: NSScrollView?
        for column in columns {
            if let sv = column.mainScrollView,
               sourceObject === sv || sourceObject === sv.contentView {
                sourceScrollView = sv
                break
            }
        }
        
        guard let source = sourceScrollView else { return }
        
        isScrollLocked = true
        defer { isScrollLocked = false }
        
        // 同步到所有其他列
        let visibleRect = source.documentVisibleRect
        for column in columns {
            guard let target = column.mainScrollView, target !== source else { continue }
            let targetVisibleRect = target.documentVisibleRect
            let newOrigin = NSPoint(x: targetVisibleRect.origin.x, y: visibleRect.origin.y)
            if newOrigin.y != targetVisibleRect.origin.y {
                target.documentView?.scroll(newOrigin)
            }
        }
    }
    


    // MARK: - Paste 处理（多列模式下 Paste 到焦点列）

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            focusedColumn?.viewModel.pasteFromClipboard()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - 窗口 Resize 监听

    private func setupWindowResizeObserver() {
        // 监听窗口 resize 通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowResize(_:)),
            name: NSWindow.didResizeNotification,
            object: nil
        )

        // 监听自动适应列宽快捷键
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoFitColumnWidth(_:)),
            name: .autoFitColumnWidth,
            object: nil
        )

        // 监听添加列快捷键
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddColumn(_:)),
            name: .addColumn,
            object: nil
        )
    }

    @objc private func handleAutoFitColumnWidth(_ notification: Notification) {
        autoFitFocusedColumn()
    }

    @objc private func handleAddColumn(_ notification: Notification) {
        addColumn()
    }

    @objc private func handleWindowResize(_ notification: Notification) {
        guard columnCount > 1, !isDraggingDivider else { return }

        // Debounce：避免频繁计算
        resizeDebounceTimer?.invalidate()
        resizeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.equalizeColumnWidths()
        }
    }

    // MARK: - 智能列宽调整

    /// 自动调整焦点列的宽度以适应内容
    func autoFitFocusedColumn() {
        guard let focusedColumn = focusedColumn,
              let contentWidth = focusedColumn.unifiedViewController?.estimatedContentWidth() else { return }

        let minWidth: CGFloat = 300
        let newWidth = max(contentWidth, minWidth)

        // 如果只有一列，不需要调整
        guard columnCount > 1 else { return }

        // 找到焦点列的索引
        guard let index = columns.firstIndex(where: { $0 === focusedColumn }) else { return }

        // 调整分隔线位置
        if index < splitViewItems.count - 1 {
            let currentWidth = splitView.subviews[index].frame.width
            let deltaWidth = newWidth - currentWidth

            // 计算当前分隔线位置
            var dividerPos: CGFloat = 0
            for i in 0...index {
                dividerPos += splitView.subviews[i].frame.width
                if i < index {
                    dividerPos += splitView.dividerThickness
                }
            }

            let newPosition = dividerPos + deltaWidth

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                splitView.animator().setPosition(newPosition, ofDividerAt: index)
            }
        }
    }

    deinit {
        stopSyncScrolling()
        NotificationCenter.default.removeObserver(self)
        resizeDebounceTimer?.invalidate()
    }
}
