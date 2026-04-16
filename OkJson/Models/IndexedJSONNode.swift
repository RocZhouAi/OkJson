//  IndexedJSONNode.swift
//  OkJson
//
//  基于索引的轻量级 JSON 节点 (极致性能版)
//  - 移除所有 String 存储 (Key, Path)
//  - 零拷贝访问 Key 和 Value
//  - 基于 Byte 的快速扫描
//

import Foundation

/// 共享的 Data 持有者，避免每个节点持有独立闭包
private final class DataHolder {
    let data: Data
    init(_ data: Data) { self.data = data }
}

/// 基于索引的轻量级 JSON 节点
final class IndexedJSONNode {
    // MARK: - Properties

    /// 节点类型 (1 Byte)
    let type: NodeType

    // 移除 key: String，改为偏移量
    // 根节点/数组元素 keyStartOffset = -1
    private let keyStartOffset: Int
    private let keyEndOffset: Int
    
    /// 用于删除操作：完整的起始位置（包含 key 的引号）
    /// 如果是对象的值节点，返回 key 引号前一个字节的位置；
    /// 如果是数组元素或根节点，返回 startOffset
    var fullStartOffset: Int {
        // keyStartOffset 是 key 内容的起始，我们需要包含引号
        // 所以 fullStart = keyStartOffset - 1 (引号位置)
        if keyStartOffset >= 1 {
            return keyStartOffset - 1
        }
        return startOffset
    }

    /// Key 内容在原始数据中的字节范围（不含引号），用于编辑 Key
    var keyByteRange: (start: Int, end: Int)? {
        guard keyStartOffset >= 0 else { return nil }
        return (keyStartOffset, keyEndOffset)
    }

    /// Value 在原始数据中的字节范围，用于编辑 Value
    var valueByteRange: (start: Int, end: Int) {
        return (startOffset, endOffset)
    }
    
    /// 在原始 JSON Data 中的起始字节偏移
    let startOffset: Int
    
    /// 在原始 JSON Data 中的结束字节偏移
    let endOffset: Int
    
    /// 嵌套深度
    let depth: Int
    
    // 移除 path: String，改为计算属性或仅在 diff 时传递
    // path 占用了对大量内存，对于仅查看来说是浪费
    // 只有在 diff/delete 时需要 path
    // 我们可以添加一个 debugPath 计算属性用于调试，或者在 traverse 时构建 path
    
    /// 共享数据持有者（替代闭包，消除堆分配开销）
    private let dataHolder: DataHolder
    
    /// 缓存的子节点索引信息
    // 优化：使用 Struct 减少内存
    private struct ChildInfo {
        let keyStart: Int
        let keyEnd: Int
        let start: Int
        let end: Int
        let type: NodeType
    }
    
    private var _childrenInfo: [ChildInfo]?
    
    /// 缓存的子节点对象（数组替代字典，连续索引直接访问）
    private var _cachedChildrenNodes: [IndexedJSONNode?] = []
    
    /// 下一次扫描的起始字节偏移
    private var nextScanOffset: Int?
    
    /// 是否已加载完所有子节点
    var isFullyLoaded: Bool {
        return nextScanOffset == nil
    }
    
    /// 是否需要对 Key 进行排序
    let shouldSortKeys: Bool
    
    // MARK: - Computed Properties
    
    /// 获取原始 JSON Data
    internal var jsonData: Data {
        dataHolder.data
    }
    
