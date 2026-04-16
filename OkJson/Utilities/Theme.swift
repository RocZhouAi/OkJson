//  Theme.swift
//  OkJson
//
//  集中管理所有 UI 主题色，方便后期更换

import AppKit

/// 全局主题色定义
enum Theme {
    
    // MARK: - JSON 语法颜色（TreeView 使用）
    
    /// Key 颜色（如 "name":）
    static let keyColor: NSColor = .systemPurple
    
    /// String 值颜色
    static let stringColor: NSColor = .systemGreen
    
    /// Number 值颜色
    static let numberColor: NSColor = .systemBlue
    
    /// Boolean 值颜色
    static let booleanColor: NSColor = .systemOrange
    
    /// Null 值颜色
    static let nullColor: NSColor = .systemGray
    
    /// 括号/标点默认颜色
    static let punctuationColor: NSColor = .labelColor
    
    /// 括号高亮颜色（选中容器时）
    static let bracketHighlightColor: NSColor = .systemYellow
    
    /// 搜索匹配行背景色
    static let searchMatchColor: NSColor = NSColor.systemYellow.withAlphaComponent(0.15)
    
    /// 当前搜索焦点行背景色
    static let currentSearchMatchColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.3)
    
    /// 搜索匹配文本内联高亮背景色
    static let searchTextHighlightColor: NSColor = NSColor.systemYellow.withAlphaComponent(0.5)
    
    // MARK: - 错误
    
    /// 错误文本颜色
    static let errorColor: NSColor = .systemRed
    
    // MARK: - 选中/焦点
    
    /// 行选中背景色
    static let selectionColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.2)
    
    /// 焦点边框颜色
    static let focusBorderColor: NSColor = .controlAccentColor
    
    // MARK: - 辅助文本
    
    /// 行号颜色
    static let lineNumberColor: NSColor = .secondaryLabelColor
    
    /// 容器摘要信息颜色（如 "3 keys"）
    static let containerInfoColor: NSColor = .secondaryLabelColor
    
    /// 空状态提示文本颜色
    static let emptyStateColor: NSColor = .secondaryLabelColor
    
    /// 空状态次要提示颜色
    static let emptyStateHintColor: NSColor = .tertiaryLabelColor
    
    /// 空状态图标颜色
    static let emptyStateIconColor: NSColor = .secondaryLabelColor
    
    // MARK: - App 主题管理
    
    enum AppTheme: String {
        case light
        case dark
        
        var next: AppTheme {
            switch self {
            case .light: return .dark
            case .dark: return .light
            }
        }
        
        var iconName: String {
            switch self {
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }
        
        func apply() {
            switch self {
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
            // 异步发送通知，确保 Appearance 已传播到所有视图
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Constants.Notifications.themeChanged, object: nil)
            }
        }
    }
    
    /// 当前主题（自动持久化）
    static var current: AppTheme {
        get {
            let key = "AppTheme"
            if let saved = UserDefaults.standard.string(forKey: key),
               let theme = AppTheme(rawValue: saved) {
                return theme
            }
            return .light
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "AppTheme")
            newValue.apply()
        }
    }
}
