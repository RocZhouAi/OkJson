//  NodeType.swift
//  OkJson
//
//  JSON value type enumeration
//

import Foundation

/// Kind of JSON value
enum NodeType: String, Sendable, Equatable {
    /// JSON object: {"key": value}
    case object

    /// JSON array: [value1, value2]
    case array

    /// JSON string: "text"
    case string

    /// JSON number: 42, 3.14
    case number

    /// JSON boolean: true or false
    case boolean

    /// JSON null: null
    case null

    // MARK: - Computed Properties

    /// Whether this type can have children
    var isContainer: Bool {
        switch self {
        case .object, .array:
            return true
        default:
            return false
        }
    }

    /// Whether this is a primitive type
    var isPrimitive: Bool {
        !isContainer
    }
}