    /// Key (按需解码)
    var key: String? {
        if keyStartOffset < 0 { return nil }
        
        let data = jsonData
        // 范围检查
        guard keyStartOffset < data.count, keyEndOffset <= data.count, keyStartOffset < keyEndOffset else {
             return nil
        }
        
        // keyStartOffset 指向引号内的内容（或者包含引号？）
        // 解析器存储的是包含引号的范围吗？通常 key 是 "foo"
        // 我们的解析器返回的是 start/end。
        // 为了性能，我们假设存储的是包含引号的范围，或者不包含？
        // 从解析逻辑看，parser 返回的是 *value* range.
        // wait, childInfo stores key range?
        // Let's check init.
        
        // 我们需要约定：keyStartOffset / keyEndOffset 是去除引号后的吗？
        // 下面解析逻辑中，parseString 返回的是 unescaped string AND next index.
        // 为了零拷贝，我们需要原始 range.
        // 修改 parser: parseStringRawRange -> (start, end) around content.
        
        // 这里假设是原始字节范围 (不含引号)
        // 但如果包含转义符，直接 UTF8 decode 可能会有 '\\'
        // 对于 key，绝大多数情况没有转义。
        // 我们先做简单解码。
        let subData = data[keyStartOffset..<keyEndOffset]
        
        // Fallback unescape if needed
        // 为了极致性能，先尝试直接 string，如果有 \ 再处理
        // 或者直接 string，显示时 key 稍微带个转义也行（如 key 里面有换行 debugDescription 会处理）
        // 此时我们只是为了 UI 显示。
        
        // 使用 String(decoding: as: UTF8) 非常快
        // 但是对于转义字符，比如 "a\nb"，raw bytes 是 97, 92, 110, 98
        // String decoding 得到 "a\\nb"
        // 这对于 key 展示通常是可以接受的，或者 UI 层处理。
        // 但标准 JSON parser 会 unescape。
        // 可以在这里做 unescape。
        
        // 但为了 "Extreme"，我们希望 UI 列表里直接显示 raw key 也可以。
        // 真的需要 unescape 吗？
        // "foo": 1
        // Key is foo.
        // "foo\nbar": 1
        // Key is foo<newline>bar.
        // UI 显示 "foo\nbar" 也是对的。
        
        return String(decoding: subData, as: UTF8.self)
    }
    
    /// 路径 (计算属性，性能开销大，谨慎使用)
    /// 因为移除了 parent 指针和 stored path，无法直接获取 path
    /// 如果业务层依赖 path，需要在遍历时传递。
    /// 目前只有 deleteNode 和 Diff 需要 path。
    /// 我们修改 API：node.path 移除。依赖 context。
    // var path: String { ... } // Removed
    
    /// 获取当前节点的原始 JSON 字符串片段
    var rawString: String {
        let data = jsonData
        let safeStart = max(0, min(startOffset, data.count))
        let safeEnd = max(safeStart, min(endOffset, data.count))
        let subData = data[safeStart..<safeEnd]
        return String(decoding: subData, as: UTF8.self)
    }
    
    /// 子节点数量
    var childCount: Int {
        if !type.isContainer { return 0 }
        return childrenInfo.count
    }
    
    /// 是否有子节点
    var hasChildren: Bool {
        type.isContainer && childCount > 0
    }
    
    /// 子节点索引信息（延迟解析）
    private var childrenInfo: [ChildInfo] {
        if _childrenInfo == nil {
            if shouldSortKeys {
                loadMore(count: Int.max)
            } else {
                loadMore(count: 1000)
            }
        }
        return _childrenInfo ?? []
    }
    
    /// 是否还有更多子节点可加载
    var hasMoreChildren: Bool {
        guard type.isContainer else { return false }
        if _childrenInfo == nil {
             _ = childrenInfo
        }
        return !isFullyLoaded
    }
    
    /// 显示值（完整）
    var displayValue: String {
        switch type {
        case .object:
            return childCount == 0 ? "{}" : ""
        case .array:
            return childCount == 0 ? "[]" : ""
        case .string, .number, .boolean, .null:
            return rawString
        }
    }

    /// 值的字节大小
    var valueByteSize: Int {
        return endOffset - startOffset
    }

    /// 格式化的大小文本（如 "1.2 KB"、"3.5 MB"）
    var formattedSize: String {
        let size = valueByteSize
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }

