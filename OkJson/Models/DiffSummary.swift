//  DiffSummary.swift
//  OkJson
//
//  Aggregate statistics for comparison results
//

import Foundation

/// Aggregate statistics for diff results
struct DiffSummary: Equatable {
    // MARK: - Properties

    /// Keys/indices in right document only
    let additions: Int

    /// Keys/indices in left document only
    let deletions: Int

    /// Same path, different value
    let modifications: Int

    /// No change
    let unchanged: Int

    // MARK: - Initialization

    init(additions: Int = 0, deletions: Int = 0, modifications: Int = 0, unchanged: Int = 0) {
        self.additions = additions
        self.deletions = deletions
        self.modifications = modifications
        self.unchanged = unchanged
    }

    // MARK: - Computed Properties

    /// Total number of changes (excludes unchanged)
    var totalChanges: Int {
        additions + deletions + modifications
    }

    /// Total number of items compared
    var totalItems: Int {
        additions + deletions + modifications + unchanged
    }

    /// Whether there are any changes
    var hasChanges: Bool {
        totalChanges > 0
    }
}
