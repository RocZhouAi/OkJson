//  FormatterViewModel.swift
//  OkJson
//
//  View model for JSON formatter - Pure AppKit (no SwiftUI dependencies)

import Foundation
import AppKit

/// View model for the JSON formatter - AppKit version
class FormatterViewModel {
    
    // MARK: - Properties
    
    /// Raw input text from user
    var inputText: String = Constants.defaultJSON {
        didSet {
            onInputTextChanged?(inputText)
        }
    }
    
    /// Parsed JSON tree for tree view display
    var parsedTree: IndexedJSONNode? {
        didSet {
            onParsedTreeChanged?()
        }
    }
    
    /// Formatted JSON output (text format)
    var formattedText: String = ""
    
    /// Parse error if any
    var parseError: ParseError? {
        didSet {
            onParseErrorChanged?()
        }
    }
    
    /// Whether processing is in progress
    var isProcessing: Bool = false
    
    /// Whether to sort keys alphabetically
    var sortKeys: Bool = false {
        didSet {
            // Re-format if changed
            if !inputText.isEmpty {
                formatJSON()
            }
        }
    }
    
    /// Indentation size (2 or 4 spaces)
    var indentation: Int = 2
    
    // MARK: - Callbacks
    
    var onInputTextChanged: ((String) -> Void)?
    var onParsedTreeChanged: (() -> Void)?
    var onParseErrorChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // 从 UserDefaults 读取设置
        loadSettings()
        
