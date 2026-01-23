//  FormatterViewModel.swift
//  OkJson
//
//  View model for JSON formatter
//

import Foundation
import SwiftUI
import Combine

/// View model for the JSON formatter view
@MainActor
final class FormatterViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Raw input text from user
    @Published var inputText: String = Constants.defaultJSON

    /// Parsed JSON tree for tree view display
    @Published var parsedTree: JSONNode?

    /// Formatted JSON output (text format)
    @Published var formattedText: String = ""

    /// View mode: tree or code
    @Published var viewMode: ViewMode = .tree

    /// Parse error if any
    @Published var parseError: ParseError?

    /// Whether processing is in progress
    @Published var isProcessing: Bool = false

    /// User formatting preferences
    @Published var preferences: FormatPreference = .default

    // MARK: - View Mode

    enum ViewMode: String, CaseIterable {
        case tree = "Tree"
        case code = "Code"

        var icon: String {
            switch self {
            case .tree: return "list.bullet.indent"
            case .code: return "doc.text"
            }
        }
    }

    // MARK: - Services

    private let parser = JSONParser.shared
    private let formatter = JSONFormatter.shared
    private let clipboard = ClipboardService.shared

    // MARK: - Initialization

    init() {
        // Delay formatting to avoid initialization issues
        Task { @MainActor in
            formatJSON()
        }
    }

    // MARK: - Format Method

    /// Format the input JSON
    func formatJSON() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
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

        switch parser.parse(inputText) {
        case .success(let node):
            self.parsedTree = node
            let options = FormatOptions(
                indentation: preferences.indentationSize.rawValue,
                sortKeys: preferences.sortKeys
            )
            self.formattedText = formatter.format(node, options: options)
            self.parseError = nil

        case .failure(let error):
            self.parseError = error
            self.formattedText = ""
            self.parsedTree = nil
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

        switch parser.parse(inputText) {
        case .success(let node):
            self.formattedText = formatter.minify(node)
            self.parseError = nil

        case .failure(let error):
            self.parseError = error
            self.formattedText = ""
        }
    }

    // MARK: - Paste from Clipboard

    /// Paste JSON from clipboard
    func pasteFromClipboard() {
        guard let content = clipboard.read() else { return }

        self.inputText = content
        self.formatJSON()
    }

    // MARK: - Clear All

    /// Clear input and output
    func clear() {
        inputText = ""
        formattedText = ""
        parsedTree = nil
        parseError = nil
    }
    
    // MARK: - Update Node Key
    
    /// 更新节点的键名
    func updateNodeKey(node: JSONNode, newKey: String) {
        guard var tree = parsedTree else { return }
        
        // 递归查找并更新节点
        func updateKey(in currentNode: inout JSONNode) -> Bool {
            if currentNode.id == node.id {
                currentNode.key = newKey
                return true
            }
            for i in currentNode.children.indices {
                if updateKey(in: &currentNode.children[i]) {
                    return true
                }
            }
            return false
        }
        
        if updateKey(in: &tree) {
            self.parsedTree = tree
            // 重新格式化文本输出
            let options = FormatOptions(
                indentation: preferences.indentationSize.rawValue,
                sortKeys: preferences.sortKeys
            )
            self.formattedText = formatter.format(tree, options: options)
        }
    }
}
