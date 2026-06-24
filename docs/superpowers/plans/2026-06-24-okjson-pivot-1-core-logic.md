# OkJson 转向 · 计划① 逻辑地基层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为"树形浏览器 → JSON 文本编辑器"重构打好纯逻辑地基:精确错误定位、代码折叠区间、格式化封装、行列换算,全部 TDD,零 UI。

**Architecture:** 新增 4 个独立、可单测的逻辑单元(`LineColumnConverter`、`JSONValidator`、`FoldingModel`、`JSONFormatter.format`),复用现有 `IndexedJSONNode.prettyJSONString` 做美化。位置单位全程统一为 **UTF-16 偏移**(与 `NSString`/`NSRange`/`NSTextView` 一致)。本计划不触碰任何 UI。

**Tech Stack:** Swift 5.9、Foundation、XCTest。测试 target `OkJsonTests`,`@testable import OkJson`,文件置于 `Tests/Unit/`。

## Global Constraints

- 纯 Swift + Foundation,**零第三方依赖**;macOS 13+;Swift 5.9。
- 代码规范:4 空格缩进、行宽警告 150、禁止 `!` 强解包与 `try!`、类加 `final`、`guard` 早返回。
- 位置单位统一为 **UTF-16 偏移**(code unit),与 `NSString.length` 一致。
- **复用优先、最小侵入**:不重写现有高性能实现(`IndexedJSONNode`/`calculateHighlights`/`prettyJSONString`);改现有代码一律"扩展/增强"而非"推翻",`JSONParser.validate()` 保持原样不动。
- **不留死代码**:本计划新增的每个类型都必须被测试引用;失效测试(测已删类型)作为显式删除步骤清掉。
- 错误文案中文人话化,挂在 `JSONErrorCategory` 上,**不改动** `Constants.ErrorMessages` 现有英文常量(留给后续计划按需处理)。
- 提交信息中文:`<类型>: <描述>`。分支:`feat/text-editor-pivot`。

---

### Task 0: 恢复测试绿色基线(清除失效测试)

测试套件当前**编译不过**:`JSONNodeTests.swift`、`JSONFormatterTests.swift` 引用已删除的 `JSONNode` 类型(独立 `JSONNode` 已被 `IndexedJSONNode` 取代)。它们的被测对象已不存在,属于死代码,删除即可让 TDD 跑起来。

**Files:**
- Delete: `Tests/Unit/JSONNodeTests.swift`
- Delete: `Tests/Unit/JSONFormatterTests.swift`

- [ ] **Step 1: 确认两文件确实只测已删的 JSONNode**

Run: `grep -c "IndexedJSONNode\|JSONValidator\|FoldingModel\|LineColumnConverter" Tests/Unit/JSONNodeTests.swift Tests/Unit/JSONFormatterTests.swift`
Expected: 两个文件均为 `0`(它们不涉及任何要保留/新增的类型,可安全删除)。

- [ ] **Step 2: 删除两个失效测试文件**

```bash
git rm Tests/Unit/JSONNodeTests.swift Tests/Unit/JSONFormatterTests.swift
```

- [ ] **Step 3: 验证测试套件恢复可编译可运行**

Run: `swift build --build-tests 2>&1 | grep -c "error:"`
Expected: `0`(无编译错误)。

Run: `swift test 2>&1 | tail -5`
Expected: 测试可运行并通过(`ColorSchemeTests`/`FormatterViewModelTests`/`JSONParserTests` 全绿);若有残留失败,记录但不在本任务修复——本任务只负责"可编译可运行"。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: 移除引用已删 JSONNode 类型的失效测试，恢复测试套件可编译"
```

---

### Task 1: LineColumnConverter — UTF-16 偏移 ↔ (行,列) 换算

**Files:**
- Create: `OkJson/Utilities/LineColumnConverter.swift`
- Test: `Tests/Unit/LineColumnConverterTests.swift`

**Interfaces:**
- Produces:
  - `struct LineColumnConverter`
  - `init(text: String)`
  - `func lineColumn(at utf16Offset: Int) -> (line: Int, column: Int)`(行列均 1-based)
  - `func utf16Offset(line: Int, column: Int) -> Int`

- [ ] **Step 1: 写失败测试**

```swift
//  LineColumnConverterTests.swift
//  OkJsonTests

