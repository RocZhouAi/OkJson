//  JSONParser.swift
//  OkJson
//
//  JSON parsing service - simplified for AppKit version

import Foundation

/// JSON parsing service with validation
final class JSONParser {
    // MARK: - Singleton

    static let shared = JSONParser()

    private init() {}

    // MARK: - Validate Method

    /// Quick validation without building full tree
    /// - Parameter jsonString: The JSON text to validate
    /// - Returns: true if valid JSON, false otherwise
    func validate(_ jsonString: String) -> Bool {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard trimmed.looksLikeJSON else { return false }

        guard let data = jsonString.data(using: .utf8) else { return false }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Error Parsing

    /// 从 JSON 字符串创建解析错误（基于自研 JSONValidator，精确到行列 + 分类）
    /// - Returns: 合法 JSON 返回 nil；否则返回首个错误的精确位置与分类
    func parseError(from jsonString: String) -> ParseError? {
        guard let synErr = JSONValidator.firstError(in: jsonString) else { return nil }
        let converter = LineColumnConverter(text: jsonString)
        let (line, column) = converter.lineColumn(at: synErr.utf16Offset)
        return ParseError(
            message: synErr.category.localizedMessage,
            line: line,
            column: column,
            offset: synErr.utf16Offset,
            category: synErr.category
        )
    }
}
