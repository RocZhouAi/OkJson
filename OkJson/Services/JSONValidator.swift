//  JSONValidator.swift
//  OkJson
//
//  单遍 JSON 语法校验：返回第一个语法错误的 UTF-16 偏移与分类，合法返回 nil。
//  仅校验语法、不构建对象树（建树仍由 IndexedJSONNode 负责）。

import Foundation

enum JSONErrorCategory: Equatable {
    case empty, expectedValue, expectedColon, expectedCommaOrEnd
    case unclosedString, unclosedContainer, invalidEscape, trailingComma
    case trailingGarbage, unexpectedEnd, invalidLiteral, invalidNumber

    var localizedMessage: String {
        switch self {
        case .empty: return "输入为空"
        case .expectedValue: return "这里应该是一个值（对象、数组、字符串、数字或 true/false/null）"
        case .expectedColon: return "键的后面缺少冒号 :"
        case .expectedCommaOrEnd: return "这里缺少逗号 , 或结束括号"
        case .unclosedString: return "字符串的引号没有闭合"
        case .unclosedContainer: return "括号没有闭合"
        case .invalidEscape: return "非法的转义字符"
        case .trailingComma: return "多了一个逗号"
        case .trailingGarbage: return "JSON 结束后还有多余内容"
        case .unexpectedEnd: return "内容意外结束"
        case .invalidLiteral: return "无效的字面量，应为 true、false 或 null"
        case .invalidNumber: return "无效的数字格式"
        }
    }
}

struct JSONSyntaxError: Error, Equatable {
    let utf16Offset: Int
    let category: JSONErrorCategory
}

enum JSONValidator {
    static func firstError(in text: String) -> JSONSyntaxError? {
        var scanner = Scanner(ns: text as NSString)
        scanner.skipWhitespace()
        if scanner.isAtEnd {
            return JSONSyntaxError(utf16Offset: 0, category: .empty)
        }
        do {
            try scanner.scanValue()
            scanner.skipWhitespace()
            if !scanner.isAtEnd {
                return JSONSyntaxError(utf16Offset: scanner.index, category: .trailingGarbage)
            }
            return nil
        } catch let e as JSONSyntaxError {
            return e
        } catch {
            return JSONSyntaxError(utf16Offset: scanner.index, category: .expectedValue)
        }
    }

    private struct Scanner {
        let ns: NSString
        let len: Int
        var index: Int = 0

        init(ns: NSString) { self.ns = ns; self.len = ns.length }

        var isAtEnd: Bool { index >= len }

        mutating func skipWhitespace() {
            while index < len {
                let c = ns.character(at: index)
                if c == 32 || c == 9 || c == 10 || c == 13 { index += 1 } else { break }
            }
        }

        mutating func scanValue() throws {
            skipWhitespace()
            guard index < len else {
                throw JSONSyntaxError(utf16Offset: index, category: .unexpectedEnd)
            }
            switch ns.character(at: index) {
            case 123: try scanObject()           // {
            case 91:  try scanArray()            // [
            case 34:  try scanString()           // "
            case 116: try scanLiteral("true")    // t
            case 102: try scanLiteral("false")   // f
            case 110: try scanLiteral("null")    // n
            case 45, 48...57: try scanNumber()   // - 或数字
            default:
                throw JSONSyntaxError(utf16Offset: index, category: .expectedValue)
            }
        }

        mutating func scanObject() throws {
            index += 1 // {
            skipWhitespace()
            if index < len && ns.character(at: index) == 125 { index += 1; return } // }
            while true {
                skipWhitespace()
                guard index < len else {
                    throw JSONSyntaxError(utf16Offset: index, category: .unclosedContainer)
                }
                if ns.character(at: index) == 125 { // 紧跟 } → 多余逗号
                    throw JSONSyntaxError(utf16Offset: index, category: .trailingComma)
                }
                guard ns.character(at: index) == 34 else {
                    throw JSONSyntaxError(utf16Offset: index, category: .expectedValue)
                }
                try scanString()
                skipWhitespace()
                guard index < len && ns.character(at: index) == 58 else { // :
                    throw JSONSyntaxError(utf16Offset: index, category: .expectedColon)
                }
                index += 1 // :
                try scanValue()
                skipWhitespace()
                guard index < len else {
                    throw JSONSyntaxError(utf16Offset: index, category: .unclosedContainer)
                }
                let d = ns.character(at: index)
                if d == 44 { index += 1; continue }      // ,
                else if d == 125 { index += 1; return }  // }
                else { throw JSONSyntaxError(utf16Offset: index, category: .expectedCommaOrEnd) }
            }
        }

