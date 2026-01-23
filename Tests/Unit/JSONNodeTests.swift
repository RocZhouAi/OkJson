//  JSONNodeTests.swift
//  OkJsonTests
//
//  Unit tests for JSONNode
//

import XCTest
@testable import OkJson

/// Unit tests for JSONNode model
final class JSONNodeTests: XCTestCase {
    // MARK: - Initialization Tests

    func testNodeInitialization() {
        let node = JSONNode(
            type: .string,
            key: "name",
            value: "John",
            depth: 1
        )

        XCTAssertEqual(node.type, .string)
        XCTAssertEqual(node.key, "name")
        XCTAssertEqual(node.value as? String, "John")
        XCTAssertEqual(node.depth, 1)
        XCTAssertTrue(node.children.isEmpty)
    }

    // MARK: - Tree Construction Tests

    func testObjectWithChildren() {
        let child1 = JSONNode(type: .string, key: "name", value: "Alice", depth: 1)
        let child2 = JSONNode(type: .number, key: "age", value: 30, depth: 1)

        let parent = JSONNode(
            type: .object,
            children: [child1, child2],
            depth: 0
        )

        XCTAssertEqual(parent.children.count, 2)
        XCTAssertEqual(parent.hasChildren, true)
        XCTAssertEqual(parent.isLeaf, false)
    }

    func testArrayWithChildren() {
        let child1 = JSONNode(type: .number, value: 1, depth: 1)
        let child2 = JSONNode(type: .number, value: 2, depth: 1)

        let array = JSONNode(
            type: .array,
            children: [child1, child2],
            depth: 0
        )

        XCTAssertEqual(array.type, .array)
        XCTAssertEqual(array.children.count, 2)
        XCTAssertTrue(array.hasChildren)
    }

    // MARK: - Path Generation Tests

    func testRootPath() {
        let node = JSONNode(type: .object, depth: 0)
        XCTAssertEqual(node.path, "$")
    }

    func testNestedPath() {
        let child = JSONNode(
            type: .string,
            key: "name",
            value: "John",
            depth: 2,
            path: "$.user.name"
        )

        XCTAssertEqual(child.path, "$.user.name")
    }

    func testArrayPath() {
        let child = JSONNode(
            type: .number,
            value: 42,
            depth: 2,
            path: "$.items[0]"
        )

        XCTAssertEqual(child.path, "$.items[0]")
    }

    // MARK: - Depth Calculation Tests

    func testDepthCalculation() {
        let root = JSONNode(type: .object, depth: 0)
        XCTAssertEqual(root.depth, 0)

        let child = JSONNode(type: .string, depth: 1)
        XCTAssertEqual(child.depth, 1)

        let grandchild = JSONNode(type: .string, depth: 2)
        XCTAssertEqual(grandchild.depth, 2)
    }

    // MARK: - IsLeaf Tests

    func testPrimitivesAreLeafNodes() {
        let stringNode = JSONNode(type: .string, value: "text")
        XCTAssertTrue(stringNode.isLeaf)

        let numberNode = JSONNode(type: .number, value: 42)
        XCTAssertTrue(numberNode.isLeaf)

        let boolNode = JSONNode(type: .boolean, value: true)
        XCTAssertTrue(boolNode.isLeaf)

        let nullNode = JSONNode(type: .null, value: nil)
        XCTAssertTrue(nullNode.isLeaf)
    }

    func testContainersAreNotLeafNodes() {
        let objectWithChildren = JSONNode(
            type: .object,
            children: [JSONNode(type: .string, value: "x")]
        )
        XCTAssertFalse(objectWithChildren.isLeaf)

        let arrayWithChildren = JSONNode(
            type: .array,
            children: [JSONNode(type: .number, value: 1)]
        )
        XCTAssertFalse(arrayWithChildren.isLeaf)
    }

    // MARK: - HasChildren Tests

    func testEmptyObjectHasNoChildren() {
        let emptyObject = JSONNode(type: .object, children: [])
        XCTAssertFalse(emptyObject.hasChildren)
    }

    func testNonEmptyObjectHasChildren() {
        let object = JSONNode(
            type: .object,
            children: [JSONNode(type: .string, key: "key", value: "value", depth: 1)]
        )
        XCTAssertTrue(object.hasChildren)
    }

    func testPrimitiveCannotHaveChildren() {
        let stringNode = JSONNode(type: .string, value: "text")
        XCTAssertFalse(stringNode.hasChildren)

        // Even if we somehow add children (shouldn't happen in practice)
        var mutated = stringNode
        mutated.children = [JSONNode(type: .string, value: "x")]
        // The node type is still primitive, so hasChildren should be false
        XCTAssertFalse(mutated.hasChildren)
    }

    // MARK: - DisplayValue Tests

    func testStringDisplayValue() {
        let node = JSONNode(type: .string, value: "Hello")
        XCTAssertEqual(node.displayValue, "Hello")
    }

    func testNumberDisplayValue() {
        let intNode = JSONNode(type: .number, value: 42)
        XCTAssertEqual(intNode.displayValue, "42")

        let doubleNode = JSONNode(type: .number, value: 3.14)
        XCTAssertEqual(doubleNode.displayValue, "3.14")
    }

    func testBooleanDisplayValue() {
        let trueNode = JSONNode(type: .boolean, value: true)
        XCTAssertEqual(trueNode.displayValue, "true")

        let falseNode = JSONNode(type: .boolean, value: false)
        XCTAssertEqual(falseNode.displayValue, "false")
    }

    func testNullDisplayValue() {
        let nullNode = JSONNode(type: .null, value: nil)
        XCTAssertEqual(nullNode.displayValue, "null")
    }

    func testEmptyObjectDisplayValue() {
        let emptyObject = JSONNode(type: .object, children: [])
        XCTAssertEqual(emptyObject.displayValue, "{}")
    }

    func testEmptyArrayDisplayValue() {
        let emptyArray = JSONNode(type: .array, children: [])
        XCTAssertEqual(emptyArray.displayValue, "[]")
    }

    // MARK: - Expansion Tests

    func testDefaultExpansionShallowNodes() {
        let node = JSONNode(type: .object, depth: 1)
        // Depth < 3 should be expanded by default
        XCTAssertTrue(node.isExpanded)
    }

    func testDefaultExpansionDeepNodes() {
        let node = JSONNode(type: .object, depth: 5)
        // Depth >= 3 should be collapsed by default
        XCTAssertFalse(node.isExpanded)
    }

    func testManualExpansion() {
        let node = JSONNode(type: .object, depth: 5, isExpanded: true)
        XCTAssertTrue(node.isExpanded)

        let collapsed = JSONNode(type: .object, depth: 1, isExpanded: false)
        XCTAssertFalse(collapsed.isExpanded)
    }

    // MARK: - DisplayKey Tests

    func testDisplayKeyForObjectProperty() {
        let node = JSONNode(type: .string, key: "username", value: "john")
        XCTAssertEqual(node.displayKey, "\"username\"")
    }

    func testDisplayKeyForArrayElement() {
        let node = JSONNode(type: .string, value: "item")
        XCTAssertNil(node.displayKey)
    }

    func testDisplayKeyForRoot() {
        let node = JSONNode(type: .object, children: [], depth: 0)
        XCTAssertNil(node.displayKey)
    }
}
