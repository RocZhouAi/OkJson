# Data Model: JSON Formatter and Comparison Tool

**Feature**: 001-json-formatter
**Date**: 2026-01-22
**Status**: Complete

## Overview

This document defines the core data entities for the JSON Formatter and Comparison Tool. All models use Swift value types (struct) for immutability and thread safety.

---

## Entity Relationships

```
┌────────────────────┐       ┌──────────────────────┐
│   FormatPreference │       │     JSONDocument     │
│   (Settings)       │       └──────────┬───────────┘
└────────────────────┘                  │
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
            ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
            │  JSONNode   │  │  ParseError │  │  DiffResult  │
            │  (Tree)     │  └─────────────┘  └──────┬───────┘
            └─────────────┘                          │
                                                   │
                                         ┌─────────┼─────────┐
                                         ▼         ▼         ▼
                                    ┌─────────────────────────┐
                                    │      DiffChange         │
                                    │  (Add/Remove/Modify)    │
                                    └─────────────────────────┘
```

---

## Core Entities

### JSONDocument

**Purpose**: Represents a parsed JSON document with metadata

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| id | UUID | No | Unique identifier for the document |
| source | DocumentSource | No | Where the JSON came from (clipboard, file, typed) |
| originalText | String | No | Raw input string |
| root | JSONNode | Yes | Parsed root node (nil if parse failed) |
| parseError | ParseError | Yes | Error details if parsing failed |
| size | Int | No | Byte size of original text |
| timestamp | Date | No | When document was created/loaded |

**Validation Rules**:
- `root` and `parseError` are mutually exclusive (one is nil)
- `size` must equal `originalText.utf8.count`
- `originalText` is never empty (use empty object `{}` for blank)

**State Transitions**:

```
[New] → [Parsing] → [Parsed] or [Error]
                     ↓
                 [Formatted] → [Copied] → [Closed]
```

---

### JSONNode

**Purpose**: Tree node representing any JSON value with rendering info

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| type | NodeType | No | Kind of value (object, array, string, number, bool, null) |
| key | String | Yes | Property key (nil for root or array items) |
| value | Any | Yes | The actual value (String, Int, Double, Bool, or nil for null) |
| children | [JSONNode] | No | Child nodes (empty for primitives) |
| depth | Int | No | Nesting level for indentation |
| path | String | No | JSONPath (e.g., `$.users[0].name`) |
| isExpanded | Bool | No | UI state for tree view (default: depth < 3) |

**Nested Types**:

```swift
enum NodeType {
    case object
    case array
    case string
    case number
    case boolean
    case null
}
```

**Validation Rules**:
- `children` is empty for primitive types (string, number, boolean, null)
- `key` is nil only for root node or array elements
- `depth` >= 0 (root is 0)
- `path` follows JSONPath notation

**Computed Properties**:
- `displayValue`: String representation for UI
- `isLeaf`: Bool (true for primitives)
- `hasChildren`: Bool (true for object/array)

---

### ParseError

**Purpose**: Represents JSON syntax error with location

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| message | String | No | Human-readable error description |
| line | Int | No | Line number where error occurred (1-based) |
| column | Int | No | Column position (1-based) |
| offset | Int | No | Byte offset in source string |
| context | String | Yes | Snippet of code around error |

**Validation Rules**:
- `line` >= 1
- `column` >= 1
- `offset` >= 0 and < source length
- `context` is ~40 characters around error position

**Example**:

```json
{
  "name": "John",
  "age": 30,
  "active": true,
}
//           ↑
//      ParseError: Unexpected comma at line 4, column 4
```

---

### DiffResult

**Purpose**: Contains comparison results between two JSON documents

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| id | UUID | No | Unique identifier for this diff |
| leftDocument | JSONDocument | No | Original/left JSON |
| rightDocument | JSONDocument | No | Modified/right JSON |
| changes | [DiffChange] | No | All detected differences |
| summary | DiffSummary | No | Aggregate statistics |
| timestamp | Date | No | When comparison was performed |

**Nested Types**:

