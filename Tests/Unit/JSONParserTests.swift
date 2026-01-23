//  JSONParserTests.swift
//  OkJsonTests
//
//  Unit tests for JSONParser
//

import XCTest
@testable import OkJson

/// Unit tests for JSONParser
final class JSONParserTests: XCTestCase {
    // MARK: - Valid JSON Tests

    func testParseValidObject() throws {
        let json = """
        {"name": "John", "age": 30}
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            XCTAssertEqual(node.type, .object)
            XCTAssertTrue(node.hasChildren)
            XCTAssertEqual(node.children.count, 2)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testParseValidArray() throws {
        let json = """
        [1, 2, 3, "four"]
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            XCTAssertEqual(node.type, .array)
            XCTAssertEqual(node.children.count, 4)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testParseNestedStructure() throws {
        let json = """
        {
            "user": {
                "name": "Alice",
                "tags": ["admin", "user"]
            }
        }
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            XCTAssertEqual(node.type, .object)
            let user = node.children.first { $0.key == "user" }
            XCTAssertNotNil(user)
            XCTAssertEqual(user?.type, .object)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Invalid JSON Tests

    func testParseInvalidJSONWithErrorLocation() {
        let json = """
        {"name": "John", "age": }
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success:
            XCTFail("Expected failure for invalid JSON")
        case .failure(let error):
            XCTAssertTrue(error.line > 0)
            XCTAssertTrue(error.column > 0)
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    func testParseUnclosedString() {
        let json = #"{"name": "John}"#
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }

    func testParseMissingComma() {
        let json = """
        [1 2 3]
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            XCTAssertTrue(true) // Expected failure path
        }
    }

    // MARK: - Edge Case Tests

    func testParseEmptyInput() {
        let result = JSONParser.shared.parse("")

        switch result {
        case .success:
            XCTFail("Expected failure for empty input")
        case .failure(let error):
            XCTAssertEqual(error.message, Constants.ErrorMessages.emptyInput)
        }
    }

    func testParseWhitespaceOnly() {
        let result = JSONParser.shared.parse("   \n\t  ")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            XCTAssertTrue(true) // Expected failure path
        }
    }

    // MARK: - Unicode Tests

    func testParseUnicodeCharacters() {
        let json = #"{"emoji": "😀", "chinese": "你好", "russian": "Привет"}"#
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            let emoji = node.children.first { $0.key == "emoji" }
            XCTAssertEqual(emoji?.value as? String, "😀")
        case .failure:
            XCTFail("Expected success with unicode")
        }
    }

    func testParseEscapedCharacters() {
        let json = #"{"text": "Line\nBreak\tTab"}"#
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            // Check that the escaped characters are preserved
            if let textValue = node.children.first?.value as? String {
                XCTAssertTrue(textValue.contains("\n"))
                XCTAssertTrue(textValue.contains("\t"))
            }
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Validation Tests

    func testValidateValidJSON() {
        let json = #"{"valid": true}"#
        XCTAssertTrue(JSONParser.shared.validate(json))
    }

    func testValidateInvalidJSON() {
        let json = #"{"invalid": }"#
        XCTAssertFalse(JSONParser.shared.validate(json))
    }

    func testValidateEmptyString() {
        XCTAssertFalse(JSONParser.shared.validate(""))
    }

    // MARK: - Node Retrieval Tests

    func testGetNodeAtPath() {
        let json = """
        {
            "user": {
                "name": "Alice",
                "age": 25
            }
        }
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let root):
            let nameNode = JSONParser.shared.getNode(atPath: "$.user.name", from: root)
            XCTAssertNotNil(nameNode)
            XCTAssertEqual(nameNode?.value as? String, "Alice")

            let missingNode = JSONParser.shared.getNode(atPath: "$.user.address", from: root)
            XCTAssertNil(missingNode)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Number Tests

    func testParseNumberValues() {
        let json = """
        {
            "integer": 42,
            "negative": -10,
            "float": 3.14,
            "exponent": 1.5e10
        }
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            XCTAssertEqual(node.children.count, 4)
            let intNode = node.children.first { $0.key == "integer" }
            XCTAssertEqual(intNode?.value as? Double, 42.0)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Boolean and Null Tests

    func testParseBooleanAndNull() {
        let json = """
        {"active": true, "deleted": false, "value": null}
        """
        let result = JSONParser.shared.parse(json)

        switch result {
        case .success(let node):
            let active = node.children.first { $0.key == "active" }
            let deleted = node.children.first { $0.key == "deleted" }
            let value = node.children.first { $0.key == "value" }

            XCTAssertEqual(active?.value as? Bool, true)
            XCTAssertEqual(deleted?.value as? Bool, false)
            XCTAssertEqual(value?.type, .null)
        case .failure:
            XCTFail("Expected success")
        }
    }
}
