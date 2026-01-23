# Service Contract: ClipboardService

**Service**: `ClipboardService`
**Version**: 1.0.0
**Feature**: 001-json-formatter

## Purpose

Manages clipboard operations for JSON text.

---

## API

### copy(_:)

Copies a string to the system clipboard.

**Input**:
- `text: String` - The text to copy

**Output**: None (async operation)

**Error Handling**:
- Silently fails if clipboard unavailable (logged)

---

### read() -> String?

Reads current clipboard content.

**Input**: None

**Output**:
- `String?` - Clipboard content if text, nil otherwise

**Error Conditions**:
| Condition | Result |
|-----------|--------|
| Clipboard empty | nil |
| Clipboard contains image | nil |
| Clipboard contains text | String |
| Permission denied | nil (logged) |

---

### hasJSON() -> Bool

Checks if clipboard likely contains valid JSON.

**Input**: None

**Output**:
- `Bool` - true if clipboard starts with `{` or `[`

**Implementation**: Simple heuristic, not full validation
