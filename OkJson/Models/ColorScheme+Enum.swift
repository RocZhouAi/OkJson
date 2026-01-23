//  ColorScheme+Enum.swift
//  OkJson
//
//  Syntax highlighting color scheme enum for UI selection
//

import Foundation
import SwiftUI

/// Syntax highlighting theme selector for UI
enum ColorSchemeEnum: String, CaseIterable, Identifiable {
    case `default`
    case dark
    case highContrast

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .dark: return "Dark"
        case .highContrast: return "High Contrast"
        }
    }
}