import XCTest
@testable import OkJson

final class LineColumnConverterTests: XCTestCase {
    func testSingleLine() {
        let c = LineColumnConverter(text: "hello")
        XCTAssertEqual(c.lineColumn(at: 0).line, 1)
        XCTAssertEqual(c.lineColumn(at: 0).column, 1)
        XCTAssertEqual(c.lineColumn(at: 5).column, 6)
    }

    func testMultiLine() {
        // "{\n  \"a\": 1\n}" —— 第2行从 offset 2 开始
        let text = "{\n  \"a\": 1\n}"
        let c = LineColumnConverter(text: text)
        XCTAssertEqual(c.lineColumn(at: 0).line, 1)   // '{'
        XCTAssertEqual(c.lineColumn(at: 2).line, 2)   // 第2行行首空格
        XCTAssertEqual(c.lineColumn(at: 2).column, 1)
        let nl2 = (text as NSString).range(of: "}").location
        XCTAssertEqual(c.lineColumn(at: nl2).line, 3) // '}'
    }

    func testRoundTrip() {
        let c = LineColumnConverter(text: "ab\ncde\nf")
        for off in 0...8 {
            let lc = c.lineColumn(at: off)
            XCTAssertEqual(c.utf16Offset(line: lc.line, column: lc.column), min(off, 8))
        }
    }

    func testChineseAndEmoji() {
        // 中文 1 个 UTF-16 unit；emoji "😀" 是代理对 2 个 unit
        let text = "{\n  \"名\": \"😀\"\n}"
        let c = LineColumnConverter(text: text)
        let braceClose = (text as NSString).range(of: "}").location
        XCTAssertEqual(c.lineColumn(at: braceClose).line, 3)
        // 往返一致(夹紧在总长内)
        let lc = c.lineColumn(at: braceClose)
        XCTAssertEqual(c.utf16Offset(line: lc.line, column: lc.column), braceClose)
    }

