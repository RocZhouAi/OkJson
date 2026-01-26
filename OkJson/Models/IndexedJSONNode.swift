//  IndexedJSONNode.swift
//  OkJson
//
//  基于索引的轻量级 JSON 节点 - 不保存解析值，按需从原始字符串读取
//

import Foundation

/// 基于索引的轻量级 JSON 节点
final class IndexedJSONNode {
    // MARK: - Properties
    
    /// 节点类型
    let type: NodeType
    
    /// 属性键名（nil 表示根节点或数组元素）
    let key: String?
    
    /// 在原始 JSON 字符串中的起始位置
    let startIndex: String.Index
    
    /// 在原始 JSON 字符串中的结束位置
    let endIndex: String.Index
    
    /// 嵌套深度
    let depth: Int
    
    /// JSONPath 路径
    let path: String
    
    /// 对原始 JSON 字符串的弱引用（通过闭包）
    private let jsonStringProvider: () -> String
    
    /// 缓存的子节点信息（只存索引，不存值）
    private var _childrenIndices: [(key: String?, start: String.Index, end: String.Index, type: NodeType)]?
    
    /// 缓存的子节点对象，确保同一索引返回相同实例（保留状态）
    private var _cachedChildrenNodes: [Int: IndexedJSONNode] = [:]
    
    /// 下一次扫描的起始位置（用于分页加载）
    private var nextScanIndex: String.Index?
    
    /// 是否已加载完所有子节点
    var isFullyLoaded: Bool {
        return nextScanIndex == nil
    }
    
    /// 是否需要对 Key 进行排序
    let shouldSortKeys: Bool
    
    // MARK: - Computed Properties
    
    /// 获取原始 JSON 字符串
    private var jsonString: String {
        jsonStringProvider()
    }
    
    /// 获取当前节点的原始 JSON 字符串片段
    var rawString: String {
        String(jsonString[startIndex..<endIndex])
    }
    
    /// 子节点数量
    var childCount: Int {
        if !type.isContainer { return 0 }
        return childrenIndices.count
    }
    
    /// 是否有子节点
    var hasChildren: Bool {
        type.isContainer && childCount > 0
    }
    
    /// 子节点索引信息（延迟解析）
    private var childrenIndices: [(key: String?, start: String.Index, end: String.Index, type: NodeType)] {
        if _childrenIndices == nil {
            if shouldSortKeys {
                loadMore(count: Int.max)
            } else {
                loadMore(count: 1000)
            }
        }
        return _childrenIndices ?? []
    }
    
    /// 是否还有更多子节点可加载
    var hasMoreChildren: Bool {
        guard type.isContainer else { return false }
        // 确保已初始化
        if _childrenIndices == nil {
            _ = childrenIndices
        }
        return !isFullyLoaded
    }
    
    /// 显示值（从原始字符串按需读取）
    var displayValue: String {
        switch type {
        case .object:
            return childCount == 0 ? "{}" : ""
        case .array:
            return childCount == 0 ? "[]" : ""
        case .string:
            // Scroll Optimization: Return raw string (including quotes) directly
            // Avoids expensive unescaping during scroll
            return rawString
        case .number, .boolean, .null:
            // Scroll Optimization: Return raw string directly
            // Avoids trimming overhead
            // The parser ensures the range is correct (excludes delimiters)
            return rawString
        }
    }
    
