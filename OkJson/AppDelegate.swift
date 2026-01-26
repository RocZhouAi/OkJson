//  AppDelegate.swift
//  OkJson
//
//  Application delegate - Pure AppKit

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindowController: MainWindowController?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建主窗口
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        
        // 设置菜单
        setupMenuBar()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
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
        appMenu.addItem(withTitle: "Quit OkJson", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // File 菜单
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Clear Input", action: #selector(clearInput), keyEquivalent: "k")
        
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
        
        // JSON 菜单
        let jsonMenuItem = NSMenuItem()
        mainMenu.addItem(jsonMenuItem)
        let jsonMenu = NSMenu(title: "JSON")
        jsonMenuItem.submenu = jsonMenu
        
        let formatItem = NSMenuItem(title: "Format JSON", action: #selector(formatJSON), keyEquivalent: "r")
        formatItem.keyEquivalentModifierMask = [.command]
        jsonMenu.addItem(formatItem)
        
        jsonMenu.addItem(NSMenuItem.separator())
        
        let pasteItem = NSMenuItem(title: "Paste JSON", action: #selector(pasteJSON), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command, .shift]
        jsonMenu.addItem(pasteItem)
        
        let copyResultItem = NSMenuItem(title: "Copy Formatted Result", action: #selector(copyFormattedResult), keyEquivalent: "c")
        copyResultItem.keyEquivalentModifierMask = [.command, .shift]
        jsonMenu.addItem(copyResultItem)
        
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
    
    @objc func clearInput() {
        NotificationCenter.default.post(name: .clearInput, object: nil)
    }
    
    @objc func formatJSON() {
        NotificationCenter.default.post(name: .formatJSON, object: nil)
    }
    
    @objc func minifyJSON() {
        NotificationCenter.default.post(name: .minifyJSON, object: nil)
    }
    
    @objc func pasteJSON() {
        NotificationCenter.default.post(name: .pasteJSON, object: nil)
    }
    
    @objc func copyFormattedResult() {
        NotificationCenter.default.post(name: .copyFormattedResult, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clearInput = Notification.Name("clearInput")
    static let formatJSON = Notification.Name("formatJSON")
    static let minifyJSON = Notification.Name("minifyJSON")
    static let pasteJSON = Notification.Name("pasteJSON")
    static let copyFormattedResult = Notification.Name("copyFormattedResult")
}
