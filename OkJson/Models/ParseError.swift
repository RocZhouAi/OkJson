//  ParseError.swift
//  OkJson
//
//  Represents JSON syntax error with location
//

import Foundation

/// JSON syntax error with precise location information
struct ParseError: Error, Equatable, Sendable {
    // MARK: - Properties

    /// Human-readable error description
    let message: String

    /// Line number where error occurred (1-based)
    let line: Int

    /// Column position (1-based)
    let column: Int

    /// Byte offset in source string
    let offset: Int

    /// Snippet of code around error position (~40 characters)
    let context: String?

    // MARK: - Initialization

    init(message: String, line: Int, column: Int, offset: Int, context: String? = nil) {
        self.message = message
        self.line = max(1, line)
        self.column = max(1, column)
        self.offset = max(0, offset)
        self.context = context
    }

    // MARK: - Computed Properties

    /// Formatted error description for display
    var localizedDescription: String {
        if let context = context {
            return "Line \(line), Column \(column): \(message)\n\n\(context)"
        }
        return "Line \(line), Column \(column): \(message)"
    }
}

// MARK: - CustomStringConvertible

extension ParseError: CustomStringConvertible {
    var description: String {
        localizedDescription
    }
}

// MARK: - LocalizedError

extension ParseError: LocalizedError {
    var errorDescription: String? {
        localizedDescription
    }
}