```swift
struct DiffSummary {
    let additions: Int      // Keys/indices in right only
    let deletions: Int      // Keys/indices in left only
    let modifications: Int  // Same path, different value
    let unchanged: Int      // No change
}
```

**Validation Rules**:
- `changes` sorted by path for consistent ordering
- Summary counts match change type counts

---

### DiffChange

**Purpose**: Individual difference detected during comparison

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| type | ChangeType | No | Kind of difference |
| path | String | No | JSONPath to changed element |
| oldValue | Any | Yes | Value from left document |
| newValue | Any | Yes | Value from right document |

**Nested Types**:

```swift
enum ChangeType {
    case addition      // In right only
    case deletion      // In left only
    case modification  // Both, different values
}
```

**Validation Rules**:
- `oldValue` is nil for additions
- `newValue` is nil for deletions
- Both values present for modifications

**Examples**:

```javascript
// Addition
{ path: "$.users[2].email", type: .addition, newValue: "new@example.com" }

// Deletion
{ path: "$.users[1]", type: .deletion, oldValue: {...} }

// Modification
{ path: "$.users[0].active", type: .modification, oldValue: false, newValue: true }
```

---

### FormatPreference

**Purpose**: User settings for JSON formatting and display

**Properties**:

| Name | Type | Optional | Description |
|------|------|----------|-------------|
| indentationSize | Indentation | No | 2 or 4 spaces |
| sortKeys | Bool | No | Alphabetically sort object keys |
| synchronizedScroll | Bool | No | Link scroll in comparison view |
| colorScheme | ColorScheme | No | Syntax highlighting theme |
| maxDepth | Int | No | Default collapse depth for tree view |
| showLineNumbers | Bool | No | Display line numbers in code view |

**Nested Types**:

```swift
enum Indentation: Int, CaseIterable {
    case twoSpaces = 2
    case fourSpaces = 4
}

enum ColorScheme: String, CaseIterable {
    case default    // Xcode-like
    case dark       // Dark mode colors
    case highContrast  // Accessibility
}
```

**Validation Rules**:
- `indentationSize` is 2 or 4 only
- `maxDepth` between 1 and 10

**Default Values**:

| Property | Default |
|----------|---------|
| indentationSize | .twoSpaces |
| sortKeys | false |
| synchronizedScroll | true |
| colorScheme | .default |
| maxDepth | 3 |
| showLineNumbers | true |

---

### DocumentSource

**Purpose**: Tracks where JSON content originated

**Definition**:

```swift
enum DocumentSource {
    case clipboard                // Pasted from clipboard
    case file(URL)                // Loaded from disk
    case typed                    // User entered manually
    case dragAndDrop(URL)         // Dropped into window
    case sample                   // Built-in example
}
```

---

## Type Aliases

```swift
typealias JSONPath = String                    // e.g., "$.store.book[0].title"
typealias JSONValue = Any                       // String, Int, Double, Bool, nil
typealias JSONObject = [String: Any]            // JSON object
typealias JSONArray = [Any]                     // JSON array
```

---

## Memory Considerations

**Per-Node Memory**: ~200 bytes (struct overhead)

**Estimated Memory**:
| Document Size | Nodes | Memory |
|---------------|-------|--------|
| 1 KB | ~50 | 10 KB |
| 100 KB | ~5,000 | 1 MB |
| 1 MB | ~50,000 | 10 MB |
| 10 MB | ~500,000 | 100 MB |

**Optimization Strategies**:
- Use `[String: Any]` directly for large objects (lazy parsing)
- Collapse nodes beyond `maxDepth` by default
- Render only visible viewport in UI

---

## Thread Safety

All models are `struct` (value types) → inherently thread-safe.
- No shared mutable state
- Safe to pass between threads
- Combine publishers handle serialization

---

## Serialization

**UserDefaults Storage** (FormatPreference only):
- Use @AppStorage property wrappers
- Keys: `"indentation"`, `"sortKeys"`, `"syncScroll"`, `"colorScheme"`, `"maxDepth"`, `"lineNumbers"`

**File Storage** (JSONDocument):
- Original text stored as-is
- Re-parsed on load for consistency
- Metadata (timestamp, source) stored in extended attributes if needed