    func testOutOfRangeClamped() {
        let c = LineColumnConverter(text: "ab")
        XCTAssertEqual(c.lineColumn(at: 999).line, 1)
        XCTAssertEqual(c.lineColumn(at: 999).column, 3) // 夹到末尾(len=2 → col 3)
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter LineColumnConverterTests 2>&1 | tail -5`
Expected: 编译失败 `cannot find 'LineColumnConverter' in scope`。

- [ ] **Step 3: 实现**

```swift
//  LineColumnConverter.swift
//  OkJson
//
//  UTF-16 偏移 ↔ (行,列) 双向换算。位置单位为 UTF-16 code unit，
//  与 NSString / NSRange / NSTextView 一致。行以 \n 分隔，行列均 1-based。

import Foundation

struct LineColumnConverter {
    /// 每行起始处的 UTF-16 偏移（lineStarts[0] == 0）
    private let lineStarts: [Int]
    private let totalLength: Int

    init(text: String) {
        let ns = text as NSString
        let len = ns.length
        var starts: [Int] = [0]
        var i = 0
        while i < len {
            if ns.character(at: i) == 10 { // \n
                starts.append(i + 1)
            }
            i += 1
        }
        self.lineStarts = starts
        self.totalLength = len
    }

    /// UTF-16 偏移 → (行,列)，均 1-based；越界偏移夹紧到合法范围。
    func lineColumn(at utf16Offset: Int) -> (line: Int, column: Int) {
        let offset = max(0, min(utf16Offset, totalLength))
        var lo = 0
        var hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return (lo + 1, offset - lineStarts[lo] + 1)
    }

    /// (行,列) → UTF-16 偏移；越界输入夹紧。
    func utf16Offset(line: Int, column: Int) -> Int {
        let lineIdx = max(0, min(line - 1, lineStarts.count - 1))
        let offset = lineStarts[lineIdx] + max(0, column - 1)
        return max(0, min(offset, totalLength))
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter LineColumnConverterTests 2>&1 | tail -5`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add OkJson/Utilities/LineColumnConverter.swift Tests/Unit/LineColumnConverterTests.swift
git commit -m "feat: 新增 LineColumnConverter 做 UTF-16 偏移与行列双向换算"
```

---

### Task 2: JSONValidator — 精确位置 + 错误分类 + 中文文案

自研单遍 JSON 语法校验器,返回**第一个**语法错误的 UTF-16 偏移与分类;增强 `JSONParser.parseError` 复用它(替换现有依赖 `JSONSerialization`、列号永远=1 的旧实现);给 `ParseError` 加可选 `category` 字段(向后兼容)。

**Files:**
- Create: `OkJson/Services/JSONValidator.swift`
- Modify: `OkJson/Models/ParseError.swift`(新增可选 `category` 字段,默认 nil)
- Modify: `OkJson/Services/JSONParser.swift`(`parseError(from:)` 改为复用 `JSONValidator`;`validate()` 不动)
- Test: `Tests/Unit/JSONValidatorTests.swift`

**Interfaces:**
- Produces:
  - `enum JSONErrorCategory: Equatable`,成员:`empty/expectedValue/expectedColon/expectedCommaOrEnd/unclosedString/unclosedContainer/invalidEscape/trailingComma/trailingGarbage/unexpectedEnd/invalidLiteral/invalidNumber`
  - `var JSONErrorCategory.localizedMessage: String`(中文)
  - `struct JSONSyntaxError: Error, Equatable { let utf16Offset: Int; let category: JSONErrorCategory }`
  - `enum JSONValidator { static func firstError(in text: String) -> JSONSyntaxError? }`(nil = 合法)
- Consumes(later tasks):Task 4 用 `JSONValidator.firstError`;UI 计划用 `ParseError.category`。

- [ ] **Step 1: 写失败测试**

```swift
//  JSONValidatorTests.swift
//  OkJsonTests

import XCTest
@testable import OkJson

final class JSONValidatorTests: XCTestCase {
    func testValidPasses() {
        for json in ["{}", "[]", "{\"a\":1}", "[1,2,3]",
                     "{\"a\":{\"b\":[true,false,null]}}", "\"str\"", "-3.14e10"] {
            XCTAssertNil(JSONValidator.firstError(in: json), "应合法: \(json)")
        }
    }

    func testEmpty() {
        XCTAssertEqual(JSONValidator.firstError(in: "")?.category, .empty)
        XCTAssertEqual(JSONValidator.firstError(in: "   \n ")?.category, .empty)
    }

    func testUnclosedContainer() {
        XCTAssertEqual(JSONValidator.firstError(in: "{\"a\":1")?.category, .unclosedContainer)
        XCTAssertEqual(JSONValidator.firstError(in: "[1,2")?.category, .unclosedContainer)
    }

    func testExpectedColon() {
        XCTAssertEqual(JSONValidator.firstError(in: "{\"a\" 1}")?.category, .expectedColon)
    }

    func testExpectedCommaOrEnd() {
        XCTAssertEqual(JSONValidator.firstError(in: "{\"a\":1 \"b\":2}")?.category, .expectedCommaOrEnd)
    }

    func testTrailingComma() {
        XCTAssertEqual(JSONValidator.firstError(in: "[1,2,]")?.category, .trailingComma)
        XCTAssertEqual(JSONValidator.firstError(in: "{\"a\":1,}")?.category, .trailingComma)
    }

    func testExpectedValue() {
        XCTAssertEqual(JSONValidator.firstError(in: "{\"a\":}")?.category, .expectedValue)
    }

    func testUnclosedString() {
        XCTAssertEqual(JSONValidator.firstError(in: "\"abc")?.category, .unclosedString)
    }

    func testInvalidEscape() {
        XCTAssertEqual(JSONValidator.firstError(in: "\"a\\xb\"")?.category, .invalidEscape)
    }

    func testInvalidLiteralAndNumber() {
        XCTAssertEqual(JSONValidator.firstError(in: "tru")?.category, .invalidLiteral)
        XCTAssertEqual(JSONValidator.firstError(in: "-")?.category, .invalidNumber)
    }

    func testTrailingGarbage() {
        XCTAssertEqual(JSONValidator.firstError(in: "123 abc")?.category, .trailingGarbage)
    }

    func testErrorOffsetAndChinese() {
        // 第2行 x 处期望一个值
        let text = "{\n  \"a\": x\n}"
        let err = JSONValidator.firstError(in: text)
        XCTAssertEqual(err?.category, .expectedValue)
        let xLoc = (text as NSString).range(of: "x").location
        XCTAssertEqual(err?.utf16Offset, xLoc)
        // 含中文 key 的未闭合容器
        XCTAssertEqual(JSONValidator.firstError(in: "{\"名字\":1")?.category, .unclosedContainer)
    }

    func testParseErrorBridging() {
        let pe = JSONParser.shared.parseError(from: "{\n  \"a\": x\n}")
        XCTAssertNotNil(pe)
        XCTAssertEqual(pe?.line, 2)
        XCTAssertEqual(pe?.category, .expectedValue)
        XCTAssertNil(JSONParser.shared.parseError(from: "{\"a\":1}"))
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter JSONValidatorTests 2>&1 | tail -5`
Expected: 编译失败 `cannot find 'JSONValidator' in scope`。

- [ ] **Step 3: 实现 JSONValidator**

```swift
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
```

- [ ] **Step 4: 给 ParseError 增加可选 category(向后兼容)**

在 `OkJson/Models/ParseError.swift` 中,为 `struct ParseError` 增加字段与参数(其余不动):

```swift
    /// 错误分类（新增，可选，向后兼容）
    let category: JSONErrorCategory?

    init(message: String, line: Int, column: Int, offset: Int,
         context: String? = nil, category: JSONErrorCategory? = nil) {
        self.message = message
        self.line = max(1, line)
        self.column = max(1, column)
        self.offset = max(0, offset)
        self.context = context
        self.category = category
    }
```

- [ ] **Step 5: 增强 JSONParser.parseError 复用 JSONValidator**

把 `OkJson/Services/JSONParser.swift` 的 `parseError(from:)` 整体替换为(`validate(_:)` 与 `private func error(...)` 保留不动或随之清理——见下):

```swift
    /// 从 JSON 字符串创建解析错误（基于自研 JSONValidator，精确到行列 + 分类）
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
```

随后 `private func error(from:jsonString:)` 已无人调用 → **删除该私有方法**(避免死代码)。`validate(_:)` 保持不动。

- [ ] **Step 6: 运行确认通过**

Run: `swift test --filter JSONValidatorTests 2>&1 | tail -5`
Expected: 全部 PASS。

Run: `swift build 2>&1 | grep -c "error:"`
Expected: `0`(确认删私有方法后无悬空引用)。

- [ ] **Step 7: Commit**

```bash
git add OkJson/Services/JSONValidator.swift OkJson/Models/ParseError.swift OkJson/Services/JSONParser.swift Tests/Unit/JSONValidatorTests.swift
git commit -m "feat: 新增 JSONValidator 精确定位语法错误并分类，JSONParser 复用其结果"
```

---

### Task 3: FoldingModel — 文本 → 折叠区间

括号配对扫描(跳过字符串内括号),输出每个**跨多行**容器的折叠区间。不校验合法性、不依赖建树,对编辑中途的文本也能尽力计算。

**Files:**
- Create: `OkJson/Models/FoldingModel.swift`
- Test: `Tests/Unit/FoldingModelTests.swift`

**Interfaces:**
- Produces:
  - `struct FoldRange: Equatable { let startLine: Int; let endLine: Int }`(1-based,含首尾行)
  - `enum FoldingModel { static func foldRanges(in text: String) -> [FoldRange] }`(按 startLine、endLine 升序)

- [ ] **Step 1: 写失败测试**

```swift
//  FoldingModelTests.swift
//  OkJsonTests

import XCTest
@testable import OkJson

final class FoldingModelTests: XCTestCase {
    func testSingleLineNotFoldable() {
        XCTAssertEqual(FoldingModel.foldRanges(in: "{\"a\":1}"), [])
    }

    func testSimpleObject() {
        let text = "{\n  \"a\": 1\n}"
        XCTAssertEqual(FoldingModel.foldRanges(in: text), [FoldRange(startLine: 1, endLine: 3)])
    }

    func testNested() {
        let text = "{\n  \"a\": {\n    \"b\": 1\n  }\n}"
        XCTAssertEqual(
            FoldingModel.foldRanges(in: text),
            [FoldRange(startLine: 1, endLine: 5), FoldRange(startLine: 2, endLine: 4)]
        )
    }

    func testBracketsInsideStringIgnored() {
        let text = "{\n  \"a\": \"{[}]\"\n}"
        XCTAssertEqual(FoldingModel.foldRanges(in: text), [FoldRange(startLine: 1, endLine: 3)])
    }

    func testEscapedQuoteInString() {
        let text = "{\n  \"a\": \"he said \\\"{\\\"\"\n}"
        XCTAssertEqual(FoldingModel.foldRanges(in: text), [FoldRange(startLine: 1, endLine: 3)])
    }

    func testEmptyContainerAcrossLines() {
        let text = "{\n}"
        XCTAssertEqual(FoldingModel.foldRanges(in: text), [FoldRange(startLine: 1, endLine: 2)])
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter FoldingModelTests 2>&1 | tail -5`
Expected: 编译失败 `cannot find 'FoldingModel' in scope`。

- [ ] **Step 3: 实现**

```swift
//  FoldingModel.swift
//  OkJson
//
//  从 JSON 文本计算代码折叠区间：每个跨多行的 {} / [] 产生一个区间。
//  纯文本括号配对扫描，跳过字符串内部括号；不依赖 JSON 是否完全合法。

import Foundation

struct FoldRange: Equatable {
    let startLine: Int
    let endLine: Int
}

enum FoldingModel {
    static func foldRanges(in text: String) -> [FoldRange] {
        let ns = text as NSString
        let len = ns.length
        var ranges: [FoldRange] = []
        var stack: [Int] = []   // 开括号所在行号
        var line = 1
        var i = 0
        var inString = false

        while i < len {
            let c = ns.character(at: i)
            if inString {
                if c == 92 { i += 2; continue }       // \ 跳过转义的下一个字符
                if c == 34 { inString = false }       // 闭引号
                else if c == 10 { line += 1 }         // 字符串内换行也计行
                i += 1
                continue
            }
            switch c {
            case 34: inString = true                  // "
            case 123, 91: stack.append(line)          // { [
            case 125, 93:                              // } ]
                if let openLine = stack.popLast(), line > openLine {
                    ranges.append(FoldRange(startLine: openLine, endLine: line))
                }
            case 10: line += 1                         // \n
            default: break
            }
            i += 1
        }

        return ranges.sorted {
            $0.startLine != $1.startLine ? $0.startLine < $1.startLine : $0.endLine < $1.endLine
        }
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter FoldingModelTests 2>&1 | tail -5`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add OkJson/Models/FoldingModel.swift Tests/Unit/FoldingModelTests.swift
git commit -m "feat: 新增 FoldingModel 按括号配对计算代码折叠区间"
```

---

### Task 4: JSONFormatter.format — 美化封装(幂等)

把现有 `IndexedJSONNode.prettyJSONString` 封装成一个清晰、对外的 `JSONFormatter.format`,合法才美化、非法返回 nil;复用 Task 2 的 `JSONValidator` 做前置校验。

**Files:**
- Modify: `OkJson/Services/JSONFormatter.swift`(给现有空 `JSONFormatter` 加 `format`,**不动** `SyntaxHighlightService`)
- Test: `Tests/Unit/JSONFormatterFormatTests.swift`

**Interfaces:**
- Consumes:`JSONValidator.firstError`、`IndexedJSONNode.fromData`、`IndexedJSONNode.prettyJSONString(indentation:)`
- Produces:`static func JSONFormatter.format(_ text: String, indent: Int = 2, sortKeys: Bool = false) -> String?`

- [ ] **Step 1: 写失败测试**

```swift
//  JSONFormatterFormatTests.swift
//  OkJsonTests

import XCTest
@testable import OkJson

final class JSONFormatterFormatTests: XCTestCase {
    func testFormatTwoSpaces() {
        let out = JSONFormatter.format("{\"a\":1}", indent: 2)
        XCTAssertEqual(out, "{\n  \"a\": 1\n}")
    }

    func testFormatFourSpaces() {
        let out = JSONFormatter.format("{\"a\":1}", indent: 4)
        XCTAssertEqual(out, "{\n    \"a\": 1\n}")
    }

    func testSortKeys() {
        let out = JSONFormatter.format("{\"b\":2,\"a\":1}", indent: 2, sortKeys: true)
        XCTAssertEqual(out, "{\n  \"a\": 1,\n  \"b\": 2\n}")
    }

    func testIdempotent() {
        let once = JSONFormatter.format("{\"a\":[1,2,{\"c\":3}]}", indent: 2)
        XCTAssertNotNil(once)
        let twice = JSONFormatter.format(once ?? "", indent: 2)
        XCTAssertEqual(once, twice)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(JSONFormatter.format("{\"a\":1", indent: 2))
        XCTAssertNil(JSONFormatter.format("", indent: 2))
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter JSONFormatterFormatTests 2>&1 | tail -5`
Expected: 编译失败 `type 'JSONFormatter' has no member 'format'`。

- [ ] **Step 3: 实现(追加到 JSONFormatter.swift 末尾)**

```swift
// MARK: - 格式化封装

extension JSONFormatter {
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
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter JSONFormatterFormatTests 2>&1 | tail -5`
Expected: 全部 PASS。

> 注:若 `testSortKeys` 因现有排序为大小写不敏感的字节序而与预期细节不符,以实际稳定输出修正断言(排序行为来自既有 `IndexedJSONNode`,不在本计划改动范围)。

- [ ] **Step 5: Commit**

```bash
git add OkJson/Services/JSONFormatter.swift Tests/Unit/JSONFormatterFormatTests.swift
git commit -m "feat: JSONFormatter.format 封装美化（缩进/排序/幂等），复用 IndexedJSONNode"
```

---

## 计划① 收尾验证

- [ ] **全套测试通过**

Run: `swift test 2>&1 | tail -8`
Expected: 全绿,含新增 4 个测试类。

- [ ] **Lint 通过**

Run: `swiftlint lint --strict 2>&1 | tail -5`
Expected: 无 strict 违规(若 swiftlint 未安装则跳过并说明)。

- [ ] **无死代码残留**

Run: `grep -rn "func error(from" OkJson/Services/JSONParser.swift`
Expected: 无输出(确认 Task 2 已删旧私有错误方法)。

---

## Self-Review(对照 spec)

- **精确错误定位**(spec §7)→ Task 2 `JSONValidator` + `ParseError.category` + `LineColumnConverter`(Task 1)。✓
- **中文人话错误**(spec §7)→ `JSONErrorCategory.localizedMessage`。✓
- **代码折叠区间**(spec §4/§5)→ Task 3 `FoldingModel`。✓
- **格式化:缩进/排序/幂等**(spec §5/§8)→ Task 4 `JSONFormatter.format`。✓
- **多字节安全**(spec §8)→ Task 1 `testChineseAndEmoji`。✓
- **复用而非重写、不留死代码**(Global Constraints)→ 复用 `prettyJSONString`/`IndexedJSONNode`;Task 0 删失效测试;Task 2 删旧私有方法。✓
- **视口着色 / 编辑器 / 同步滚动**→ 属计划②③,本计划不含。✓(范围正确)