        mutating func scanArray() throws {
            index += 1 // [
            skipWhitespace()
            if index < len && ns.character(at: index) == 93 { index += 1; return } // ]
            while true {
                skipWhitespace()
                if index < len && ns.character(at: index) == 93 { // 紧跟 ] → 多余逗号
                    throw JSONSyntaxError(utf16Offset: index, category: .trailingComma)
                }
                try scanValue()
                skipWhitespace()
                guard index < len else {
                    throw JSONSyntaxError(utf16Offset: index, category: .unclosedContainer)
                }
                let d = ns.character(at: index)
                if d == 44 { index += 1; continue }     // ,
                else if d == 93 { index += 1; return }  // ]
                else { throw JSONSyntaxError(utf16Offset: index, category: .expectedCommaOrEnd) }
            }
        }

        mutating func scanString() throws {
            let start = index
            index += 1 // 开引号
            while index < len {
                let c = ns.character(at: index)
                if c == 92 { // \
                    index += 1
                    guard index < len else {
                        throw JSONSyntaxError(utf16Offset: index, category: .unclosedString)
                    }
                    switch ns.character(at: index) {
                    case 34, 92, 47, 98, 102, 110, 114, 116: index += 1 // " \ / b f n r t
                    case 117: // \uXXXX
                        index += 1
                        var k = 0
                        while k < 4 {
                            guard index < len, isHex(ns.character(at: index)) else {
                                throw JSONSyntaxError(utf16Offset: index, category: .invalidEscape)
                            }
                            index += 1; k += 1
                        }
                    default:
                        throw JSONSyntaxError(utf16Offset: index, category: .invalidEscape)
                    }
                } else if c == 34 { // 闭引号
                    index += 1; return
                } else {
                    index += 1
                }
            }
            throw JSONSyntaxError(utf16Offset: start, category: .unclosedString)
        }

        mutating func scanLiteral(_ literal: String) throws {
            let start = index
            let lit = literal as NSString
            guard start + lit.length <= len else {
                throw JSONSyntaxError(utf16Offset: start, category: .invalidLiteral)
            }
            var k = 0
            while k < lit.length {
                if ns.character(at: start + k) != lit.character(at: k) {
                    throw JSONSyntaxError(utf16Offset: start, category: .invalidLiteral)
                }
                k += 1
            }
            index = start + lit.length
        }

        mutating func scanNumber() throws {
            let start = index
            if index < len && ns.character(at: index) == 45 { index += 1 } // -
            guard index < len, isDigit(ns.character(at: index)) else {
                throw JSONSyntaxError(utf16Offset: start, category: .invalidNumber)
            }
            while index < len && isDigit(ns.character(at: index)) { index += 1 }
            if index < len && ns.character(at: index) == 46 { // .
                index += 1
                guard index < len, isDigit(ns.character(at: index)) else {
                    throw JSONSyntaxError(utf16Offset: index, category: .invalidNumber)
                }
                while index < len && isDigit(ns.character(at: index)) { index += 1 }
            }
            if index < len && (ns.character(at: index) == 101 || ns.character(at: index) == 69) { // e/E
                index += 1
                if index < len && (ns.character(at: index) == 43 || ns.character(at: index) == 45) { index += 1 }
                guard index < len, isDigit(ns.character(at: index)) else {
                    throw JSONSyntaxError(utf16Offset: index, category: .invalidNumber)
                }
                while index < len && isDigit(ns.character(at: index)) { index += 1 }
            }
        }

        func isDigit(_ c: unichar) -> Bool { c >= 48 && c <= 57 }
        func isHex(_ c: unichar) -> Bool {
            (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
        }
    }
}