    /// 值是否被截断显示
    var isTruncated: Bool {
        guard type == .string || type == .number else { return false }
        return valueByteSize > Constants.valueTruncationThreshold
    }

    /// 截断后的显示值（树视图使用）
    var truncatedDisplayValue: String {
        switch type {
        case .object:
            return childCount == 0 ? "{}" : ""
        case .array:
            return childCount == 0 ? "[]" : ""
        case .string, .number:
            let raw = rawString
            if raw.count <= Constants.valueTruncationThreshold {
                return raw
            }
            let prefix = raw.prefix(Constants.truncationPrefixLength)
            let suffix = raw.suffix(Constants.truncationSuffixLength)
            return "\(prefix)...\(suffix) (\(formattedSize))"
        case .boolean, .null:
            return rawString
        }
    }
    
    /// 原始值（仅用于基本类型）
    var value: Any? {
        switch type {
        case .string:
            // String needs unescape
            let s = rawString
            // Remove quotes
            if s.count >= 2 && s.first == "\"" && s.last == "\"" {
                 let content = s.dropFirst().dropLast()
                 // Simple unescape
                 return String(content).simpleUnescape()
            }
            return s
        case .number:
            let str = rawString.trimmingCharacters(in: .whitespaces)
            if str.contains(".") {
                return Double(str)
            }
            return Int(str)
        case .boolean:
            return rawString.trimmingCharacters(in: .whitespaces) == "true"
        case .null:
            return nil
        default:
            return nil
        }
    }
    
    // MARK: - Initialization

    fileprivate init(
        type: NodeType,
        keyStart: Int,
        keyEnd: Int,
        startOffset: Int,
        endOffset: Int,
        depth: Int,
        shouldSortKeys: Bool,
        dataHolder: DataHolder
    ) {
        self.type = type
        self.keyStartOffset = keyStart
        self.keyEndOffset = keyEnd
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.depth = depth
        self.shouldSortKeys = shouldSortKeys
        self.dataHolder = dataHolder
    }
    
    // MARK: - 子节点访问
    
    func child(at index: Int) -> IndexedJSONNode? {
        guard index >= 0 && index < childrenInfo.count else { return nil }

        // 延迟初始化数组到正确大小
        if _cachedChildrenNodes.count < childrenInfo.count {
            _cachedChildrenNodes = [IndexedJSONNode?](repeating: nil, count: childrenInfo.count)
        }

        if let cachedNode = _cachedChildrenNodes[index] {
            return cachedNode
        }

        let info = childrenInfo[index]

        let node = IndexedJSONNode(
            type: info.type,
            keyStart: info.keyStart,
            keyEnd: info.keyEnd,
            startOffset: info.start,
            endOffset: info.end,
            depth: depth + 1,
            shouldSortKeys: shouldSortKeys,
            dataHolder: dataHolder
        )

        _cachedChildrenNodes[index] = node
        return node
    }
    
    // MARK: - Parsing Engine
    
