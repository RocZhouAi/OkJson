//  Indentation.swift
//  OkJson
//
//  Indentation options for JSON formatting
//

import Foundation

/// Indentation size options
enum Indentation: Int, CaseIterable, Identifiable, Sendable {
    case twoSpaces = 2
    case fourSpaces = 4

    // MARK: - Identifiable

    var id: Int { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        "\(rawValue) spaces"
    }

    /// The indentation string (e.g., "  " or "    ")
    var stringValue: String {
        String(repeating: " ", count: rawValue)
    }
}