        // 监听格式化设置变化（只在设置页面修改时触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(formatSettingsDidChange),
            name: Constants.Notifications.formatSettingsChanged,
            object: nil
        )
        
        // 初始化时格式化默认 JSON
        DispatchQueue.main.async { [weak self] in
            self?.formatJSON()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Settings
    
    /// 从 UserDefaults 加载设置
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // 读取排序设置
        sortKeys = defaults.bool(forKey: Constants.UserDefaultsKeys.sortKeys)
        
        // 读取缩进设置 (默认为 2)
        let savedIndentation = defaults.integer(forKey: Constants.UserDefaultsKeys.indentation)
        indentation = savedIndentation == 4 ? 4 : 2
    }
    
    @objc private func formatSettingsDidChange(_ notification: Notification) {
        // 重新加载设置
        let defaults = UserDefaults.standard
        
        let newSortKeys = defaults.bool(forKey: Constants.UserDefaultsKeys.sortKeys)
        let savedIndentation = defaults.integer(forKey: Constants.UserDefaultsKeys.indentation)
        let newIndentation = savedIndentation == 4 ? 4 : 2
        
        // 只有设置真的变化了才重新格式化
        let needsReformat = (newSortKeys != sortKeys) || (newIndentation != indentation)
        
        // 直接设置，避免触发 didSet 中的重复格式化
        if newSortKeys != sortKeys {
            sortKeys = newSortKeys
        }
        indentation = newIndentation
        
        // 手动触发一次格式化
        if needsReformat && !inputText.isEmpty {
            formatJSON()
        }
    }
    
    // MARK: - Format Method
    
    /// Format the input JSON
    /// - Parameter forceGenerateString: Ensure string is generated even for large files
    func formatJSON(forceGenerateString: Bool = false) {
        // Capture input to avoid threading issues
        let input = inputText
        
        guard !input.isEmpty else {
            self.parseError = ParseError(
                message: Constants.ErrorMessages.emptyInput,
                line: 1,
                column: 1,
                offset: 0
            )
            self.formattedText = ""
            self.parsedTree = nil
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Capture settings to avoid threading issues
        let currentIndentation = indentation
        
        // Asynchronous processing to prevent UI freezing on large files
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Trim on background thread (heavy for huge strings)
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                 DispatchQueue.main.async {
                     self.parseError = ParseError(
                         message: Constants.ErrorMessages.emptyInput,
                         line: 1,
                         column: 1,
                         offset: 0
                     )
                     self.formattedText = ""
                     self.parsedTree = nil
                 }
                 return
            }
            
            // Large file threshold (1MB)
            let isLargeFile = trimmed.count > 1_000_000
            let shouldGenerateString = forceGenerateString || !isLargeFile
            
            // 使用基于索引的按需解析
            if let indexedNode = IndexedJSONNode.fromJSONString(trimmed, shouldSortKeys: self.sortKeys) {
                
                var formatted = ""
                if shouldGenerateString {
                    formatted = indexedNode.prettyJSONString(indentation: currentIndentation)
                }
                
                DispatchQueue.main.async {
                    self.formattedText = formatted
                    self.parsedTree = indexedNode
                    self.parseError = nil
                    
                    // If we skipped generation, we might want to notify UI or just leave it empty
                    // The UI should handle empty formattedText if parsedTree is present (as "Large File Mode")
                }
            } else {
                DispatchQueue.main.async {
                    self.parseError = ParseError(
                        message: Constants.ErrorMessages.invalidJSON,
                        line: 1,
                        column: 1,
                        offset: 0
                    )
                    self.formattedText = ""
                    self.parsedTree = nil
                }
            }
        }
    }
    
    /// Ensure formatted text is generated (e.g. for Copy or Text View)
    func ensureFormattedText(_ completion: (() -> Void)? = nil) {
        guard formattedText.isEmpty, let tree = parsedTree else {
            completion?()
            return
        }
        
        let currentIndentation = indentation
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let formatted = tree.prettyJSONString(indentation: currentIndentation)
            DispatchQueue.main.async {
                self?.formattedText = formatted
                self?.isProcessing = false
                completion?()
            }
        }
    }
    

    
    // MARK: - Minify Method
    
    /// Minify the input JSON
    func minifyJSON() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            self.parseError = ParseError(
                message: Constants.ErrorMessages.emptyInput,
                line: 1,
                column: 1,
                offset: 0
            )
            return
        }
        

        
        isProcessing = true
        defer { isProcessing = false }
        
        // 使用简单的字符串处理来压缩 JSON
        self.formattedText = minifyJSONString(inputText)
        self.parseError = nil
    }
    
    /// 简单的 JSON 压缩
    private func minifyJSONString(_ json: String) -> String {
        var result = ""
        var inString = false
        
        for char in json {
            if inString {
                result.append(char)
                if char == "\\" {
                    continue
                }
                if char == "\"" {
                    inString = false
                }
                continue
            }
            
            switch char {
            case "\"":
                inString = true
                result.append(char)
            case " ", "\n", "\r", "\t":
                break // 跳过空白
            default:
                result.append(char)
            }
        }
        
        return result
    }
    
    // MARK: - Clipboard
    
    /// Paste JSON from clipboard
    func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputText = string
            formatJSON()
        }
    }
    
    /// Copy formatted JSON to clipboard
    func copyToClipboard() {
        // 如果有格式化后的文本，直接复制
        if !formattedText.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(formattedText, forType: .string)
            return
        }
        
        // 如果有解析树但没有格式化文本（大文件模式），先生成再复制
        if let tree = parsedTree {
            let currentIndentation = indentation
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let formatted = tree.prettyJSONString(indentation: currentIndentation)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.formattedText = formatted
                    self.isProcessing = false
                    
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(formatted, forType: .string)
                }
            }
            return
        }
        
        // 没有有效内容，尝试先格式化再复制
        if !inputText.isEmpty {
            formatJSON(forceGenerateString: true)
            // 格式化是异步的，需要在完成后复制
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, !self.formattedText.isEmpty else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(self.formattedText, forType: .string)
            }
        }
    }
    
    // MARK: - Clear
    
    /// Clear all content
    func clear() {
        inputText = ""
        formattedText = ""
        parsedTree = nil
        parseError = nil
    }
    
    // MARK: - Helper
    

}
