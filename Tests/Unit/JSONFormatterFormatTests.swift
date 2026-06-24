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