    @discardableResult
    func loadMore(count: Int = 1000) -> Int {
        guard type.isContainer else { return 0 }
        let data = jsonData
        let totalCount = data.count
        
        // 初始化
        if _childrenInfo == nil {
            _childrenInfo = []
            nextScanOffset = startOffset + 1
        }
        
        guard var i = nextScanOffset, i < min(endOffset, totalCount) else {
            nextScanOffset = nil
            return 0
        }
        
        var loadedCount = 0
        
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else { return }
            let ptr = baseAddress.bindMemory(to: UInt8.self, capacity: totalCount)
            let endLimit = min(endOffset, totalCount)
            
            while i < endLimit && loadedCount < count {
                // 1. Skip Whitespace
                while i < endLimit {
                    let byte = ptr[i]
                    if byte == 32 || byte == 10 || byte == 13 || byte == 9 {
                        i += 1
                    } else {
                        break
                    }
                }
                
                if i >= endLimit { break }
                let char = ptr[i]
                
                // 2. Check End
                if char == 125 || char == 93 { // } or ]
                    nextScanOffset = nil
                    
                    if shouldSortKeys && type == .object {
                        // 极致优化：大小写不敏感的字节比较，避免创建临时 String
                        _childrenInfo?.sort { (n1, n2) -> Bool in
                            let k1Len = n1.keyEnd - n1.keyStart
                            let k2Len = n2.keyEnd - n2.keyStart
                            
                            if k1Len <= 0 { return true }
                            if k2Len <= 0 { return false }
                            
                            // 大小写不敏感比较 (A-Z 转换为 a-z)
                            let cmpLen = min(k1Len, k2Len)
                            for j in 0..<cmpLen {
                                var b1 = ptr[n1.keyStart + j]
                                var b2 = ptr[n2.keyStart + j]
                                
                                // 转换为小写 (A-Z: 65-90 -> a-z: 97-122)
                                if b1 >= 65 && b1 <= 90 { b1 += 32 }
                                if b2 >= 65 && b2 <= 90 { b2 += 32 }
                                
                                if b1 != b2 {
                                    return b1 < b2
                                }
                            }
                            // 前缀相同，短的排前面
                            return k1Len < k2Len
                        }
                    }
                    return
                }
                
                // 3. Skip Comma
                if char == 44 {
                    i += 1
                    continue
                }
                
                // 4. Parse Key (Object only)
                var kStart = -1
                var kEnd = -1
                
                if type == .object && char == 34 { // "
                    // Parse raw key range (content inside quotes)
                    let (contentStart, contentEnd, nextIndex) = parseStringRawRange(ptr: ptr, from: i, limit: endLimit)
                    kStart = contentStart
                    kEnd = contentEnd
                    i = nextIndex
                    
                    // Skip Colon
                    while i < endLimit {
                        let b = ptr[i]
                         if b == 58 { // :
                             i += 1
                             break
                         } else if b == 32 || b == 10 || b == 13 || b == 9 {
                             i += 1
                         } else {
                             break
                         }
                    }
                    
                    // Skip Prior Value Whitespace
                    while i < endLimit {
                        let b = ptr[i]
                        if b == 32 || b == 10 || b == 13 || b == 9 { i += 1 } else { break }
                    }
                }
                
                if i >= endLimit { break }
                
                // 5. Parse Value
                let (valStart, valEnd, valType) = parseValueRange(ptr: ptr, from: i, limit: endLimit)
                
                _childrenInfo?.append(ChildInfo(keyStart: kStart, keyEnd: kEnd, start: valStart, end: valEnd, type: valType))
                loadedCount += 1
                i = valEnd
            }
        }
        
