//  DocumentSource.swift
//  OkJson
//
//  Tracks where JSON content originated
//

import Foundation

/// Where the JSON content came from
enum DocumentSource: Equatable, Sendable {
    /// Pasted from clipboard
    case clipboard

    /// Loaded from disk
    case file(URL)

    /// User entered manually
    case typed

    /// Dropped into window
    case dragAndDrop(URL)

    /// Built-in example
    case sample

    // MARK: - Computed Properties

    /// Human-readable description
    var description: String {
        switch self {
        case .clipboard:
            return "Clipboard"
        case .file(let url):
            return "File: \(url.lastPathComponent)"
        case .typed:
            return "Typed"
        case .dragAndDrop(let url):
            return "Dropped: \(url.lastPathComponent)"
        case .sample:
            return "Sample"
        }
    }

    /// File URL if applicable
    var fileURL: URL? {
        switch self {
        case .file(let url), .dragAndDrop(let url):
            return url
        default:
            return nil
        }
    }
}
