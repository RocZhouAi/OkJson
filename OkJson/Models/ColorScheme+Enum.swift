//  ColorScheme+Enum.swift
//  OkJson
//
//  Syntax highlighting color scheme enum for UI selection

import Foundation

/// Syntax highlighting theme selector for UI
enum ColorSchemeEnum: String, CaseIterable {
    case `default`
    case dark
    case highContrast

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .dark: return "Dark"
        case .highContrast: return "High Contrast"
        }
    }
}
