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
