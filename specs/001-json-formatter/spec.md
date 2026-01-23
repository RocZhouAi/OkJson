# Feature Specification: JSON Formatter and Comparison Tool

**Feature Branch**: `001-json-formatter`
**Created**: 2026-01-22
**Status**: Draft
**Input**: User description: "这是一个MacOS的原生工程。创建一个JSON格式化工具。之前每次json 的格式化，都需要到网页 https://www.json.cn/，它有两个问题：第一性能较差，当JSON较大的时候，容易卡死。第二个就是页面显示不够大，不方便对比。帮我创建一个原生的JSON格式化和对比工具。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - JSON Formatting (Priority: P1)

As a developer, I want to paste or import a raw/minified JSON string and have it formatted with proper indentation and syntax highlighting, so that I can quickly read and understand the JSON structure.

**Why this priority**: This is the core pain point - users currently need to visit a web tool that is slow and unresponsive. A native formatter solves the immediate performance problem.

**Independent Test**: Can be fully tested by pasting various JSON strings (valid, invalid, nested, large) and verifying the formatted output is readable and properly indented.

**Acceptance Scenarios**:

1. **Given** the application is open, **When** user pastes a valid JSON string, **Then** the JSON is formatted with 2-space or 4-space indentation (user preference) and displayed with syntax highlighting
2. **Given** a formatted JSON is displayed, **When** user clicks a "Copy" button, **Then** the formatted JSON is copied to clipboard
3. **Given** user pastes an invalid JSON string, **When** the application parses it, **Then** a clear error message indicates the line and position of the syntax error
4. **Given** a large JSON file (1MB+), **When** user opens or pastes it, **Then** the formatting completes within 2 seconds without freezing the interface

---

### User Story 2 - JSON Comparison (Priority: P2)

As a developer, I want to compare two JSON documents side-by-side to see their differences highlighted, so that I can identify changes between API responses, configuration files, or data dumps.

**Why this priority**: The user explicitly mentioned the inability to compare conveniently in web tools due to limited screen space. Side-by-side comparison with diff highlighting is a valuable addition.

**Independent Test**: Can be fully tested by loading two different JSON documents and verifying that additions, deletions, and modifications are clearly highlighted in each panel.

**Acceptance Scenarios**:

1. **Given** two JSON documents are loaded in side-by-side panels, **When** user triggers comparison, **Then** differences are highlighted: additions in green, deletions in red, modifications in yellow
2. **Given** a large comparison result, **When** user views the diff, **Then** both panels support independent scrolling or synchronized scrolling (user preference)
3. **Given** nested JSON objects differ, **When** displaying the diff, **Then** the specific changed fields are highlighted at the path level (e.g., `user.address.city`)

---

### User Story 3 - File Import/Export (Priority: P3)

As a developer, I want to open JSON files directly from disk and save formatted results, so that I don't need to copy-paste content manually.

**Why this priority**: Convenience feature that improves workflow but doesn't block core functionality. Copy-paste works for MVP.

**Independent Test**: Can be fully tested by opening .json files from Finder and using File > Save to write formatted output.

**Acceptance Scenarios**:

1. **Given** the application is open, **When** user double-clicks a .json file in Finder or uses File > Open, **Then** the file content is loaded and formatted
2. **Given** a formatted JSON is displayed, **When** user uses File > Save or Save As, **Then** the JSON is written to disk with proper formatting
3. **Given** user drags a .json file onto the application window, **When** the file is dropped, **Then** the content is loaded and formatted

---

### Edge Cases

- What happens when the JSON contains Unicode characters or escape sequences?
- What happens when the JSON is extremely large (100MB+) - should it stream or reject?
- What happens when two JSON files of different sizes are compared?
- How does the system handle JSON with circular references (though technically invalid)?
- What happens when the clipboard contains non-JSON content?
- What happens when the file path contains special characters or is on a network drive?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: User MUST be able to paste raw JSON text from clipboard into the application
- **FR-002**: Application MUST format JSON with configurable indentation (2 or 4 spaces)
- **FR-003**: Application MUST display formatted JSON with syntax highlighting (different colors for keys, strings, numbers, booleans, null)
- **FR-004**: Application MUST validate JSON syntax and report errors with line/column position
- **FR-005**: Application MUST provide a "Copy to Clipboard" button for the formatted output
- **FR-006**: Application MUST support side-by-side comparison of two JSON documents
- **FR-007**: Application MUST highlight differences between two JSON documents (additions, deletions, modifications)
- **FR-008**: Application MUST support synchronized and independent scrolling modes for comparison panels
- **FR-009**: Application MUST allow opening .json files from disk
- **FR-010**: Application MUST allow saving formatted JSON to disk
- **FR-011**: Application MUST handle large JSON files (up to 10MB) without freezing the interface
- **FR-012**: Application MUST support drag-and-drop of .json files
- **FR-013**: Application MUST collapse and expand nested objects/arrays for better navigation (tree view)
- **FR-014**: Application MUST provide a minify option to compress JSON

### Key Entities

- **JSON Document**: The core data entity representing a parsed JSON structure with metadata (original source, size, parse status)
- **Diff Result**: Represents the comparison outcome between two JSON documents, containing change deltas (additions, deletions, modifications) with path information
- **Parse Error**: Represents syntax validation failures with line number, column position, and contextual message
- **Format Preference**: User settings for indentation size (2/4 spaces), sort keys option, and display theme

## Assumptions

- User has basic familiarity with JSON format
- JSON files being processed are within reasonable size limits (up to 10MB for optimal performance)
- Users primarily work with English content, but Unicode support is expected
- The application is a desktop tool for individual use (no multi-user collaboration features needed)
- Users prefer keyboard shortcuts over mouse interaction when available

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: JSON formatting completes within 2 seconds for files up to 5MB
- **SC-002**: Application remains responsive (UI doesn't freeze) when processing large JSON files
- **SC-003**: Users can successfully format and view JSON without needing an internet connection
- **SC-004**: Side-by-side comparison panels occupy at least 80% of the available screen width
- **SC-005**: Syntax errors are identified and reported with accurate line/column information 100% of the time
- **SC-006**: Users can complete the format-and-copy workflow in under 10 seconds
- **SC-007**: The application uses less than 200MB of memory when idle
