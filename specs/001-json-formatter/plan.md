# Implementation Plan: JSON Formatter and Comparison Tool

**Branch**: `001-json-formatter` | **Date**: 2026-01-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-json-formatter/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a native macOS application for JSON formatting and comparison. The app provides fast, offline JSON parsing/formatting with syntax highlighting, error reporting, and side-by-side diff view. Replaces web-based tools (json.cn) that suffer from performance issues and limited screen space. Key features: paste/format JSON, validate syntax with error locations, side-by-side comparison with diff highlighting, file open/save, drag-and-drop support, and tree view navigation.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: Foundation (JSONSerialization), SwiftUI (UI), Combine (reactive)
**Storage**: User defaults for preferences, file system for JSON documents
**Testing**: XCTest for unit and integration tests
**Target Platform**: macOS 13.0+ (Ventura)
**Project Type**: Single project (macOS app)
**Performance Goals**:
  - Format 5MB JSON within 2 seconds
  - UI responsiveness for files up to 10MB
  - Idle memory < 200MB
**Constraints**:
  - Offline-capable (no network required)
  - Native SwiftUI/AppKit only (no cross-platform)
  - No force unwrap, explicit error handling
**Scale/Scope**:
  - Single-user desktop application
  - Handle JSON files up to 10MB
  - 3 main views: Formatter, Comparison, Settings

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Swift Native Development
- ✅ Uses Swift 5.9+ with SwiftUI for UI
- ✅ Foundation framework for JSON parsing (standard library)
- ✅ Native macOS patterns (Combine, file handlers, drag-drop)
- ✅ No cross-platform frameworks planned

### Principle II: Testing Discipline (NON-NEGOTIABLE)
- ✅ XCTest will be used for all tests
- ✅ TDD approach: tests written before implementation
- ✅ Unit tests for JSON parsing, formatting, diff algorithms
- ✅ UI tests for critical user flows (paste, format, copy)

### Principle III: Memory Safety & Performance
- ✅ Value types (struct) preferred for JSON nodes
- ✅ [weak self] for closure capture in async operations
- ✅ Instruments profiling required before declaring performance acceptable
- ✅ 10MB file size limit with streaming consideration for larger

### Principle IV: Error Handling
- ✅ Result<Type, Error> for parse operations
- ✅ Custom JSONParseError with localized descriptions
- ✅ No force unwrap (except IBOutlets)
- ✅ User-friendly error messages for invalid JSON

### Principle V: Code Organization
- ✅ Models/Views/ViewModels/Services/Utilities structure
- ✅ One type per file
- ✅ MARK comments for organization
- ✅ Access control explicit

### Additional Constraints
- ✅ SPM for dependencies (minimal - only native frameworks)
- ✅ macOS 13.0 minimum target
- ✅ Accessibility labels for all UI elements
- ✅ Keyboard shortcuts supported

**Status**: ✅ ALL GATES PASSED

## Project Structure

### Documentation (this feature)

```text
specs/001-json-formatter/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
OkJson/
├── OkJsonApp.swift           # App entry point
├── Models/
│   ├── JSONDocument.swift    # Parsed JSON with metadata
│   ├── JSONNode.swift        # Tree node for JSON values
│   ├── ParseError.swift      # JSON syntax error details
│   ├── DiffResult.swift      # Comparison result with deltas
│   ├── FormatPreference.swift # User settings
│   └── DiffChange.swift      # Individual diff change (add/remove/modify)
├── ViewModels/
│   ├── FormatterViewModel.swift  # Main formatting logic
│   ├── ComparatorViewModel.swift # Diff logic
│   └── PreferencesViewModel.swift # Settings management
├── Views/
│   ├── FormatterView.swift       # Main formatting UI
│   ├── ComparatorView.swift      # Side-by-side diff UI
│   ├── JSONTreeView.swift        # Collapsible tree view
│   ├── ErrorView.swift           # Error display
│   ├── PreferencesView.swift     # Settings UI
│   └── Components/
│       ├── CodeHighlightView.swift # Syntax highlighting
│       ├── DiffPanelView.swift     # Diff panel
│       └── ToolbarView.swift       # Common toolbar
├── Services/
│   ├── JSONParser.swift       # JSON parsing with error handling
│   ├── JSONFormatter.swift    # Formatting/minifying logic
│   ├── JSONComparator.swift   # Diff algorithm implementation
│   ├── ClipboardService.swift # Clipboard operations
│   └── FileService.swift      # File I/O operations
├── Utilities/
│   ├── ColorScheme.swift      # Syntax highlighting colors
│   ├── Extensions.swift       # Foundation/SwiftUI extensions
│   └── Constants.swift        # App constants
└── Resources/
    ├── Assets.xcassets        # Images, colors
    └── Defaults.plist         # Default preferences
```

**Structure Decision**: Single macOS application with SwiftUI. MVVM architecture for separation of concerns. Models handle data, ViewModels contain business logic, Views display UI. Services layer isolates parsing/formatting/file operations for testability.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | No violations | All constitutional requirements satisfied |

No constitutional violations. The design follows all principles: native Swift, TDD with XCTest, value semantics for JSON nodes, explicit error handling, and clean file organization.
