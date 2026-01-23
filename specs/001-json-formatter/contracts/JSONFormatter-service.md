# Service Contract: JSONFormatter

**Service**: `JSONFormatter`
**Version**: 1.0.0
**Feature**: 001-json-formatter

## Purpose

Formats JSON nodes into pretty-printed or minified strings with configurable options.

---

## API

### format(_:options:) -> String

Converts a JSONNode tree to a formatted JSON string.

**Input**:
- `node: JSONNode` - The root node to format
- `options: FormatOptions` - Formatting preferences

**Output**:
- `String` - Pretty-printed JSON

**FormatOptions**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| indentation | Int | 2 | Spaces per level |
| sortKeys | Bool | false | Alphabetically sort object keys |
| trailingComma | Bool | false | Allow trailing commas |

**Example**:

```swift
let formatted = formatter.format(node, options: FormatOptions(indentation: 2, sortKeys: false))
// Returns:
// {
//   "name": "John",
//   "age": 30
// }
```

---

### minify(_:) -> String

Compresses JSON by removing all unnecessary whitespace.

**Input**:
- `node: JSONNode` - The root node to minify

**Output**:
- `String` - Minified JSON (single line)

**Example**:

```swift
let minified = formatter.minify(node)
// Returns: `{"name":"John","age":30}`
```

**Performance**: O(n) where n = node count

---

### highlight(_:colors:) -> AttributedString

Creates syntax-highlighted attributed string for display.

**Input**:
- `node: JSONNode` - The node to highlight
- `colors: ColorScheme` - Color palette for highlighting

**Output**:
- `AttributedString` - JSON text with color attributes

**ColorScheme Attributes**:

| Token | Attribute | Color (default) |
|-------|-----------|-----------------|
| Key | .foregroundColor | #A9B7C6 |
| String | .foregroundColor | #6A8759 |
| Number | .foregroundColor | #6897BB |
| Boolean | .foregroundColor | #CC7832 |
| Null | .foregroundColor | #CC7832 |
| Error | .backgroundColor | #FFCCCC |
