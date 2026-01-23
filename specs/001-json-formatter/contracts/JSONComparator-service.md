# Service Contract: JSONComparator

**Service**: `JSONComparator`
**Version**: 1.0.0
**Feature**: 001-json-formatter

## Purpose**

Compares two JSON documents and generates structured diff results.

---

## API

### compare(left:right:) -> DiffResult

Compares two JSONNode trees and identifies all differences.

**Input**:
- `left: JSONNode` - Original JSON document
- `right: JSONNode` - Modified JSON document

**Output**:
- `DiffResult` - Complete comparison result with all changes

**DiffResult Structure**:

```swift
struct DiffResult {
    let id: UUID
    let leftDocument: JSONDocument  // Wrapped left node
    let rightDocument: JSONDocument // Wrapped right node
    let changes: [DiffChange]
    let summary: DiffSummary
    let timestamp: Date
}

struct DiffSummary {
    let additions: Int
    let deletions: Int
    let modifications: Int
    let unchanged: Int
}

struct DiffChange {
    let type: ChangeType    // .addition, .deletion, .modification
    let path: String        // JSONPath to changed element
    let oldValue: Any?      // nil for additions
    let newValue: Any?      // nil for deletions
}
```

**Algorithm Behavior**:

| Scenario | Result |
|----------|--------|
| Same path, same value | No change entry |
| Same path, different value | `.modification` |
| Path only in left | `.deletion` |
| Path only in right | `.addition` |
| Array order difference | Changes at specific indices |
| Different types at path | `.modification` |

**Example**:

```swift
// Left: {"name": "John", "age": 30}
// Right: {"name": "John", "age": 31, "city": "NYC"}

let result = comparator.compare(left: leftNode, right: rightNode)

// Result changes:
// [
//   DiffChange(type: .modification, path: "$.age", oldValue: 30, newValue: 31),
//   DiffChange(type: .addition, path: "$.city", oldValue: nil, newValue: "NYC")
// ]

// Summary: additions=1, deletions=0, modifications=1, unchanged=1
```

**Performance**:
- O(n + m) where n, m = node counts of each document
- Expected: < 3 seconds for 5MB vs 5MB comparison

---

### changesAtPath(_:) -> [DiffChange]

Filters changes to only those at or under a specific path.

**Input**:
- `path: String` - JSONPath prefix to filter by

**Output**:
- `[DiffChange]` - Changes within the specified subtree

**Use Case**: Drilling down into specific sections of large diffs

---

### renderDiff(_:forSide:) -> AttributedString

Renders one side of the diff with change highlighting.

**Input**:
- `result: DiffResult` - The comparison result
- `side: DiffSide` - `.left` or `.right`

**Output**:
- `AttributedString` - JSON with diff highlights

**Highlight Colors**:

| Change Type | Left Color | Right Color |
|-------------|------------|-------------|
| Addition | (not shown) | Green background |
| Deletion | Red background | (not shown) |
| Modification | Yellow background | Yellow background |
