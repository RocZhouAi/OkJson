//  JSONParser.swift
//  OkJson
//
//  JSON parsing service with error handling
//

import Foundation

/// JSON parsing service with detailed error reporting
final class JSONParser {
    // MARK: - Singleton

    static let shared = JSONParser()

    private init() {}

    // MARK: - Parse Method

    /// Parse JSON string into a tree of JSONNode
    /// - Parameter jsonString: The raw JSON text to parse
    /// - Returns: Result with root JSONNode or ParseError
    func parse(_ jsonString: String) -> Result<JSONNode, ParseError> {
        // Check for empty input
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(ParseError(
                message: Constants.ErrorMessages.emptyInput,
                line: 1,
                column: 1,
                offset: 0
            ))
        }

        // Use Foundation's JSONSerialization
        let data = jsonString.data(using: .utf8)!

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let rootNode = buildNode(from: jsonObject, key: nil, path: "$", depth: 0)
            return .success(rootNode)
        } catch let error as NSError {
            // Extract error location
            let parseError = self.error(from: error, jsonString: jsonString)
            return .failure(parseError)
        }
    }

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

    // MARK: - Get Node at Path

    /// Retrieve a node at a specific JSONPath
    /// - Parameters:
    ///   - path: JSONPath expression (e.g., "$.users[0].name")
    ///   - root: Root node to search from
    /// - Returns: The node if found, nil otherwise
    func getNode(atPath path: String, from root: JSONNode) -> JSONNode? {
        if path == "$" || path == "." {
            return root
        }

        let components = pathComponents(from: path)
        var currentNode: JSONNode? = root

        for component in components {
            guard let node = currentNode else { return nil }

            switch component {
            case .key(let key):
                currentNode = node.children.first { $0.key == key }
            case .index(let index):
                if index < node.children.count {
                    currentNode = node.children[index]
                } else {
                    return nil
                }
            }
        }

        return currentNode
    }

    // MARK: - Private Helpers

    private func buildNode(from value: Any, key: String?, path: String, depth: Int) -> JSONNode {
        var nodeType: NodeType
        var nodeChildren: [JSONNode] = []
        var nodeValue: Any?

        switch value {
        case let dict as [String: Any]:
            nodeType = .object
            nodeChildren = dict.sorted { $0.key < $1.key }.map { (key, value) in
                let childPath = "\(path).\(escapeKey(key))"
                return buildNode(from: value, key: key, path: childPath, depth: depth + 1)
            }

        case let array as [Any]:
            nodeType = .array
            nodeChildren = array.enumerated().map { (index, value) in
                let childPath = "\(path)[\(index)]"
                return buildNode(from: value, key: nil, path: childPath, depth: depth + 1)
            }

        case let string as String:
            nodeType = .string
            nodeValue = string

        case let bool as Bool:
            nodeType = .boolean
            nodeValue = bool

        case is NSNull:
            nodeType = .null
            nodeValue = nil

        case let number as NSNumber:
            // NSNumber is what JSONSerialization returns for all numeric types
            nodeType = .number
            // Use the actual value - check if it's boolean-like (JSONSerialization can return 0/1 as BOOL)
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                nodeType = .boolean
                nodeValue = number.boolValue
            } else {
                // Store as Double for all numbers to unify handling
                nodeValue = number.doubleValue
            }

        default:
            // Fallback for unknown types
            nodeType = .string
            nodeValue = String(describing: value)
        }

        return JSONNode(
            type: nodeType,
            key: key,
            value: nodeValue,
            children: nodeChildren,
            depth: depth,
            path: path
        )
    }

    private func escapeKey(_ key: String) -> String {
        // Escape dots and brackets in keys for JSONPath
        key
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private enum PathComponent {
        case key(String)
        case index(Int)
    }

    private func pathComponents(from path: String) -> [PathComponent] {
        var components: [PathComponent] = []
        var current = path

        // Remove root prefix
        if current.hasPrefix("$") {
            current = String(current.dropFirst())
        }

        // Parse remaining path
        while !current.isEmpty {
            if current.hasPrefix(".") {
                current = String(current.dropFirst())
                if let dotIndex = current.firstIndex(of: ".") ?? current.firstIndex(of: "[") {
                    let key = String(current[..<dotIndex])
                    components.append(.key(key))
                    current = String(current[dotIndex...])
                } else {
                    components.append(.key(current))
                    break
                }
            } else if current.hasPrefix("[") {
                current = String(current.dropFirst())
                if let bracketEnd = current.firstIndex(of: "]") {
                    let indexStr = String(current[..<bracketEnd])
                    if let index = Int(indexStr) {
                        components.append(.index(index))
                    }
                    current = String(current[bracketEnd...].dropFirst())
                } else {
                    break
                }
            } else {
                break
            }
        }

        return components
    }

    private func error(from error: Error, jsonString: String) -> ParseError {
        guard let nsError = error as NSError? else {
            return ParseError(
                message: Constants.ErrorMessages.invalidJSON,
                line: 1,
                column: 1,
                offset: 0
            )
        }

        // Try to extract line and column from error
        var line = 1
        let column = 1
        var offset = 0
        var message = Constants.ErrorMessages.invalidJSON

        // Common JSON error patterns
        if let debugDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
            message = debugDescription

            // Parse line/column from error message if available
            if let range = debugDescription.range(of: #"line (\d+)"#, options: .regularExpression) {
                let lineStr = debugDescription[range].replacingOccurrences(of: #"[^0-9]"#, with: "", options: .regularExpression)
                if let lineNum = Int(lineStr) {
                    line = lineNum
                }
            }
        }

        // Calculate offset from line number
        let lines = jsonString.components(separatedBy: "\n")
        var currentOffset = 0
        for i in 0..<min(line - 1, lines.count) {
            currentOffset += lines[i].utf16.count + 1 // +1 for newline
        }
        offset = currentOffset

        // Extract context around error
        let contextStart = max(0, offset - 20)
        let contextEnd = min(jsonString.utf16.count, offset + 20)
        let contextRange = jsonString.index(jsonString.startIndex, offsetBy: contextStart)..<jsonString.index(jsonString.startIndex, offsetBy: contextEnd)
        let context = String(jsonString[contextRange])

        return ParseError(
            message: message,
            line: line,
            column: column,
            offset: offset,
            context: context
        )
    }
}
