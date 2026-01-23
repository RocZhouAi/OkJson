# Research: JSON Formatter and Comparison Tool

**Feature**: 001-json-formatter
**Date**: 2026-01-22
**Status**: Complete

## Overview

This document captures technical research and decisions for the JSON Formatter and Comparison Tool. All technical unknowns from the plan have been resolved.

---

## Decision 1: JSON Parsing Strategy

**Decision**: Use Foundation's `JSONSerialization` with custom error handling wrapper

**Rationale**:
- `JSONSerialization` is built into Foundation, zero external dependencies
- Provides reliable parsing with standard compliance
- Custom wrapper enables precise error location (line/column) reporting
- Codable alternative considered but rejected: requires known types at compile time, less suitable for arbitrary JSON

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| JSONSerialization | Native, fast, no deps | Limited error context | ✅ Chosen |
| Codable | Type-safe, Swift-idiomatic | Requires known types | Rejected |
| Third-party (SwiftyJSON) | Convenient API | External dependency | Rejected |
| Custom parser | Full control | Complex, error-prone | Rejected |

**Implementation Notes**:
- Wrap `JSONSerialization.jsonObject()` with try-catch
- Scan input string to map byte offset to line/column for errors
- Return Result<JSONNode, JSONParseError>

---

## Decision 2: Syntax Highlighting Approach

**Decision**: Custom SwiftUI Text with AttributedString

**Rationale**:
- SwiftUI's `AttributedString` supports rich text formatting natively
- No external text editor dependencies required
- Sufficient for JSON highlighting (keys, strings, numbers, booleans, null)
- Performance acceptable for files up to 10MB with lazy loading

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| AttributedString + Text | Native, SwiftUI | Limited for very large files | ✅ Chosen |
| WKWebView + highlight.js | Full feature set | Heavy, web tech | Rejected |
| Highlightr (SyntaxKit) | Powerful | External dependency | Rejected |
| NSTextView in NSViewRepresentable | Performance | AppKit complexity | Rejected |

**Color Scheme**:
- Keys: #A9B7C6 (light blue/gray)
- Strings: #6A8759 (green)
- Numbers: #6897BB (blue)
- Booleans: #CC7832 (orange)
- Null: #CC7832 (orange)
- Error background: #FFCCCC

---

## Decision 3: Diff Algorithm for JSON Comparison

**Decision**: Recursive value comparison with path tracking

**Rationale**:
- JSON is tree-structured; need structural diff, not line-based
- Path-based diff enables precise field-level highlighting
- Recursive algorithm handles nested objects/arrays naturally
- Order-sensitive for arrays (by design for API responses)

**Algorithm**:
```
compare(value1, value2, path) -> DiffChange[]
  - If types differ: Modification at path
  - If objects: Recurse each key, track additions/removals
  - If arrays: Compare by index, report additions/removals
  - If primitives: Compare values, report modification if different
```

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Recursive comparison | Accurate, path-aware | Custom implementation | ✅ Chosen |
| Google Diff Match Patch | Battle-tested | Line-based, not JSON-aware | Rejected |
| Ordered dictionary diff | Simple | Misses nested changes | Rejected |

**Change Types**:
- `.addition(path, value)`: Key/index present in v2 only
- `.deletion(path, value)`: Key/index present in v1 only
- `.modification(path, oldValue, newValue)`: Same path, different value

---

## Decision 4: Large File Handling Strategy

**Decision**: Chunked loading with lazy rendering

**Rationale**:
- 10MB JSON is ~2-5 million lines; cannot fit entirely in memory for UI
- Parse full document into memory (acceptable for 10MB)
- Render visible viewport only using lazy stack
- Background thread for parsing to keep UI responsive

**Strategy**:
1. Parse JSON on background thread using Task/async-await
2. Build flattened list of renderable nodes with depth info
3. Use `LazyVStack` for tree view rendering
4. Collapse deeply nested sections by default (depth > 3)

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Full parse + lazy render | Simple, fast lookup | Memory use | ✅ Chosen |
| Streaming parser | Low memory | Cannot random access | Rejected |
| Page-based loading | Best for huge files | Complex UX | Rejected |

