//  ClipboardService.swift
//  OkJson
//
//  Clipboard operations service
//

import Foundation
import AppKit

/// Clipboard operations service
final class ClipboardService {
    // MARK: - Singleton

    static let shared = ClipboardService()

    private init() {}

    // MARK: - Copy Method

    /// Copy text to clipboard
    /// - Parameter text: The text to copy
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Read Method

    /// Read current clipboard content
    /// - Returns: Clipboard content if text, nil otherwise
    func read() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }

    // MARK: - Has JSON Detection

    /// Check if clipboard likely contains JSON
    /// - Returns: true if clipboard starts with { or [
    func hasJSON() -> Bool {
        guard let content = read() else { return false }
        return content.trimmingCharacters(in: .whitespacesAndNewlines).looksLikeJSON
    }
}
