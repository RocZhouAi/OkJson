//  ColorScheme.swift
//  OkJson
//
//  Syntax highlighting color definitions and utilities
//

import Foundation
import SwiftUI

/// Syntax highlighting color definitions
enum SyntaxColor {
    // MARK: - Default Scheme Colors

    static let defaultKey = Color(red: 0.2, green: 0.5, blue: 1.0) // Bright blue
    static let defaultString = Color(red: 0.42, green: 0.53, blue: 0.35) // #6A8759
    static let defaultNumber = Color(red: 0.41, green: 0.59, blue: 0.73) // #6897BB
    static let defaultBoolean = Color(red: 0.8, green: 0.47, blue: 0.2) // #CC7832
    static let defaultNull = Color(red: 0.8, green: 0.47, blue: 0.2) // #CC7832

    // MARK: - Dark Scheme Colors

    static let darkKey = Color(red: 0.4, green: 0.6, blue: 0.8)
    static let darkString = Color(red: 0.5, green: 0.8, blue: 0.5)
    static let darkNumber = Color(red: 0.5, green: 0.7, blue: 0.9)
    static let darkBoolean = Color(red: 0.9, green: 0.6, blue: 0.3)
    static let darkNull = Color(red: 0.9, green: 0.6, blue: 0.3)

    // MARK: - Diff Colors

    static let additionBackground = Color.green.opacity(0.2)
    static let deletionBackground = Color.red.opacity(0.2)
    static let modificationBackground = Color.yellow.opacity(0.2)

    // MARK: - Error Colors

    static let errorBackground = Color(red: 1, green: 0.8, blue: 0.8)
}

/// Token type for syntax highlighting
enum TokenType {
    case key
    case string
    case number
    case boolean
    case null
    case whitespace
    case punctuation
    case unknown
}

/// Get color for token type based on scheme
func colorFor(token: TokenType, scheme: ColorSchemeEnum) -> Color {
    switch scheme {
    case .default:
        switch token {
        case .key: return SyntaxColor.defaultKey
        case .string: return SyntaxColor.defaultString
        case .number: return SyntaxColor.defaultNumber
        case .boolean, .null: return SyntaxColor.defaultBoolean
        default: return Color.primary
        }
    case .dark:
        switch token {
        case .key: return SyntaxColor.darkKey
        case .string: return SyntaxColor.darkString
        case .number: return SyntaxColor.darkNumber
        case .boolean, .null: return SyntaxColor.darkBoolean
        default: return Color.primary
        }
    case .highContrast:
        return Color.primary
    }
}
