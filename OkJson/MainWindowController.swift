//  MainWindowController.swift
//  OkJson
//
//  Main window controller - Pure AppKit

import AppKit

class MainWindowController: NSWindowController {
    
    private var appContainerViewController: AppContainerViewController!

    /// 当前文档标题（不含未保存圆点），用于刷新窗口标题
    private var documentTitle: String = "OkJson"

    convenience init() {
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OkJson"
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unifiedCompact
        window.minSize = NSSize(width: 800, height: 600)
        
        // 设置内容视图控制器
        let mainVC = MainViewController()
        let containerVC = AppContainerViewController(mainViewController: mainVC)
        window.contentViewController = containerVC
        
        // Window Restoration Configuration
        window.identifier = NSUserInterfaceItemIdentifier("OkJsonMainWindow")
        
        self.init(window: window)
        
        self.appContainerViewController = containerVC
        
        // Manually set delegate to receive resize events
        window.delegate = self
        
        // Manual Restoration
        restoreWindowFrame()
        
        // 配置 Toolbar
        configureToolbar()
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDocumentModified),
            name: .documentModified, object: nil
        )
    }
    
    @objc private func handleDocumentModified() {
        window?.isDocumentEdited = true
        refreshWindowTitle(edited: true)
    }

    /// 刷新窗口标题：未保存时在文件名前加一个明显的圆点
    private func refreshWindowTitle(edited: Bool) {
        // 窗口标题只显示文件名；已编辑状态由每列列头的圆点表示
        window?.title = documentTitle
    }
    
    // MARK: - Manual Persistence
    
    private func saveWindowFrame() {
        guard let window = window else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: "ManualWindowFrame_OkJson")
    }
    
    private func restoreWindowFrame() {
        guard let window = window else { return }
        
        if let frameString = UserDefaults.standard.string(forKey: "ManualWindowFrame_OkJson") {
            let frame = NSRectFromString(frameString)
            if frame.width > 0 && frame.height > 0 {
                window.setFrame(frame, display: true)
                return
            }
        }
        
        window.center()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        
        window?.toolbar = toolbar
        window?.toolbarStyle = .unifiedCompact
        // 标题栏不再显示文件名（每列列头已显示），仅保留 window.title 供 Window 菜单/Dock 识别
        window?.titleVisibility = .hidden
    }
    
    @objc private func onAddColumnClicked() {
        appContainerViewController.mainViewController.addColumn()
    }

    // MARK: - Open File

    func openFile(_ path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }

        let fileURL = URL(fileURLWithPath: path)
        let fileName = fileURL.lastPathComponent
        let mainVC = appContainerViewController.mainViewController

        // 焦点列编辑器为空则复用，否则新建空列（用编辑器实际文本判断，避免与 viewModel 脱节）
        let target: FormatterViewController
        if let focused = mainVC.focusedColumn,
           (focused.editorViewController?.textView.string ?? "")
               .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target = focused
        } else {
            mainVC.addColumn()
            guard let last = mainVC.columns.last else { return false }
            target = last
        }

        // 访问 view 强制触发 viewDidLoad（创建 editorViewController），再同步显示内容（杜绝"先空白再渲染"）
        _ = target.view
        target.editorViewController?.loadContent(content)
        target.viewModel.columnTitle = fileName
        target.viewModel.sourceFilePath = path
        target.viewModel.isModifiedSinceFileOpen = false

        window?.representedURL = fileURL
        documentTitle = fileName
        window?.isDocumentEdited = false
        refreshWindowTitle(edited: false)

        // 内容加载后重开"持续拉平"窗口，覆盖之后的迟到布局
        mainVC.equalizeColumns()

        return true
    }
    
    // MARK: - Save
    
    /// 检查是否有未保存的修改，弹出保存提示。返回 true 表示可以继续关闭。
    func handleUnsavedChanges() -> Bool {
        let mainVC = appContainerViewController.mainViewController
        let unsavedColumns = mainVC.columns.filter {
            $0.viewModel.sourceFilePath != nil && $0.viewModel.isModifiedSinceFileOpen
        }
        guard !unsavedColumns.isEmpty else { return true }
        
        let fileNames = unsavedColumns.compactMap {
            URL(fileURLWithPath: $0.viewModel.sourceFilePath!).lastPathComponent
        }
        
        let alert = NSAlert()
        alert.messageText = "要保存对文件的修改吗？"
        if fileNames.count == 1 {
            alert.informativeText = "文件「\(fileNames[0])」已修改。如果不保存，你的更改将会丢失。"
        } else {
            alert.informativeText = "以下文件已修改：\(fileNames.joined(separator: "、"))。如果不保存，你的更改将会丢失。"
        }
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            for column in unsavedColumns {
                do {
                    try column.viewModel.saveToSourceFile()
                } catch {
                    let errAlert = NSAlert()
                    errAlert.messageText = "保存失败"
                    errAlert.informativeText = error.localizedDescription
                    errAlert.alertStyle = .critical
                    errAlert.runModal()
                    return false
                }
            }
            return true
        case .alertSecondButtonReturn:
            // 用户选择不保存，标记为已处理，避免 applicationShouldTerminate 再次弹窗
            for column in unsavedColumns {
                column.viewModel.isModifiedSinceFileOpen = false
            }
            return true
        default:
            return false
        }
    }
    
    /// 保存焦点列对应的源文件
    func saveFocusedColumn() {
        let mainVC = appContainerViewController.mainViewController
        guard let focused = mainVC.focusedColumn,
              focused.viewModel.sourceFilePath != nil else { return }
        
        do {
            try focused.viewModel.saveToSourceFile()
            updateDocumentEditedState()
            // 可能已重命名文件，刷新窗口标题与代理图标
            if let path = focused.viewModel.sourceFilePath {
                let fileURL = URL(fileURLWithPath: path)
                window?.representedURL = fileURL
                documentTitle = fileURL.lastPathComponent
                refreshWindowTitle(edited: window?.isDocumentEdited ?? false)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "保存失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    private func updateDocumentEditedState() {
        let mainVC = appContainerViewController.mainViewController
        let hasUnsaved = mainVC.columns.contains {
            $0.viewModel.sourceFilePath != nil && $0.viewModel.isModifiedSinceFileOpen
        }
        window?.isDocumentEdited = hasUnsaved
        refreshWindowTitle(edited: hasUnsaved)
    }
}


extension MainWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }
    
    func windowDidMove(_ notification: Notification) {
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return handleUnsavedChanges()
    }
    
    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
    }
}

extension NSToolbarItem.Identifier {
    static let addColumn = NSToolbarItem.Identifier("com.okjson.addColumn")
}

extension MainWindowController: NSToolbarDelegate {
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .addColumn]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.addColumn, .flexibleSpace]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        if itemIdentifier == .addColumn {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "添加对比列")
            let button = NSButton(image: image!, target: self, action: #selector(onAddColumnClicked))
            button.bezelStyle = .texturedRounded
            button.toolTip = "添加对比列"
            
            item.view = button
            item.label = "添加列"
            item.paletteLabel = "添加列"
            return item
        }
        
        return nil
    }
}
