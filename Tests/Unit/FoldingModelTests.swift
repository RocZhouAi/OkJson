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
