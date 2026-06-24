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
    /// Calculate highlights for a given string (Thread Safe & High Performance)
    /// - Parameters:
    ///   - string: The JSON string to highlight
    ///   - isDark: Optional explicit theme preference.
    func calculateHighlights(for string: String, isDark: Bool? = nil) -> [(NSRange, NSColor)] {
        // Fast path for empty
        if string.isEmpty { return [] }
        
        let safeIsDark: Bool
        if let isDark = isDark {
            safeIsDark = isDark
        } else {
            if Thread.isMainThread {
                 safeIsDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            } else {
                 safeIsDark = false
            }
        }
        
        let scheme: ColorSchemeEnum = safeIsDark ? .dark : .default

        // Use NSString for O(1) UTF-16 random access without copying
        let nsString = string as NSString
        let len = nsString.length

        var highlights: [(NSRange, NSColor)] = []
        highlights.reserveCapacity(len / 20)

        // Colors cached
        let keyColor = colorFor(token: .key, scheme: scheme)
        let stringColor = colorFor(token: .string, scheme: scheme)
        let numberColor = colorFor(token: .number, scheme: scheme)
        let boolColor = colorFor(token: .boolean, scheme: scheme)

        var idx = 0

        while idx < len {
            let c = nsString.character(at: idx)
            
            // Check for Quote " (34)
            if c == 34 {
                let start = idx
                idx += 1
                var isEscaped = false
                while idx < len {
                    let sc = nsString.character(at: idx)
                    if isEscaped {
                        isEscaped = false
                    } else {
                        if sc == 92 { // \
                            isEscaped = true
                        } else if sc == 34 { // "
                            idx += 1
                            break
                        }
                    }
                    idx += 1
                }
                
                // End of string. Is it a key?
                // Look ahead for colon
                var p = idx
                var isKey = false
                while p < len {
                    let pc = nsString.character(at: p)
                    if pc == 58 { // :
                        isKey = true
                        break
                    }
                    if pc == 32 || pc == 9 || pc == 10 || pc == 13 { // whitespace
                        p += 1
                        continue
                    }
                    break
                }
                
                let range = NSRange(location: start, length: idx - start)
                highlights.append((range, isKey ? keyColor : stringColor))
                continue
            }
            
            // Check for Number (- or 0-9)
            // - (45), 0-9 (48-57)
            if c == 45 || (c >= 48 && c <= 57) {
                let start = idx
                idx += 1
                while idx < len {
                    let nc = nsString.character(at: idx)
                    // 0-9, ., +, -, e, E
                    if (nc >= 48 && nc <= 57) || nc == 46 || nc == 43 || nc == 45 || nc == 69 || nc == 101 {
                        idx += 1
                    } else {
                        break
                    }
                }
                let range = NSRange(location: start, length: idx - start)
                highlights.append((range, numberColor))
                continue
            }
            
            // Check for true (116), false (102), null (110)
            if c == 116 { // t
                if idx + 3 < len && nsString.character(at: idx+1) == 114 && nsString.character(at: idx+2) == 117 && nsString.character(at: idx+3) == 101 {
                    highlights.append((NSRange(location: idx, length: 4), boolColor))
                    idx += 4
                    continue
                }
            } else if c == 102 { // f
                if idx + 4 < len && nsString.character(at: idx+1) == 97 && nsString.character(at: idx+2) == 108 && nsString.character(at: idx+3) == 115 && nsString.character(at: idx+4) == 101 {
                     highlights.append((NSRange(location: idx, length: 5), boolColor))
                     idx += 5
                     continue
                }
            } else if c == 110 { // n
                if idx + 3 < len && nsString.character(at: idx+1) == 117 && nsString.character(at: idx+2) == 108 && nsString.character(at: idx+3) == 108 {
                     highlights.append((NSRange(location: idx, length: 4), boolColor))
                     idx += 4
                     continue
                }
            }
            
            idx += 1
        }
        
        return highlights
    }
}

// MARK: - Legacy Compatibility

/// JSON formatter service
final class JSONFormatter {
    static let shared = JSONFormatter()
    private init() {}

    /// 美化 JSON 文本。非法 JSON（含空输入）返回 nil，不抛错。
    /// - Parameters:
    ///   - text: 原始 JSON 文本
    ///   - indent: 缩进空格数（2 或 4）
    ///   - sortKeys: 是否按 Key 字母序排序
    static func format(_ text: String, indent: Int = 2, sortKeys: Bool = false) -> String? {
        guard JSONValidator.firstError(in: text) == nil else { return nil }
        guard let data = text.data(using: .utf8),
              let node = IndexedJSONNode.fromData(data, shouldSortKeys: sortKeys) else { return nil }
        return node.prettyJSONString(indentation: indent)
    }
}
