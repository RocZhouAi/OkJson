//  ColorScheme.swift
//  OkJson
//
//  Syntax highlighting color definitions and utilities

import Foundation
import AppKit

/// Syntax highlighting color definitions
enum SyntaxColor {
    // MARK: - Default Scheme Colors

    static let defaultKey = NSColor(red: 0.729, green: 0.522, blue: 0.984, alpha: 1.0) // #BA85FB 紫
    static let defaultString = NSColor(red: 0.0, green: 0.882, blue: 0.671, alpha: 1.0) // #00E1AB 绿
    static let defaultNumber = NSColor(red: 0.0, green: 0.882, blue: 0.671, alpha: 1.0) // #00E1AB 绿（数字归为 value）
    static let defaultBoolean = NSColor(red: 0.8, green: 0.47, blue: 0.2, alpha: 1.0) // #CC7832
    static let defaultNull = NSColor(red: 0.8, green: 0.47, blue: 0.2, alpha: 1.0) // #CC7832

    // MARK: - Dark Scheme Colors

    static let darkKey = NSColor(red: 0.729, green: 0.522, blue: 0.984, alpha: 1.0)  // #BA85FB 紫
    static let darkString = NSColor(red: 0.0, green: 0.882, blue: 0.671, alpha: 1.0) // #00E1AB 绿
    static let darkNumber = NSColor(red: 0.0, green: 0.882, blue: 0.671, alpha: 1.0) // #00E1AB 绿（数字归为 value）
    static let darkBoolean = NSColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1.0)
    static let darkNull = NSColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1.0)

    // MARK: - Diff Colors

    static let additionBackground = NSColor.green.withAlphaComponent(0.2)
    static let deletionBackground = NSColor.red.withAlphaComponent(0.2)
    static let modificationBackground = NSColor.yellow.withAlphaComponent(0.2)

    // MARK: - Error Colors

    static let errorBackground = NSColor(red: 1, green: 0.8, blue: 0.8, alpha: 1.0)
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
func colorFor(token: TokenType, scheme: ColorSchemeEnum) -> NSColor {
    switch scheme {
    case .default:
        switch token {
        case .key: return SyntaxColor.defaultKey
        case .string: return SyntaxColor.defaultString
        case .number: return SyntaxColor.defaultNumber
        case .boolean, .null: return SyntaxColor.defaultBoolean
        default: return NSColor.labelColor
        }
    case .dark:
        switch token {
        case .key: return SyntaxColor.darkKey
        case .string: return SyntaxColor.darkString
        case .number: return SyntaxColor.darkNumber
        case .boolean, .null: return SyntaxColor.darkBoolean
        default: return NSColor.labelColor
        }
    case .highContrast:
        return NSColor.labelColor
    }
}
