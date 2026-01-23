//  JSONFormatter.swift
//  OkJson
//
//  JSON formatting service
//

import Foundation

/// JSON formatting service
final class JSONFormatter {
    // MARK: - Singleton

    static let shared = JSONFormatter()

    private init() {}

    // MARK: - Format Method

    /// Format JSONNode to string with options
    func format(_ node: JSONNode, options: FormatOptions = FormatOptions()) -> String {
        var output = ""
        formatNode(node, indent: 0, options: options, output: &output)
        return output
    }

    // MARK: - Minify Method

    /// Compress JSON by removing whitespace
    func minify(_ node: JSONNode) -> String {
        var output = ""
        formatNode(node, indent: 0, options: FormatOptions(indentation: 0), output: &output)
        return output.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    }

    // MARK: - Private Helpers

    private func formatNode(
        _ node: JSONNode,
        indent: Int,
        options: FormatOptions,
        output: inout String
    ) {
        let indentString = String(repeating: " ", count: indent)

        switch node.type {
        case .object:
            if node.children.isEmpty {
                output += "{}"
            } else {
                output += "{\n"

                var sortedChildren = node.children
                if options.sortKeys {
                    sortedChildren = node.children.sorted {
                        guard let key1 = $0.key, let key2 = $1.key else {
                            return $0.key ?? "" < $1.key ?? ""
                        }
                        return key1 < key2
                    }
                }

                for (index, child) in sortedChildren.enumerated() {
                    output += indentString + String(repeating: " ", count: options.indentation)

                    if let key = child.key {
                        output += "\"\(key)\": "
                    }

                    formatNode(child, indent: indent + options.indentation, options: options, output: &output)

                    if index < sortedChildren.count - 1 {
                        output += ","
                    }
                    output += "\n"
                }

                output += indentString + "}"
            }

        case .array:
            if node.children.isEmpty {
                output += "[]"
            } else {
                output += "[\n"

                for (index, child) in node.children.enumerated() {
                    output += indentString + String(repeating: " ", count: options.indentation)
                    formatNode(child, indent: indent + options.indentation, options: options, output: &output)

                    if index < node.children.count - 1 {
                        output += ","
                    }
                    output += "\n"
                }

                output += indentString + "]"
            }

        case .string:
            if let value = node.value as? String {
                output += "\"\(escapeString(value))\""
            } else {
                output += "\"\""
            }

        case .number:
            output += node.displayValue

        case .boolean:
            output += node.displayValue

        case .null:
            output += node.displayValue
        }
    }

    private func escapeString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// MARK: - FormatOptions

struct FormatOptions {
    var indentation: Int
    var sortKeys: Bool

    init(indentation: Int = 2, sortKeys: Bool = false) {
        self.indentation = indentation
        self.sortKeys = sortKeys
    }
}
