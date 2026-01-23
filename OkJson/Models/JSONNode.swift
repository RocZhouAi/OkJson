//  JSONNode.swift
//  OkJson
//
//  Tree node representing any JSON value
//

import Foundation

/// Tree node representing any JSON value with rendering info
struct JSONNode: Identifiable, Equatable {
    // MARK: - Identifiable

    let id = UUID()

    // MARK: - Properties

    /// Kind of value
    let type: NodeType

    /// Property key (nil for root or array items)
    var key: String?

    /// The actual value (String, Int, Double, Bool, or nil for null)
    let value: Any?

    /// Child nodes (empty for primitives)
    var children: [JSONNode] = []

    /// Nesting level for indentation
    let depth: Int

    /// JSONPath (e.g., "$.users[0].name")
    let path: String

    /// UI state for tree view
    var isExpanded: Bool

    // MARK: - Initialization

    init(
        type: NodeType,
        key: String? = nil,
        value: Any? = nil,
        children: [JSONNode] = [],
        depth: Int = 0,
        path: String = "$",
        isExpanded: Bool? = nil
    ) {
        self.type = type
        self.key = key
        self.value = value
        self.children = children
        self.depth = max(0, depth)
        self.path = path
        // Default expansion: depth < 3, unless explicitly specified
        self.isExpanded = isExpanded ?? (depth < 3)
    }

    // MARK: - Computed Properties

    /// String representation for UI display
    var displayValue: String {
        switch type {
        case .object, .array:
            return children.isEmpty ? (type == .object ? "{}" : "[]") : ""
        case .string:
            return (value as? String) ?? ""
        case .number:
            if let intValue = value as? Int {
                return "\(intValue)"
            } else if let doubleValue = value as? Double {
                // Check if it's a whole number
                if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(Int(doubleValue))"
                }
                return "\(doubleValue)"
            }
            return "0"
        case .boolean:
            return (value as? Bool).map { $0 ? "true" : "false" } ?? "false"
        case .null:
            return "null"
        }
    }

    /// Whether this is a leaf node (no children)
    var isLeaf: Bool {
        type.isPrimitive
    }

    /// Whether this node has children
    var hasChildren: Bool {
        type.isContainer && !children.isEmpty
    }

    /// Key to display (for object properties)
    var displayKey: String? {
        guard let key = key else { return nil }
        return "\"\(key)\""
    }
}

// MARK: - Equatable Conformance (Handling Any)

extension JSONNode {
    static func == (lhs: JSONNode, rhs: JSONNode) -> Bool {
        guard lhs.type == rhs.type,
              lhs.key == rhs.key,
              lhs.depth == rhs.depth,
              lhs.path == rhs.path,
              lhs.children.count == rhs.children.count else {
            return false
        }

        // Compare values
        if !compareValues(lhs.value, rhs.value) {
            return false
        }

        // Compare children recursively
        return zip(lhs.children, rhs.children).allSatisfy { $0 == $1 }
    }

    private static func compareValues(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false

        case (let l as String, let r as String): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Bool, let r as Bool): return l == r

        // Cross-numeric comparison
        case (let l as Int, let r as Double): return Double(l) == r
        case (let l as Double, let r as Int): return l == Double(r)

        default: return String(describing: lhs) == String(describing: rhs)
        }
    }
}