        // 如果已扫描到容器结尾，标记为完全加载
        if i >= endOffset - 1 {
            nextScanOffset = nil
        } else {
            nextScanOffset = i
        }
        return loadedCount
    }
    
    // MARK: - Byte Parsing Helpers
    
    private func parseStringRawRange(ptr: UnsafePointer<UInt8>, from start: Int, limit: Int) -> (Int, Int, Int) {
        // start is at '"'
        // Returns (contentStart, contentEnd, nextIndex)
        var i = start + 1
        let contentStart = i
        
        // Scan for end quote
        while i < limit {
            let c = ptr[i]
            if c == 92 { // \
                i += 2
                continue
            }
            if c == 34 { // "
                // Found end quote
                return (contentStart, i, i + 1)
            }
            i += 1
        }
        return (contentStart, limit, limit)
    }
    
    private func parseValueRange(ptr: UnsafePointer<UInt8>, from start: Int, limit: Int) -> (start: Int, end: Int, type: NodeType) {
        let byte = ptr[start]
        
        switch byte {
        case 123: // {
            let end = findMatchingBrace(ptr: ptr, from: start, open: 123, close: 125, limit: limit)
            return (start, end, .object)
        case 91: // [
            let end = findMatchingBrace(ptr: ptr, from: start, open: 91, close: 93, limit: limit)
            return (start, end, .array)
        case 34: // "
            var i = start + 1
            while i < limit {
                let c = ptr[i]
                if c == 92 { i += 2; continue }
                if c == 34 { return (start, i+1, .string) }
                i += 1
            }
            return (start, limit, .string)
        case 116, 102: // t, f
            var i = start
            while i < limit {
                 let c = ptr[i]
                 if isDelimiter(c) { break }
                 i += 1
            }
            return (start, i, .boolean)
        case 110: // n
            var i = start
            while i < limit {
                 let c = ptr[i]
                 if isDelimiter(c) { break }
                 i += 1
            }
            return (start, i, .null)
        default:
            var i = start
            while i < limit {
                 let c = ptr[i]
                 if isDelimiter(c) { break }
                 i += 1
            }
            return (start, i, .number)
        }
    }
    
    private func findMatchingBrace(ptr: UnsafePointer<UInt8>, from start: Int, open: UInt8, close: UInt8, limit: Int) -> Int {
        var depth = 0
        var i = start
        var inString = false
        
        while i < limit {
            let c = ptr[i]
            if inString {
                if c == 92 { i += 2; continue }
                if c == 34 { inString = false }
            } else {
                if c == 34 { inString = true }
                else if c == open { depth += 1 }
                else if c == close {
                    depth -= 1
                    if depth == 0 { return i + 1 }
                }
            }
            i += 1
        }
        return limit
    }
    
    @inline(__always)
    private func isDelimiter(_ byte: UInt8) -> Bool {
        return byte == 44 || byte == 125 || byte == 93 || byte == 32 || byte == 10 || byte == 13 || byte == 9
    }
}

// MARK: - Factory

extension IndexedJSONNode {
    /// Zero-copy factory from Data
    static func fromData(_ data: Data, shouldSortKeys: Bool = false) -> IndexedJSONNode? {
        if data.isEmpty { return nil }

        let firstByte = data.first ?? 0
        let type: NodeType

        switch firstByte {
        case 123: type = .object
        case 91: type = .array
        case 34: type = .string
        case 116, 102: type = .boolean
        case 110: type = .null
        default: type = .number
        }

        let holder = DataHolder(data)
        return IndexedJSONNode(
            type: type,
            keyStart: -1,
            keyEnd: -1,
            startOffset: 0,
            endOffset: data.count,
            depth: 0,
            shouldSortKeys: shouldSortKeys,
            dataHolder: holder
        )
    }

    static func fromJSONString(_ jsonString: String, shouldSortKeys: Bool = false) -> IndexedJSONNode? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return fromData(data, shouldSortKeys: shouldSortKeys)
    }
}

// MARK: - Simple Unescape Helper
fileprivate extension String {
    func simpleUnescape() -> String {
        if !self.contains("\\") { return self }
        // Attempt JSON unescape
        let json = "\"\(self)\""
        if let data = json.data(using: .utf8),
           let str = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String {
            return str
        }
        return self
    }
}

// MARK: - Formatting (极致性能版)
extension IndexedJSONNode {
    
    // 缓存缩进字符串对应的 UTF8 字节
    private static var indentCache: [[UInt8]] = {
        var cache = [[UInt8]]()
        for i in 0..<64 {
            cache.append(Array(repeating: UInt8(ascii: " "), count: i))
        }
        return cache
    }()
    
    // 常用字符串的 UTF8 字节预计算
    private static let openBrace: [UInt8] = [123, 10]      // {\n
    private static let closeBrace: UInt8 = 125             // }
    private static let openBracket: [UInt8] = [91, 10]     // [\n
    private static let closeBracket: UInt8 = 93            // ]
    private static let emptyObject: [UInt8] = [123, 125]   // {}
    private static let emptyArray: [UInt8] = [91, 93]      // []
    private static let colonSpace: [UInt8] = [58, 32]      // : 
    private static let commaNewline: [UInt8] = [44, 10]    // ,\n
    private static let newline: UInt8 = 10                 // \n
    private static let nullBytes: [UInt8] = [110, 117, 108, 108] // null
    private static let quote: UInt8 = 34                   // "
    
