//  DiffResult.swift
//  OkJson
//
//  Comparison result between two JSON documents
//

import Foundation

/// Contains comparison results between two JSON documents
struct DiffResult: Identifiable, Equatable {
    // MARK: - Properties

    /// Unique identifier for this diff
    let id = UUID()

    /// Original/left JSON document
    let leftDocument: JSONDocument

    /// Modified/right JSON document
    let rightDocument: JSONDocument

    /// All detected differences
    var changes: [DiffChange]

    /// Aggregate statistics
    var summary: DiffSummary {
        DiffSummary(
            additions: changes.filter { $0.type == .addition }.count,
            deletions: changes.filter { $0.type == .deletion }.count,
            modifications: changes.filter { $0.type == .modification }.count,
            unchanged: 0 // Calculated during comparison
        )
    }

    /// When comparison was performed
    let timestamp: Date

    // MARK: - Initialization

    init(
        leftDocument: JSONDocument,
        rightDocument: JSONDocument,
        changes: [DiffChange] = [],
        timestamp: Date = Date()
    ) {
        self.leftDocument = leftDocument
        self.rightDocument = rightDocument
        self.changes = changes.sorted { $0.path < $1.path }
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Whether there are any changes
    var hasChanges: Bool {
        !changes.isEmpty
    }

    /// Filtered changes by type
    func changes(ofType type: ChangeType) -> [DiffChange] {
        changes.filter { $0.type == type }
    }

    /// Changes at or under a specific path prefix
    func changes(atPath pathPrefix: String) -> [DiffChange] {
        changes.filter { $0.path.hasPrefix(pathPrefix) }
    }
}

// MARK: - Equatable Conformance

extension DiffResult {
    static func == (lhs: DiffResult, rhs: DiffResult) -> Bool {
        lhs.id == rhs.id ||
        (lhs.leftDocument == rhs.leftDocument &&
         rhs.rightDocument == rhs.rightDocument &&
         lhs.changes == rhs.changes)
    }
}

// MARK: - JSONDocument Placeholder

// Note: JSONDocument is referenced here but will be defined separately
// This is a simplified placeholder for compilation
struct JSONDocument: Equatable {
    let id: UUID
    let originalText: String

    init(id: UUID = UUID(), originalText: String = "") {
        self.id = id
        self.originalText = originalText
    }

    static func == (lhs: JSONDocument, rhs: JSONDocument) -> Bool {
        lhs.id == rhs.id
    }
}
