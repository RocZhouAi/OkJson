//  AppDelegate.swift
//  OkJson
//
//  Application delegate - Pure AppKit

import AppKit
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindowController: MainWindowController?
    /// 启动前收到的待打开文件（窗口就绪后统一打开）
    private var pendingFiles: [String] = []

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建主窗口
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)

        // 设置菜单
        setupMenuBar()

        // 启动前若已收到待打开文件，现在统一打开
        for f in pendingFiles { _ = mainWindowController?.openFile(f) }
        pendingFiles.removeAll()

        // 启动后静默检查更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UpdateService.shared.checkForUpdates(silent: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let wc = mainWindowController, !wc.handleUnsavedChanges() {
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Open File

    /// 现代多文件打开（macOS 推荐路径：双击文件、拖到 Dock 图标）
    func application(_ application: NSApplication, open urls: [URL]) {
        let paths = urls.map { $0.path }
        if let wc = mainWindowController {
            for p in paths { _ = wc.openFile(p) }
        } else {
            pendingFiles.append(contentsOf: paths)
        }
    }

    /// 旧版单文件打开（兜底）
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if let wc = mainWindowController {
            return wc.openFile(filename)
        } else {
            pendingFiles.append(filename)
            return true
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Menu Setup
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App 菜单
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About OkJson", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit OkJson", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // File 菜单
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Open...", action: #selector(openFile), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Save", action: #selector(saveFile), keyEquivalent: "s")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Clear Input", action: #selector(clearInput), keyEquivalent: "k")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "设为 .json 默认打开方式", action: #selector(setAsDefaultJSONApp), keyEquivalent: "")
        
        // Edit 菜单
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(findInJSON), keyEquivalent: "f")
        editMenu.addItem(NSMenuItem(title: "Find Next", action: #selector(findNextInJSON), keyEquivalent: "g"))
        editMenu.addItem(NSMenuItem(title: "Find Previous", action: #selector(findPreviousInJSON), keyEquivalent: "G"))
        
        // JSON 菜单
        let jsonMenuItem = NSMenuItem()
        mainMenu.addItem(jsonMenuItem)
        let jsonMenu = NSMenu(title: "JSON")
        jsonMenuItem.submenu = jsonMenu
        
        let formatItem = NSMenuItem(title: "Format JSON", action: #selector(formatJSON), keyEquivalent: "r")
        formatItem.keyEquivalentModifierMask = [.command]
        jsonMenu.addItem(formatItem)
        
        jsonMenu.addItem(NSMenuItem.separator())
        
        let sortKeysItem = NSMenuItem(title: "Sort Keys", action: #selector(sortKeys), keyEquivalent: "s")
        sortKeysItem.keyEquivalentModifierMask = [.command, .shift]
        jsonMenu.addItem(sortKeysItem)

        jsonMenu.addItem(NSMenuItem.separator())

        let autoFitWidthItem = NSMenuItem(title: "Auto-Fit Column Width", action: #selector(autoFitColumnWidth), keyEquivalent: "w")
        autoFitWidthItem.keyEquivalentModifierMask = [.command, .shift]
        jsonMenu.addItem(autoFitWidthItem)

        jsonMenu.addItem(NSMenuItem.separator())

        let addColumnItem = NSMenuItem(title: "Add Column", action: #selector(addColumn), keyEquivalent: "d")
        addColumnItem.keyEquivalentModifierMask = [.command]
        jsonMenu.addItem(addColumnItem)
        
        // Window 菜单
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
    
    // MARK: - Menu Actions

    @objc func openFile() {
        let panel = NSOpenPanel()
        // 使用 allowedContentTypes 支持 .json，然后通过 UTType 扩展支持 .xcs
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "xcs")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.beginSheetModal(for: mainWindowController?.window ?? NSApp.windows.first!) { response in
            if response == .OK, let url = panel.url {
                _ = self.mainWindowController?.openFile(url.path)
            }
        }
    }

    @objc func saveFile() {
        mainWindowController?.saveFocusedColumn()
    }

    /// 把 OkJson 设为 .json 的默认打开应用（macOS 不允许自动抢默认，由用户主动触发）
    @objc func setAsDefaultJSONApp() {
        guard let jsonType = UTType(filenameExtension: "json") else { return }
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpen: jsonType) { error in
            DispatchQueue.main.async {
                let alert = NSAlert()
                if let error = error {
                    alert.messageText = "设置失败"
                    alert.informativeText = "无法设为默认：\(error.localizedDescription)\n建议先把 OkJson 拖到「应用程序」文件夹，再试一次。"
                    alert.alertStyle = .warning
                } else {
                    alert.messageText = "已设为默认"
                    alert.informativeText = "现在双击 .json 文件会用 OkJson 打开。"
                }
                alert.runModal()
            }
        }
    }

    @objc func checkForUpdates() {
        UpdateService.shared.checkForUpdates(silent: false)
    }

    @objc func clearInput() {
        NotificationCenter.default.post(name: .clearInput, object: nil)
    }
    
    @objc func formatJSON() {
        NotificationCenter.default.post(name: .formatJSON, object: nil)
    }
    
    @objc func sortKeys() {
        NotificationCenter.default.post(name: .sortKeys, object: nil)
    }

    @objc func autoFitColumnWidth() {
        NotificationCenter.default.post(name: .autoFitColumnWidth, object: nil)
    }

    @objc func addColumn() {
        NotificationCenter.default.post(name: .addColumn, object: nil)
    }

    @objc func findInJSON() {
        NotificationCenter.default.post(name: .findInJSON, object: nil)
    }

    @objc func findNextInJSON() {
        NotificationCenter.default.post(name: .findNextInJSON, object: nil)
    }

    @objc func findPreviousInJSON() {
        NotificationCenter.default.post(name: .findPreviousInJSON, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clearInput = Notification.Name("clearInput")
    static let formatJSON = Notification.Name("formatJSON")
    static let sortKeys = Notification.Name("sortKeys")
    static let autoFitColumnWidth = Notification.Name("autoFitColumnWidth")
    static let addColumn = Notification.Name("addColumn")
    static let findInJSON = Notification.Name("findInJSON")
    static let findNextInJSON = Notification.Name("findNextInJSON")
    static let findPreviousInJSON = Notification.Name("findPreviousInJSON")
    static let documentModified = Notification.Name("documentModified")
}