    func prettyJSONString(indentation: Int = 2) -> String {
        // 使用 [UInt8] 直接写入字节，最后一次性转 String
        var buffer = [UInt8]()
        buffer.reserveCapacity(endOffset - startOffset + 1024)
        writePrettyJSONFast(to: &buffer, indentation: indentation, currentIndent: 0)
        return String(decoding: buffer, as: UTF8.self)
    }
    
    private func writePrettyJSONFast(to buffer: inout [UInt8], indentation: Int, currentIndent: Int) {
        switch type {
        case .object:
            loadMore(count: Int.max)
            if childCount == 0 {
                buffer.append(contentsOf: Self.emptyObject)
                return
            }
            buffer.append(contentsOf: Self.openBrace)
            let nextIndent = currentIndent + indentation
            let count = childrenInfo.count
            
            for i in 0..<count {
                // 写入缩进
                appendIndent(to: &buffer, count: nextIndent)
                
                // 写入 Key
                if let child = child(at: i), let k = child.key {
                    buffer.append(Self.quote)
                    // 直接写入 key 的 UTF8 字节 (简化处理，不转义)
                    buffer.append(contentsOf: k.utf8)
                    buffer.append(Self.quote)
                } else {
                    buffer.append(Self.quote)
                    buffer.append(Self.quote)
                }
                buffer.append(contentsOf: Self.colonSpace)
                
                // 写入 Value
                if let child = child(at: i) {
                    child.writePrettyJSONFast(to: &buffer, indentation: indentation, currentIndent: nextIndent)
                } else {
                    buffer.append(contentsOf: Self.nullBytes)
                }
                
                if i < count - 1 {
                    buffer.append(contentsOf: Self.commaNewline)
                } else {
                    buffer.append(Self.newline)
                }
            }
            appendIndent(to: &buffer, count: currentIndent)
            buffer.append(Self.closeBrace)
            
        case .array:
            loadMore(count: Int.max)
            if childCount == 0 {
                buffer.append(contentsOf: Self.emptyArray)
                return
            }
            buffer.append(contentsOf: Self.openBracket)
            let nextIndent = currentIndent + indentation
            
            for i in 0..<childCount {
                appendIndent(to: &buffer, count: nextIndent)
                if let child = child(at: i) {
                    child.writePrettyJSONFast(to: &buffer, indentation: indentation, currentIndent: nextIndent)
                } else {
                    buffer.append(contentsOf: Self.nullBytes)
                }
                if i < childCount - 1 {
                    buffer.append(contentsOf: Self.commaNewline)
                } else {
                    buffer.append(Self.newline)
                }
            }
            appendIndent(to: &buffer, count: currentIndent)
            buffer.append(Self.closeBracket)
            
        default:
            // 直接从原始数据复制（避免 trimming 创建新 String）
            let data = jsonData
            var start = startOffset
            var end = endOffset - 1
            
            // 手动 trim whitespace
            while start < end {
                let b = data[start]
                if b == 32 || b == 10 || b == 13 || b == 9 { start += 1 } else { break }
            }
            while end > start {
                let b = data[end]
                if b == 32 || b == 10 || b == 13 || b == 9 { end -= 1 } else { break }
            }
            
            if start <= end {
                buffer.append(contentsOf: data[start...end])
            }
        }
    }
    
    @inline(__always)
    private func appendIndent(to buffer: inout [UInt8], count: Int) {
        if count < Self.indentCache.count {
            buffer.append(contentsOf: Self.indentCache[count])
        } else {
            buffer.append(contentsOf: Array(repeating: UInt8(ascii: " "), count: count))
        }
    }
}
