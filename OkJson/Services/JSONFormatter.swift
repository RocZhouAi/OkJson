//  JSONFormatter.swift
//  OkJson
//
//  Service for syntax highlighting JSON text
//  (Previously known as SyntaxHighlightService, moved here to fix Xcode project reference issues)
//

import AppKit

class SyntaxHighlightService {
    
    static let shared = SyntaxHighlightService()
    
    private init() {}
    
    // Regex pattern to identifying JSON tokens
    // Group 1: String (Quoted)
    // Group 2: Key delimiter (colon) - if present with Group 1, it's a key
    // Group 3: Number
    // Group 4: Boolean or Null
    private let jsonPattern = "(\"(?:[^\"\\\\]|\\\\.)*\")\\s*(:)?|(-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)|(true|false|null)"
    
    private lazy var regex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: jsonPattern, options: [])
    }()
    
    /// Synchronously highlight text storage (Main Thread Only)
    func highlight(_ textStorage: NSTextStorage) {
        let string = textStorage.string
        // 1. Reset base attributes first
        let fullRange = NSRange(location: 0, length: string.utf16.count)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        
        // 2. Calculate highlights
        let highlights = calculateHighlights(for: string)
        
        // 3. Apply highlights
        textStorage.beginEditing()
        for (range, color) in highlights {
            textStorage.addAttribute(.foregroundColor, value: color, range: range)
        }
        textStorage.endEditing()
    }
    
    /// Calculate highlights for a given string (Thread Safe)
    /// - Parameters:
    ///   - string: The JSON string to highlight
    ///   - isDark: Optional explicit theme preference. If nil, tries to detect from Main Thread or defaults to false.
    func calculateHighlights(for string: String, isDark: Bool? = nil) -> [(NSRange, NSColor)] {
        guard let regex = regex else { return [] }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        var highlights: [(NSRange, NSColor)] = []
        
        let safeIsDark: Bool
        if let isDark = isDark {
            safeIsDark = isDark
        } else {
            // If on main thread, we can check. If on bg, default to false.
            if Thread.isMainThread {
                 safeIsDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            } else {
                 safeIsDark = false
            }
        }
        
        let scheme: ColorSchemeEnum = safeIsDark ? .dark : .default
        
        regex.enumerateMatches(in: string, options: [], range: range) { match, flags, stop in
            guard let match = match else { return }
            
            // Group 1: String
            if let stringRange = Range(match.range(at: 1), in: string) {
                let nsRange = NSRange(stringRange, in: string)
                let isKey = match.range(at: 2).location != NSNotFound
                
                if isKey {
                    highlights.append((nsRange, colorFor(token: .key, scheme: scheme)))
                } else {
                     highlights.append((nsRange, colorFor(token: .string, scheme: scheme)))
                }
            }
            // Group 3: Number
            else if let numberRange = Range(match.range(at: 3), in: string) {
                 let nsRange = NSRange(numberRange, in: string)
                 highlights.append((nsRange, colorFor(token: .number, scheme: scheme)))
            }
            // Group 4: Boolean/Null
            else if let specialRange = Range(match.range(at: 4), in: string) {
                 let nsRange = NSRange(specialRange, in: string)
                 highlights.append((nsRange, colorFor(token: .boolean, scheme: scheme)))
            }
        }
        
        return highlights
    }
}

// MARK: - Legacy Compatibility

/// JSON formatter service (Legacy stub)
final class JSONFormatter {
    static let shared = JSONFormatter()
    private init() {}
}
