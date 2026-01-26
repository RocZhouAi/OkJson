//  MainWindowController.swift
//  OkJson
//
//  Main window controller - Pure AppKit

import AppKit

class MainWindowController: NSWindowController {
    
    private var appContainerViewController: AppContainerViewController!
    
    convenience init() {
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OkJson"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified // Use unified style for the modern look
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
        // 让分段控件居中
        toolbar.centeredItemIdentifier = .modeSwitch
        
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
        window?.titleVisibility = .hidden
    }
    
    @objc private func onModeChanged(_ sender: NSSegmentedControl) {
        appContainerViewController.mainViewController.selectedTabViewItemIndex = sender.selectedSegment
    }
    
    @objc private func onSettingsClicked() {
        appContainerViewController.mainViewController.selectedTabViewItemIndex = 2
        // 取消选中分段控件，表明当前不在 Format/Compare 模式
        if let modeSwitchItem = window?.toolbar?.items.first(where: { $0.itemIdentifier == .modeSwitch }),
           let control = modeSwitchItem.view as? NSSegmentedControl {
            control.selectedSegment = -1
        }
    }
}


extension MainWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {

        saveWindowFrame()
    }
    
    func windowDidMove(_ notification: Notification) {
         // Optionally save on move too if you want to remember position
         // saveWindowFrame()
    }
    
    func windowWillClose(_ notification: Notification) {

        saveWindowFrame()
    }
}

extension NSToolbarItem.Identifier {
    static let modeSwitch = NSToolbarItem.Identifier("com.okjson.modeSwitch")
    static let settings = NSToolbarItem.Identifier("com.okjson.settings")
}

extension MainWindowController: NSToolbarDelegate {
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // 布局：(Flexible) - [Format | Compare] - (Flexible) - [Settings]
        return [.flexibleSpace, .modeSwitch, .flexibleSpace, .settings]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.modeSwitch, .settings, .flexibleSpace]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        if itemIdentifier == .modeSwitch {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            let control = NSSegmentedControl(labels: ["Format", "Compare"], trackingMode: .selectOne, target: self, action: #selector(onModeChanged(_:)))
            control.segmentStyle = .texturedRounded
            control.selectedSegment = 0 // 默认选中 Format
            
            item.view = control
            item.label = "Mode"
            item.paletteLabel = "Mode"
            return item
            
        } else if itemIdentifier == .settings {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            let image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
            let button = NSButton(image: image!, target: self, action: #selector(onSettingsClicked))
            button.bezelStyle = .texturedRounded
            button.identifier = NSUserInterfaceItemIdentifier("SettingsButton")
            
            item.view = button
            item.label = "Settings"
            item.paletteLabel = "Settings"
            return item
        }
        
        return nil
    }
}
