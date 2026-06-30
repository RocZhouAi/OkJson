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

    /// Generation counter for task cancellation
    private var formatGeneration: Int = 0
    
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
    
    // MARK: - File Association
    
    /// 通过文件关联打开时记录源文件路径
    var sourceFilePath: String?

    /// 提供编辑器当前文本（保存时用编辑器实际内容，而非可能过时的 parsedTree/inputText）
    var editorTextProvider: (() -> String)?
    
    /// 自打开文件后内容是否被用户修改过
    var isModifiedSinceFileOpen: Bool = false {
        didSet {
            if oldValue != isModifiedSinceFileOpen { onColumnMetadataChanged?() }
        }
    }

    /// 标记当前内容已被用户修改
    func markAsModified() {
        guard sourceFilePath != nil else { return }
        isModifiedSinceFileOpen = true
        NotificationCenter.default.post(name: .documentModified, object: self)
    }
    
    /// 保存失败原因（用于向用户展示具体提示）
    enum SaveError: LocalizedError {
        case noSourceFile
        case invalidFileName
        case targetExists(String)
        case writeFailed(String)
        case renameFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSourceFile: return "该列未关联文件"
            case .invalidFileName: return "文件名无效（不能为空或包含「/」）"
            case .targetExists(let name): return "目标位置已存在同名文件「\(name)」"
            case .writeFailed(let path): return "无法写入文件：\(path)"
            case .renameFailed(let detail): return "重命名失败：\(detail)"
            }
        }
    }

    /// 将当前内容保存回源文件；若列头标题(文件名)已改动，同目录重命名磁盘文件
    func saveToSourceFile() throws {
        guard let filePath = sourceFilePath else { throw SaveError.noSourceFile }

        let content: String
        if let provider = editorTextProvider {
            content = provider()
        } else if let tree = parsedTree {
            content = tree.prettyJSONString(indentation: indentation)
        } else {
            content = inputText
        }

        let currentURL = URL(fileURLWithPath: filePath)
        let currentName = currentURL.lastPathComponent

        // 目标文件名取列头标题；漏写扩展名则补回原扩展名
        var targetName = columnTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty, !targetName.contains("/") else {
            throw SaveError.invalidFileName
        }
        let originalExt = currentURL.pathExtension
        if !originalExt.isEmpty && (targetName as NSString).pathExtension.isEmpty {
            targetName += "." + originalExt
        }

        let needsRename = targetName != currentName
        let targetURL = currentURL.deletingLastPathComponent().appendingPathComponent(targetName)
        if needsRename && FileManager.default.fileExists(atPath: targetURL.path) {
            throw SaveError.targetExists(targetName)
        }

        // 先写内容到当前路径
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            throw SaveError.writeFailed(filePath)
        }

        // 标题变了则重命名磁盘文件，并回填规范化后的路径与标题
        if needsRename {
            do {
                try FileManager.default.moveItem(at: currentURL, to: targetURL)
            } catch {
                throw SaveError.renameFailed(error.localizedDescription)
            }
            sourceFilePath = targetURL.path
            columnTitle = targetName
        }

        isModifiedSinceFileOpen = false
    }
    
    // MARK: - Column Metadata (Title & Color)
    
    var columnTitle: String = "Column" {
        didSet {
            onColumnMetadataChanged?()
        }
    }
    
    var columnColor: NSColor? = nil {
        didSet {
            onColumnMetadataChanged?()
        }
    }
    
    // MARK: - Callbacks
    
    var onInputTextChanged: ((String) -> Void)?
    var onParsedTreeChanged: (() -> Void)?
    var onParseErrorChanged: (() -> Void)?
    var onColumnMetadataChanged: (() -> Void)?
    
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
    
    /// Format the input JSON
    /// - Parameters:
    ///   - forceGenerateString: Ensure string is generated even for large files
    ///   - sortKeysOverride: Optional override for sortKeys (used for manual sorting)
    ///   - completion: Optional callback invoked on main thread after formatting completes
    func formatJSON(forceGenerateString: Bool = false, sortKeysOverride: Bool? = nil, completion: (() -> Void)? = nil) {
        // 确定是否排序：优先使用 override，否则使用当前设置
        let shouldSort = sortKeysOverride ?? sortKeys
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
            completion?()
            return
        }

        isProcessing = true

        // Increment generation to cancel stale tasks
        formatGeneration += 1
        let currentGeneration = formatGeneration

        // Capture settings to avoid threading issues
        let currentIndentation = indentation

        // Asynchronous processing to prevent UI freezing on large files
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 1. Trim on background thread (heavy for huge strings)
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                 DispatchQueue.main.async {
                     guard currentGeneration == self.formatGeneration else { return }
                     self.parseError = ParseError(
                         message: Constants.ErrorMessages.emptyInput,
                         line: 1,
                         column: 1,
                         offset: 0
                     )
                     self.formattedText = ""
                     self.parsedTree = nil
                     self.isProcessing = false
                     completion?()
                 }
                 return
            }

            // 极致优化：Tree View 模式不需要 prettyJSONString
            // 将阈值降低到 100KB，减少不必要的字符串生成
            let isLargeFile = trimmed.count > 100_000
            let shouldGenerateString = forceGenerateString || !isLargeFile

            // 使用基于索引的按需解析
            if let indexedNode = IndexedJSONNode.fromJSONString(trimmed, shouldSortKeys: shouldSort) {

                var formatted = ""
                if shouldGenerateString {
                    formatted = indexedNode.prettyJSONString(indentation: currentIndentation)
                }

                DispatchQueue.main.async {
                    guard currentGeneration == self.formatGeneration else { return }
                    self.formattedText = formatted
                    self.parsedTree = indexedNode
                    self.parseError = nil
                    self.isProcessing = false
                    completion?()
                }
            } else {
                DispatchQueue.main.async {
                    guard currentGeneration == self.formatGeneration else { return }
                    self.parseError = ParseError(
                        message: Constants.ErrorMessages.invalidJSON,
                        line: 1,
                        column: 1,
                        offset: 0
                    )
                    self.formattedText = ""
                    self.parsedTree = nil
                    self.isProcessing = false
                    completion?()
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
    

    // MARK: - Clear
    
    /// Clear all content
    func clear() {
        markAsModified()
        inputText = ""
        formattedText = ""
        parsedTree = nil
        parseError = nil
        clearSearch()
    }
    
    // MARK: - Search
    
    var searchQuery: String = ""
    
    private(set) var searchResults: [IndexedJSONNode] = []
    private(set) var searchMatchNodeIDs: Set<ObjectIdentifier> = []
    
    /// 每个节点到其父节点的映射（用于展开祖先路径）
    private(set) var nodeParentMap: [ObjectIdentifier: IndexedJSONNode] = [:]
    
    var currentSearchIndex: Int = -1 {
        didSet {
            onSearchStateChanged?()
        }
    }
    
    var onSearchStateChanged: (() -> Void)?
    
    var currentSearchMatch: IndexedJSONNode? {
        guard currentSearchIndex >= 0, currentSearchIndex < searchResults.count else { return nil }
        return searchResults[currentSearchIndex]
    }
    
    func performSearch() {
        guard !searchQuery.isEmpty, let tree = parsedTree else {
            searchResults = []
            searchMatchNodeIDs = []
            nodeParentMap = [:]
            currentSearchIndex = -1
            onSearchStateChanged?()
            return
        }
        
        let query = searchQuery.lowercased()
        var results: [IndexedJSONNode] = []
        var parentMap: [ObjectIdentifier: IndexedJSONNode] = [:]
        
        searchRecursive(node: tree, query: query, results: &results, parentMap: &parentMap)
        
        searchResults = results
        searchMatchNodeIDs = Set(results.map { ObjectIdentifier($0) })
        nodeParentMap = parentMap
        currentSearchIndex = results.isEmpty ? -1 : 0
        onSearchStateChanged?()
    }
    
    private func searchRecursive(
        node: IndexedJSONNode,
        query: String,
        results: inout [IndexedJSONNode],
        parentMap: inout [ObjectIdentifier: IndexedJSONNode]
    ) {
        var matched = false
        
        if let key = node.key, key.lowercased().contains(query) {
            matched = true
        }
        
        if !matched && !node.type.isContainer {
            if node.displayValue.lowercased().contains(query) {
                matched = true
            }
        }
        
        if matched {
            results.append(node)
        }
        
        if node.hasChildren {
            node.loadMore(count: Int.max)
            for i in 0..<node.childCount {
                if let child = node.child(at: i) {
                    parentMap[ObjectIdentifier(child)] = node
                    searchRecursive(node: child, query: query, results: &results, parentMap: &parentMap)
                }
            }
        }
    }
    
    func nextSearchMatch() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
    }
    
    func previousSearchMatch() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchMatchNodeIDs = []
        nodeParentMap = [:]
        currentSearchIndex = -1
        onSearchStateChanged?()
    }
}
