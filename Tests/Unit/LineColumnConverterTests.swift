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
        let braceClose = (text as NSString).range(of: "}").location
        XCTAssertEqual(c.lineColumn(at: braceClose).line, 3) // '}'
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
        let lc = c.lineColumn(at: braceClose)
        XCTAssertEqual(c.utf16Offset(line: lc.line, column: lc.column), braceClose)
    }

    func testOutOfRangeClamped() {
        let c = LineColumnConverter(text: "ab")
        XCTAssertEqual(c.lineColumn(at: 999).line, 1)
        XCTAssertEqual(c.lineColumn(at: 999).column, 3) // 夹到末尾(len=2 → col 3)
    }
}
