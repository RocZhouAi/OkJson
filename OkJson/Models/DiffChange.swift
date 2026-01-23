//  DiffChange.swift
//  OkJson
//
//  Individual difference detected during JSON comparison
//

import Foundation

/// Individual difference detected during comparison
struct DiffChange: Identifiable, Equatable {
    // MARK: - Properties

    /// Unique identifier
    let id = UUID()

    /// Kind of difference
    let type: ChangeType

    /// JSONPath to changed element (e.g., "$.users[0].name")
    let path: String

    /// Value from left document (nil for additions)
    let oldValue: Any?

    /// Value from right document (nil for deletions)
    let newValue: Any?

    // MARK: - Initialization

    init(type: ChangeType, path: String, oldValue: Any?, newValue: Any?) {
        self.type = type
        self.path = path
        self.oldValue = oldValue
        self.newValue = newValue
    }

    // MARK: - Computed Properties

    /// Formatted display of the change
    var description: String {
        switch type {
        case .addition:
            return "\(type.symbol) \(path): \(valueDisplay(newValue))"
        case .deletion:
            return "\(type.symbol) \(path): \(valueDisplay(oldValue))"
        case .modification:
            return "\(type.symbol) \(path): \(valueDisplay(oldValue)) → \(valueDisplay(newValue))"
        }
    }

    // MARK: - Private Helpers

    private func valueDisplay(_ value: Any?) -> String {
        guard let value = value else { return "nil" }
        if let stringValue = value as? String {
            return "\"\(stringValue)\""
        }
        return "\(value)"
    }
}

// MARK: - Equatable Conformance (Handling Any)

extension DiffChange {
    static func == (lhs: DiffChange, rhs: DiffChange) -> Bool {
        guard lhs.type == rhs.type,
              lhs.path == rhs.path else {
            return false
        }

        // Compare values using string representation
        return lhs.valueDisplay(lhs.oldValue) == rhs.valueDisplay(rhs.oldValue) &&
               lhs.valueDisplay(lhs.newValue) == rhs.valueDisplay(rhs.newValue)
    }
}
