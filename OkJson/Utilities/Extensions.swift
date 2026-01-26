//  Extensions.swift
//  OkJson
//
//  Foundation extensions

import Foundation

// MARK: - String Extensions

extension String {
    /// Strip leading and trailing whitespace from each line
    func trimmedLines() -> String {
        split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    /// Check if string appears to be JSON
    var looksLikeJSON: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }

    /// Count tabs and spaces for indentation detection
    var indentationLevel: Int {
        prefix(while: { $0 == " " || $0 == "\t" }).count
    }

    /// Get parent path from JSONPath
    var parentPath: String {
        guard let lastDot = lastIndex(of: ".") else {
            return self
        }
        return String(prefix(upTo: lastDot))
    }

    /// Get last component from JSONPath
    var lastComponent: String {
        guard let lastDot = lastIndex(of: ".") else {
            return self
        }
        return String(suffix(from: index(after: lastDot)))
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript returning optional
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    /// Check if dictionary is empty
    var isNotEmpty: Bool {
        !isEmpty
    }
}