    /// 原始值（仅用于基本类型）
    var value: Any? {
        switch type {
        case .string:
            return extractStringValue()
        case .number:
            let content = String(jsonString[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            if content.contains(".") {
                return Double(content)
            }
            return Int(content)
        case .boolean:
            let content = String(jsonString[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            return content == "true"
        case .null:
            return nil
        case .object, .array:
            return nil
        }
    }
    
    // MARK: - Initialization
    
    init(
        type: NodeType,
        key: String?,
        startIndex: String.Index,
        endIndex: String.Index,
        depth: Int,
        path: String,
        shouldSortKeys: Bool,
        jsonStringProvider: @escaping () -> String
    ) {
        self.type = type
        self.key = key
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.depth = depth
        self.path = path
        self.shouldSortKeys = shouldSortKeys
        self.jsonStringProvider = jsonStringProvider
    }
    
    // MARK: - 子节点访问
    
    /// 获取指定索引的子节点
    func child(at index: Int) -> IndexedJSONNode? {
        guard index >= 0 && index < childrenIndices.count else { return nil }
        
        // 检查缓存
        if let cachedNode = _cachedChildrenNodes[index] {
            return cachedNode
        }
        
        let info = childrenIndices[index]
        let childPath: String
        if let key = info.key {
            childPath = "\(path).\(escapeKey(key))"
        } else {
            childPath = "\(path)[\(index)]"
        }
        
        let node = IndexedJSONNode(
            type: info.type,
            key: info.key,
            startIndex: info.start,
            endIndex: info.end,
            depth: depth + 1,
            path: childPath,
            shouldSortKeys: shouldSortKeys,
            jsonStringProvider: jsonStringProvider
        )
        
        // 存入缓存
        _cachedChildrenNodes[index] = node
        return node
    }
    
    // MARK: - Private Methods
    
    /// 加载更多子节点
    /// - Parameter count: 加载数量
    /// - Returns: 新加载的子节点数量
    @discardableResult
    func loadMore(count: Int = 1000) -> Int {
        guard type.isContainer else { return 0 }
        
        // 初始化缓存
        if _childrenIndices == nil {
            _childrenIndices = []
            // 跳过 '{' 或 '['
            nextScanIndex = jsonString.index(after: startIndex)
        }
        
        guard let startScan = nextScanIndex, startScan < endIndex else {
            nextScanIndex = nil
            return 0
        }
        
        let json = jsonString
        var i = startScan
        var loadedCount = 0
        
        while i < endIndex && loadedCount < count {
            // 跳过空白
            i = skipWhitespace(from: i, in: json)
            guard i < endIndex else { break }
            
            let char = json[i]
            
            // 检查结束
            if char == "}" || char == "]" {
                nextScanIndex = nil // 标记为已完全加载
                
                // Sort keys if needed
                if shouldSortKeys && type == .object {
                    _childrenIndices?.sort { (node1, node2) -> Bool in
                        guard let key1 = node1.key, let key2 = node2.key else { return false }
                        return key1.localizedCompare(key2) == .orderedAscending
                    }
                }
                
                return loadedCount
            }
            
            // 跳过逗号
            if char == "," {
                i = json.index(after: i)
                continue
            }
            
            // 解析键（对于 object）
            var key: String? = nil
            if type == .object && char == "\"" {
                let (parsedKey, nextIndex) = parseString(from: i, in: json)
                key = parsedKey
                i = nextIndex
                
                // 跳过冒号
                i = skipWhitespace(from: i, in: json)
                if i < endIndex && json[i] == ":" {
                    i = json.index(after: i)
                }
                i = skipWhitespace(from: i, in: json)
            }
            
            // 解析值的范围
            guard i < endIndex else { break }
            let (valueStart, valueEnd, valueType) = parseValueRange(from: i, in: json)
            
            _childrenIndices?.append((key: key, start: valueStart, end: valueEnd, type: valueType))
            loadedCount += 1
            i = valueEnd
        }
        
        // 只有当真正扫描完所有内容（遇到结束符）时才置为 nil，
        // 这里只是暂停扫描，记录当前位置
        nextScanIndex = i
        
        // 再次检查是否已经到达末尾（优化：如果刚好读完最后一个元素）
        let checkEnd = skipWhitespace(from: i, in: json)
        if checkEnd < endIndex {
            let endChar = json[checkEnd]
            if endChar == "}" || endChar == "]" {
                nextScanIndex = nil
                
                // Sort keys if needed
                if shouldSortKeys && type == .object {
                    _childrenIndices?.sort { (node1, node2) -> Bool in
                        guard let key1 = node1.key, let key2 = node2.key else { return false }
                        return key1.localizedCompare(key2) == .orderedAscending
                    }
                }
            }
        }
        
        return loadedCount
    }
    
    /// 解析值的范围（不解析具体值）
    private func parseValueRange(from start: String.Index, in json: String) -> (start: String.Index, end: String.Index, type: NodeType) {
        let char = json[start]
        
        switch char {
        case "{":
            let end = findMatchingBrace(from: start, open: "{", close: "}", in: json)
            return (start, end, .object)
            
        case "[":
            let end = findMatchingBrace(from: start, open: "[", close: "]", in: json)
            return (start, end, .array)
            
        case "\"":
            var i = json.index(after: start)
            while i < json.endIndex {
                if json[i] == "\\" {
                    i = json.index(after: i)
                    if i < json.endIndex {
                        i = json.index(after: i)
                    }
                    continue
                }
                if json[i] == "\"" {
                    return (start, json.index(after: i), .string)
                }
                i = json.index(after: i)
            }
            return (start, json.endIndex, .string)
            
        case "t", "f":
            // true or false
            let word = char == "t" ? "true" : "false"
            let end = json.index(start, offsetBy: word.count, limitedBy: json.endIndex) ?? json.endIndex
            return (start, end, .boolean)
            
        case "n":
            // null
            let end = json.index(start, offsetBy: 4, limitedBy: json.endIndex) ?? json.endIndex
            return (start, end, .null)
            
        default:
            // number
            var i = start
            while i < json.endIndex {
                let c = json[i]
                if c == "," || c == "}" || c == "]" || c.isWhitespace {
                    break
                }
                i = json.index(after: i)
            }
            return (start, i, .number)
        }
    }
    
    /// 查找匹配的括号
    private func findMatchingBrace(from start: String.Index, open: Character, close: Character, in json: String) -> String.Index {
        var depth = 0
        var i = start
        var inString = false
        
        while i < json.endIndex {
            let char = json[i]
            
            if inString {
                if char == "\\" {
                    i = json.index(after: i)
                    if i < json.endIndex {
                        i = json.index(after: i)
                    }
                    continue
                }
                if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == open {
                    depth += 1
                } else if char == close {
                    depth -= 1
                    if depth == 0 {
                        return json.index(after: i)
                    }
                }
            }
            i = json.index(after: i)
        }
        return json.endIndex
    }
    
    /// 跳过空白字符
    private func skipWhitespace(from start: String.Index, in json: String) -> String.Index {
        var i = start
        while i < json.endIndex && json[i].isWhitespace {
            i = json.index(after: i)
        }
        return i
    }
    
    /// 解析字符串并返回内容和结束位置
    private func parseString(from start: String.Index, in json: String) -> (String, String.Index) {
        let onePastStart = json.index(after: start)
        var current = onePastStart
        var hasEscape = false
        
        // Fast Path: 快速扫描，寻找结束引号或转义符
        while current < json.endIndex {
            let char = json[current]
            if char == "\"" {
                // 找到结束引号
                if !hasEscape {
                    // 完美路径：没有转义符，直接截取子串
                    // String(Substring) 比逐个字符 append 快得多 (memcpy vs loop)
                    let content = String(json[onePastStart..<current])
                    return (content, json.index(after: current))
                }
                break // 转义情况交给慢速路径处理（虽然理论上不会进这里，除非逻辑修改）
            }
            
            if char == "\\" {
                hasEscape = true
                break // 发现转义，中止快速扫描，转入慢速路径
            }
            
            current = json.index(after: current)
        }
        
        // Slow Path: 包含转义符，或者快速扫描中断
        var result = ""
        // 如果是从 fast path 中断回来的，我们可以先复用已经扫描过的部分优化吗？
        // 为了代码简单稳健，我们只是把 fast path 用于无转义的常见情况。
        // 有转义时回退到原始位置重新解析（有转义的情况相对少，且一般 key 较短，回退开销可忽略）
        
        var i = onePastStart
        if hasEscape {
            // 预先 append 之前确认安全的部分？不，直接重头来最安全
        }
        
        while i < json.endIndex {
            let char = json[i]
            
            if char == "\\" {
                i = json.index(after: i)
                if i < json.endIndex {
                    let escaped = json[i]
                    switch escaped {
                    case "n": result.append("\n")
                    case "r": result.append("\r")
                    case "t": result.append("\t")
                    case "\"": result.append("\"")
                    case "\\": result.append("\\")
                    case "b": result.append("\u{08}") // backspace
                    case "f": result.append("\u{0C}") // form feed
                    case "/": result.append("/")      // solidus
                    case "u":
                        // 解析 unicode: \uXXXX
                        // 简单处理：向后读4位 (为保持极简，这里暂略复杂边界检查，假设 JSON 合法)
                        let endHex = json.index(i, offsetBy: 5, limitedBy: json.endIndex) ?? json.endIndex
                        if endHex > json.index(after: i) {
                            let hexStart = json.index(after: i)
                            let hexStr = json[hexStart..<endHex]
                            if hexStr.count == 4, let codePoint = UInt32(hexStr, radix: 16), let scalar = UnicodeScalar(codePoint) {
                                result.append(String(scalar))
                                i = json.index(i, offsetBy: 4)
                            } else {
                                result.append("\\u") // 解析失败原样保留
                            }
                        } else {
                             result.append("\\u")
                        }
                    default: result.append(escaped)
                    }
                }
            } else if char == "\"" {
                return (result, json.index(after: i))
            } else {
                result.append(char)
            }
            i = json.index(after: i)
        }
        
        return (result, json.endIndex)
    }
    
    /// 提取字符串值
    private func extractStringValue() -> String? {
        let (value, _) = parseString(from: startIndex, in: jsonString)
        return value
    }
    
    private func escapeKey(_ key: String) -> String {
        key
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}

// MARK: - 从 JSON 字符串创建根节点

extension IndexedJSONNode {
    /// 从 JSON 字符串创建根节点
    static func fromJSONString(_ jsonString: String, shouldSortKeys: Bool = false) -> IndexedJSONNode? {
        let json = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !json.isEmpty else { return nil }
        
        let firstChar = json[json.startIndex]
        let type: NodeType
        
        switch firstChar {
        case "{": type = .object
        case "[": type = .array
        case "\"": type = .string
        case "t", "f": type = .boolean
        case "n": type = .null
        default: type = .number
        }
        
        // 使用闭包捕获字符串，避免复制
        let capturedString = jsonString
        
        return IndexedJSONNode(
            type: type,
            key: nil,
            startIndex: json.startIndex,
            endIndex: json.endIndex,
            depth: 0,
            path: "$",
            shouldSortKeys: shouldSortKeys,
            jsonStringProvider: { capturedString }
        )
    }
}

// MARK: - JSON Formatting

extension IndexedJSONNode {
    /// 生成格式化的 JSON 字符串
    /// - Parameters:
    ///   - indentation: 缩进空格数
    ///   - currentIndent: 当前缩进级别（内部递归使用）
    /// - Returns: 格式化后的 JSON 字符串
    func prettyJSONString(indentation: Int = 2) -> String {
        // 预估大小：原始大小 * 1.5 (格式化后的空格和换行)
        let estimatedCapacity = Int(Double(jsonString.count) * 1.5)
        var buffer = ""
        buffer.reserveCapacity(estimatedCapacity)
        
        writePrettyJSON(to: &buffer, indentation: indentation, currentIndent: 0)
        
        return buffer
    }
    
    /// 将格式化的 JSON 写入缓冲区
    /// - Parameters:
    ///   - buffer: 目标字符串缓冲区
    ///   - indentation: 缩进空格数
    ///   - currentIndent: 当前缩进级别
    func writePrettyJSON(to buffer: inout String, indentation: Int, currentIndent: Int) {
        switch type {
        case .object:
            // 确保加载所有子节点以进行排序（如果需要）
            loadMore(count: Int.max)
            
            if childCount == 0 {
                buffer.append("{}")
                return
            }
            
            buffer.append("{\n")
            let nextIndent = currentIndent + indentation
            let indentString = String(repeating: " ", count: nextIndent)
            let closingIndentString = String(repeating: " ", count: currentIndent)
            
            let indices = childrenIndices
            let count = indices.count
            
            for (index, childInfo) in indices.enumerated() {
                // key 必须存在于 object 中
                guard let key = childInfo.key else { continue }
                
                buffer.append(indentString)
                // 使用 debugDescription 来自动处理转义和引号
                buffer.append(key.debugDescription)
                buffer.append(": ")
                
                // 获取子节点（利用缓存）
                if let childNode = child(at: index) {
                    childNode.writePrettyJSON(to: &buffer, indentation: indentation, currentIndent: nextIndent)
                } else {
                    buffer.append("null")
                }
                
                if index < count - 1 {
                    buffer.append(",\n")
                } else {
                    buffer.append("\n")
                }
            }
            
            buffer.append(closingIndentString)
            buffer.append("}")
            
        case .array:
            // 确保加载所有子节点
            loadMore(count: Int.max)
            
            if childCount == 0 {
                buffer.append("[]")
                return
            }
            
            buffer.append("[\n")
            let nextIndent = currentIndent + indentation
            let indentString = String(repeating: " ", count: nextIndent)
            let closingIndentString = String(repeating: " ", count: currentIndent)
            
            let count = childCount
            for index in 0..<count {
                buffer.append(indentString)
                
                if let childNode = child(at: index) {
                    childNode.writePrettyJSON(to: &buffer, indentation: indentation, currentIndent: nextIndent)
                } else {
                   buffer.append("null")
                }
                
                if index < count - 1 {
                    buffer.append(",\n")
                } else {
                    buffer.append("\n")
                }
            }
            
            buffer.append(closingIndentString)
            buffer.append("]")
            
        default:
             // string, number, boolean, null -> 直接复用原始 rawString
             buffer.append(rawString.trimmingCharacters(in: .whitespaces))
        }
    }
}
