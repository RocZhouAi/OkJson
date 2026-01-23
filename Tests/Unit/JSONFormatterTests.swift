//  JSONFormatterTests.swift
//  OkJsonTests
//
//  Unit tests for JSONFormatter
//

import XCTest
@testable import OkJson

/// Unit tests for JSONFormatter
final class JSONFormatterTests: XCTestCase {
    // MARK: - Format Tests

    func testFormatWithTwoSpaces() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .string, key: "name", value: "John", depth: 1),
                JSONNode(type: .number, key: "age", value: 30, depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node, options: OkJson.FormatOptions(indentation: 2))
        XCTAssertTrue(formatted.contains("  "))
    }

    func testFormatWithFourSpaces() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .string, key: "name", value: "John", depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node, options: OkJson.FormatOptions(indentation: 4))
        XCTAssertTrue(formatted.contains("    "))
    }

    func testFormatNestedStructure() {
        let innerNode = JSONNode(
            type: .string,
            key: "city",
            value: "NYC",
            depth: 2
        )
        let addressNode = JSONNode(
            type: .object,
            key: "address",
            children: [innerNode],
            depth: 1
        )
        let root = JSONNode(
            type: .object,
            children: [addressNode],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(root, options: OkJson.FormatOptions(indentation: 2))

        XCTAssertTrue(formatted.contains("{"))
        XCTAssertTrue(formatted.contains("}"))
        XCTAssertTrue(formatted.contains("city"))
    }

    // MARK: - Sort Keys Tests

    func testFormatSortedKeys() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .string, key: "zebra", value: "last", depth: 1),
                JSONNode(type: .string, key: "apple", value: "first", depth: 1),
                JSONNode(type: .string, key: "banana", value: "middle", depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node, options: OkJson.FormatOptions(indentation: 2, sortKeys: true))

        // Check that apple comes before zebra
        let appleRange = formatted.range(of: "\"apple\"")
        let zebraRange = formatted.range(of: "\"zebra\"")
        if let appleRange = appleRange, let zebraRange = zebraRange {
            XCTAssertLessThan(appleRange.lowerBound, zebraRange.lowerBound)
        } else {
            XCTFail("Could not find keys in formatted output")
        }
    }

    // MARK: - Minify Tests

    func testMinifyObject() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .string, key: "name", value: "John", depth: 1),
                JSONNode(type: .number, key: "age", value: 30, depth: 1)
            ],
            depth: 0
        )

        let minified = JSONFormatter.shared.minify(node)

        // Should not contain newlines or extra spaces
        XCTAssertFalse(minified.contains("\n"))
        XCTAssertEqual(minified.first, "{")
        XCTAssertEqual(minified.last, "}")
    }

    func testMinifyArray() {
        let node = JSONNode(
            type: .array,
            children: [
                JSONNode(type: .number, value: 1, depth: 1),
                JSONNode(type: .number, value: 2, depth: 1),
                JSONNode(type: .number, value: 3, depth: 1)
            ],
            depth: 0
        )

        let minified = JSONFormatter.shared.minify(node)

        XCTAssertEqual(minified, "[1,2,3]")
    }

    // MARK: - Empty Structure Tests

    func testFormatEmptyObject() {
        let node = JSONNode(type: .object, children: [], depth: 0)
        let formatted = JSONFormatter.shared.format(node)
        XCTAssertEqual(formatted, "{}")
    }

    func testFormatEmptyArray() {
        let node = JSONNode(type: .array, children: [], depth: 0)
        let formatted = JSONFormatter.shared.format(node)
        XCTAssertEqual(formatted, "[]")
    }

    // MARK: - Escape String Tests

    func testFormatEscapesQuotes() {
        let node = JSONNode(
            type: .string,
            key: "text",
            value: "He said \"hello\"",
            depth: 1
        )
        let root = JSONNode(type: .object, children: [node], depth: 0)

        let formatted = JSONFormatter.shared.format(root)
        XCTAssertTrue(formatted.contains("\\\""))
    }

    func testFormatEscapesBackslashes() {
        let node = JSONNode(
            type: .string,
            key: "path",
            value: "C:\\Users\\test",
            depth: 1
        )
        let root = JSONNode(type: .object, children: [node], depth: 0)

        let formatted = JSONFormatter.shared.format(root)
        XCTAssertTrue(formatted.contains("\\\\"))
    }

    func testFormatEscapesNewlines() {
        let node = JSONNode(
            type: .string,
            key: "multiline",
            value: "line1\nline2",
            depth: 1
        )
        let root = JSONNode(type: .object, children: [node], depth: 0)

        let formatted = JSONFormatter.shared.format(root)
        XCTAssertTrue(formatted.contains("\\n"))
    }

    func testFormatEscapesTabs() {
        let node = JSONNode(
            type: .string,
            key: "tabbed",
            value: "col1\tcol2",
            depth: 1
        )
        let root = JSONNode(type: .object, children: [node], depth: 0)

        let formatted = JSONFormatter.shared.format(root)
        XCTAssertTrue(formatted.contains("\\t"))
    }

    // MARK: - Display Value Tests

    func testFormatNumberValue() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .number, key: "int", value: 42, depth: 1),
                JSONNode(type: .number, key: "float", value: 3.14, depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node)
        XCTAssertTrue(formatted.contains("42"))
        XCTAssertTrue(formatted.contains("3.14"))
    }

    func testFormatBooleanValue() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .boolean, key: "active", value: true, depth: 1),
                JSONNode(type: .boolean, key: "deleted", value: false, depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node)
        XCTAssertTrue(formatted.contains("true"))
        XCTAssertTrue(formatted.contains("false"))
    }

    func testFormatNullValue() {
        let node = JSONNode(
            type: .object,
            children: [
                JSONNode(type: .null, key: "empty", value: nil, depth: 1)
            ],
            depth: 0
        )

        let formatted = JSONFormatter.shared.format(node)
        XCTAssertTrue(formatted.contains("null"))
    }
}
