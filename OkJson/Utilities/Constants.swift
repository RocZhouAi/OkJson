//  Constants.swift
//  OkJson
//
//  App-wide constants
//

import Foundation

/// App-wide constants
enum Constants {
    // MARK: - App Info

    static let appName = "OkJson"
    static let appVersion = "1.2.0"

    // MARK: - File Size Limits

    /// Maximum file size in bytes (10MB)
    static let maxFileSizeBytes: Int = 10 * 1024 * 1024

    /// File size warning threshold (5MB)
    static let fileSizeWarningThreshold: Int = 5 * 1024 * 1024

    // MARK: - Performance

    /// Maximum nesting depth for default expansion
    static let defaultMaxDepth: Int = 3

    // MARK: - 大值截断

    /// 字符串值超过此字节数时截断显示（默认 200 字符）
    static let valueTruncationThreshold: Int = 200

    /// 截断后保留的前缀长度
    static let truncationPrefixLength: Int = 80

    /// 截断后保留的后缀长度
    static let truncationSuffixLength: Int = 40

    /// Indentation options
    static let indentationOptions = [2, 4]

    // MARK: - Default Content

    /// Default JSON for testing/demo (empty for production)
    static let defaultJSON = ""

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let indentation = "indentation"
        static let sortKeys = "sortKeys"
        static let syncScroll = "syncScroll"
        static let colorScheme = "colorScheme"
        static let maxDepth = "maxDepth"
        static let lineNumbers = "lineNumbers"
    }

    // MARK: - Error Messages

    enum ErrorMessages {
        static let emptyInput = "Input cannot be empty"
        static let invalidJSON = "Invalid JSON"
        static let fileTooLarge = "File size exceeds 10MB limit"
        static let networkDriveNotSupported = "Network drives are not supported"
        static let encodingError = "Unable to read file as UTF-8"
        static let permissionDenied = "Permission denied"
        static let fileNotFound = "File not found"
    }
    
    // MARK: - Notifications
    
    enum Notifications {
        /// 格式化设置变化通知（缩进、排序等）
        static let formatSettingsChanged = Notification.Name("OkJson.formatSettingsChanged")
        /// 显示设置变化通知（行号等）
        static let displaySettingsChanged = Notification.Name("OkJson.displaySettingsChanged")
        /// 主题变化通知
        static let themeChanged = Notification.Name("OkJson.themeChanged")
    }
}
