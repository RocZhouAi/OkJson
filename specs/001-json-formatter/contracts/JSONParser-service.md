# Service Contract: JSONParser

**Service**: `JSONParser`
**Version**: 1.0.0
**Feature**: 001-json-formatter

## Purpose

Parses JSON strings into structured `JSONNode` trees with detailed error reporting.

---

## API

### parse(_:) → Result<JSONNode, JSONParseError>

Parses a JSON string into a JSONNode tree structure.

**Input**:
- `jsonString: String` - The raw JSON text to parse

**Output**:
- `Result<JSONNode, JSONParseError>`
  - Success: Root `JSONNode` of the parsed tree
  - Failure: `JSONParseError` with line, column, and context

**Error Conditions**:
| Error | Condition | HTTP-like Code |
|-------|-----------|----------------|
| invalidSyntax | JSON is malformed | 400 |
| emptyInput | Input string is empty | 400 |
| unsupportedType | Contains unsupported value | 422 |
| tooDeep | Nesting exceeds limit | 413 |

**Example**:

```swift
// Success
let result = parser.parse(`{"name": "John"}`)
// .success(JSONNode(type: .object, children: [...]))

// Failure
let result = parser.parse(`{"name": }`)
// .failure(JSONParseError(line: 1, column: 10, message: "Unexpected token"))
```

**Performance**:
- O(n) where n = input length
- Expected: < 1 second for 5MB input

---

### validate(_:) -> Bool

Quick validation without building full tree.

**Input**:
- `jsonString: String` - The JSON text to validate

**Output**:
- `Bool` - true if valid JSON, false otherwise

**Use Case**: Fast pre-check before expensive operations

---

### getNode(atPath:) -> JSONNode?

Retrieves a node at a specific JSONPath from a parsed document.

**Input**:
- `path: String` - JSONPath expression (e.g., `$.users[0].name`)

**Output**:
- `JSONNode?` - The node if found, nil otherwise

**Error Conditions**: None (returns nil on invalid path)