---

## Decision 5: Tree View Implementation

**Decision**: DisclosureGroup with recursive view

**Rationale**:
- SwiftUI's `DisclosureGroup` provides native expand/collapse
- Recursive view pattern handles arbitrary nesting
- Supports keyboard navigation by default
- Accessibility built-in

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| DisclosureGroup | Native, accessible | Depth limits | ✅ Chosen |
| OutlineGroup (macOS 14+) | More features | Requires macOS 14 | Rejected |
| NSOutlineView | Full feature | AppKit wrapper | Rejected |

---

## Decision 6: File Association and Drag-Drop

**Decision**: Uniform Types (UTType) + FileDocument

**Rationale**:
- `UTType.json` is system-defined for .json files
- `FileDocument` protocol provides automatic document handling
- `.onDrop` modifier for drag-drop into windows
- Enables double-click from Finder

**Implementation**:
```
OkJsonApp: App
├── WindowGroup {
│   └── DocumentGroup(newDocument: JSONDocument.self)
├── Commands(for: .openDocument)
└── Commands(for: .newDocument)
```

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| FileDocument + DocumentGroup | Native document app | Requires macOS 13 | ✅ Chosen |
| Custom file handling | Full control | Manual association | Rejected |

---

## Decision 7: Settings Persistence

**Decision**: @AppStorage property wrappers

**Rationale**:
- Native UserDefaults integration
- SwiftUI-reactive (updates UI on change)
- Simple key-value storage sufficient
- Automatic persistence

**Settings to Store**:
| Key | Type | Default |
|-----|------|---------|
| indentationSize | Int | 2 |
| sortKeys | Bool | false |
| synchronizedScroll | Bool | true |
| colorScheme | String | "default" |
| maxDepth | Int | 3 |

**Alternatives Considered**:
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| @AppStorage | Native, reactive | Simple types only | ✅ Chosen |
| UserDefaults directly | More control | Manual observation | Rejected |
| Codable + File | Complex types | Manual I/O | Rejected |

---

## Decision 8: Code Organization (MVVM)

**Decision**: MVVM with SwiftUI

**Rationale**:
- Clear separation of concerns
- ViewModels testable without UI
- Models as value types (struct) for immutability
- Services layer for business logic

**Architecture**:
```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│    View     │◄────│ ViewModel    │◄────│  Service   │
│ (SwiftUI)   │     │ (Observable) │     │  (Logic)   │
└─────────────┘     └──────────────┘     └────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │    Model     │
                     │  (Struct)    │
                     └──────────────┘
```

**Data Flow**:
- User action → View → ViewModel → Service → Model
- Service returns Result<Model, Error>
- ViewModel publishes @Published properties
- View observes and updates

---

## Open Questions Resolved

| Question | Answer | Source |
|----------|--------|--------|
| How to handle 100MB+ files? | Cap at 10MB with warning; larger files show error message | Performance research |
| Unicode support? | Foundation handles Unicode natively; AttributedString supports | Documentation |
| Circular reference handling? | JSON doesn't allow circular refs; parser will fail naturally | JSON spec |
| Network drive files? | POSIX file I/O handles transparently | Foundation docs |

---

## Dependencies

**External**: None

**System Frameworks**:
- Foundation (JSONSerialization, FileManager, UserDefaults)
- SwiftUI (UI components, @AppStorage)
- Combine (publishers, subscribers - implicitly via SwiftUI)
- AppKit (NSPasteboard for clipboard via bridge)

---

## Performance Targets

Based on research, these targets are achievable:

| Metric | Target | Basis |
|--------|--------|-------|
| Parse 5MB JSON | < 1 second | Foundation benchmark |
| Format 5MB JSON | < 2 seconds | String operations |
| Diff 5MB vs 5MB | < 3 seconds | O(n) traversal |
| Idle memory | < 100MB | Struct-based nodes |
| 10MB file handling | < 5 seconds total | Linear scaling |

---

## Next Steps

Phase 1 artifacts to generate:
1. `data-model.md` - Entity definitions from this research
2. `quickstart.md` - Test scenarios and usage examples
3. `contracts/` - Service API definitions
