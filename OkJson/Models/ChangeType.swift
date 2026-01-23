//  ChangeType.swift
//  OkJson
//
//  Difference type for JSON comparison
//

import Foundation

/// Kind of difference detected during comparison
enum ChangeType: String, Sendable, Equatable {
    /// Key/index present in right document only
    case addition

    /// Key/index present in left document only
    case deletion

    /// Same path, different value
    case modification

    // MARK: - Display Properties

    /// Display symbol for this change type
    var symbol: String {
        switch self {
        case .addition: return "+"
        case .deletion: return "-"
        case .modification: return "~"
        }
    }

    /// Display name for this change type
    var displayName: String {
        switch self {
        case .addition: return "Addition"
        case .deletion: return "Deletion"
        case .modification: return "Modification"
        }
    }
}
