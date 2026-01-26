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
    
    /// 从 JSON 字符串创建解析错误
    func parseError(from jsonString: String) -> ParseError? {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParseError(
                message: Constants.ErrorMessages.emptyInput,
                line: 1,
                column: 1,
                offset: 0
            )
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return ParseError(
                message: "无法将 JSON 转换为 UTF-8 数据",
                line: 1,
                column: 1,
                offset: 0
            )
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return nil // 解析成功，没有错误
        } catch let error as NSError {
            return self.error(from: error, jsonString: jsonString)
        }
    }

    // MARK: - Private Helpers

    private func error(from error: Error, jsonString: String) -> ParseError {
        guard let nsError = error as NSError? else {
            return ParseError(
                message: Constants.ErrorMessages.invalidJSON,
                line: 1,
                column: 1,
                offset: 0
            )
        }

        var line = 1
        let column = 1
        var offset = 0
        var message = Constants.ErrorMessages.invalidJSON

        if let debugDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
            message = debugDescription

            if let range = debugDescription.range(of: #"line (\d+)"#, options: .regularExpression) {
                let lineStr = debugDescription[range].replacingOccurrences(of: #"[^0-9]"#, with: "", options: .regularExpression)
                if let lineNum = Int(lineStr) {
                    line = lineNum
                }
            }
        }

        let lines = jsonString.components(separatedBy: "\n")
        var currentOffset = 0
        for i in 0..<min(line - 1, lines.count) {
            currentOffset += lines[i].utf16.count + 1
        }
        offset = currentOffset

        let contextStart = max(0, offset - 20)
        let contextEnd = min(jsonString.utf16.count, offset + 20)
        if contextStart < contextEnd && contextEnd <= jsonString.utf16.count {
            let startIndex = jsonString.index(jsonString.startIndex, offsetBy: contextStart)
            let endIndex = jsonString.index(jsonString.startIndex, offsetBy: contextEnd)
            let context = String(jsonString[startIndex..<endIndex])
            
            return ParseError(
                message: message,
                line: line,
                column: column,
                offset: offset,
                context: context
            )
        }

        return ParseError(
            message: message,
            line: line,
            column: column,
            offset: offset
        )
    }
}
