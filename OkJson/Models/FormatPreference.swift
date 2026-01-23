//  FormatPreference.swift
//  OkJson
//
//  User settings for JSON formatting and display
//

import Foundation

/// User settings for JSON formatting and display
struct FormatPreference: Equatable {
    // MARK: - Properties

    /// Indentation size (2 or 4 spaces)
    var indentationSize: Indentation

    /// Alphabetically sort object keys
    var sortKeys: Bool

    /// Link scroll in comparison view
    var synchronizedScroll: Bool

    /// Syntax highlighting theme
    var colorScheme: ColorSchemeEnum

    /// Default collapse depth for tree view (1-10)
    var maxDepth: Int

    /// Display line numbers in code view
    var showLineNumbers: Bool

    // MARK: - Default Values

    static let `default` = FormatPreference(
        indentationSize: .twoSpaces,
        sortKeys: false,
        synchronizedScroll: true,
        colorScheme: .default,
        maxDepth: 3,
        showLineNumbers: true
    )

    // MARK: - Initialization

    init(
        indentationSize: Indentation = .twoSpaces,
        sortKeys: Bool = false,
        synchronizedScroll: Bool = true,
        colorScheme: ColorSchemeEnum = .default,
        maxDepth: Int = 3,
        showLineNumbers: Bool = true
    ) {
        self.indentationSize = indentationSize
        self.sortKeys = sortKeys
        self.synchronizedScroll = synchronizedScroll
        self.colorScheme = colorScheme
        // Clamp maxDepth between 1 and 10
        self.maxDepth = max(1, min(10, maxDepth))
        self.showLineNumbers = showLineNumbers
    }

    // MARK: - Computed Properties

    /// Validation: checks if maxDepth is within valid range
    var isValid: Bool {
        (1...10).contains(maxDepth)
    }
}

