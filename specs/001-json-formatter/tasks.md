---

description: "Task list for JSON Formatter and Comparison Tool implementation"
---

# Tasks: JSON Formatter and Comparison Tool

**Input**: Design documents from `/specs/001-json-formatter/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: This project follows TDD as per constitution requirement. Test tasks are included for all core functionality.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single macOS app project**: `OkJson/` at repository root
- Structure: Models/, ViewModels/, Views/, Services/, Utilities/, Resources/

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create macOS app project using Xcode or swift package with OkJson/ directory structure
- [X] T002 Create directory structure: Models/, ViewModels/, Views/, Services/, Utilities/, Resources/
- [X] T003 [P] Create Assets.xcassets in Resources/ with app icon and color sets
- [X] T004 [P] Create Defaults.plist in Resources/ with default preference values
- [X] T005 [P] Create Constants.swift in Utilities/ with app-wide constants
- [X] T006 Configure project for macOS 13.0 deployment target
- [X] T007 [P] Configure SwiftLint with .swiftlint.yml enforcing no force-unwrap and explicit type handling
- [X] T008 [P] Create test target structure: Tests/Unit/, Tests/Integration/, Tests/UI/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T009 [P] [US1] Create ParseError.swift model in OkJson/Models/ with message, line, column, offset, context properties
- [X] T010 [P] [US1] Create NodeType enum in OkJson/Models/ with object, array, string, number, boolean, null cases
- [X] T011 [P] [US1] Create DocumentSource enum in OkJson/Models/ with clipboard, file, typed, dragAndDrop, sample cases
- [X] T012 Create JSONNode.swift model in OkJson/Models/ with type, key, value, children, depth, path, isExpanded properties
- [X] T013 [P] [US1] Create ChangeType enum in OkJson/Models/ with addition, deletion, modification cases
- [X] T014 [P] [US1] Create DiffChange.swift model in OkJson/Models/ with type, path, oldValue, newValue properties
- [X] T015 Create JSONDocument.swift model in OkJson/Models/ with id, source, originalText, root, parseError, size, timestamp properties
- [X] T016 [P] [US1] Create DiffSummary struct in OkJson/Models/ with additions, deletions, modifications, unchanged properties
- [X] T017 Create DiffResult.swift model in OkJson/Models/ with id, leftDocument, rightDocument, changes, summary, timestamp properties
- [X] T018 [P] [US1] Create Indentation enum in OkJson/Models/ with twoSpaces=2, fourSpaces=4 cases
- [X] T019 [P] [US1] Create ColorScheme enum in OkJson/Models/ with default, dark, highContrast cases
- [X] T020 Create FormatPreference.swift model in OkJson/Models/ with indentationSize, sortKeys, synchronizedScroll, colorScheme, maxDepth, showLineNumbers properties
- [X] T021 Create ColorScheme utility in OkJson/Utilities/ColorScheme.swift with syntax highlighting color definitions
- [X] T022 Create Foundation/SwiftUI extensions in OkJson/Utilities/Extensions.swift (String JSONPath, AttributedString helpers)
- [X] T023 Create OkJsonApp.swift app entry point in OkJson/ with WindowGroup setup

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - JSON Formatting (Priority: P1) 🎯 MVP

**Goal**: Enable users to paste, format, validate, and copy JSON with syntax highlighting and error reporting

**Independent Test**: Paste various JSON strings (valid, invalid, nested, large) and verify formatted output is readable, properly indented, and syntax highlighted

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T024 [P] [US1] Write JSONParser tests in Tests/Unit/JSONParserTests.swift covering valid JSON, invalid JSON with error location, empty input, Unicode characters
- [X] T025 [P] [US1] Write JSONFormatter tests in Tests/Unit/JSONFormatterTests.swift covering format with 2/4 space indentation, sort keys option, minify
- [X] T026 [P] [US1] Write JSONNode tests in Tests/Unit/JSONNodeTests.swift covering tree construction, path generation, depth calculation, isLeaf logic
- [X] T027 [P] [US1] Write syntax highlighting tests in Tests/Unit/ColorSchemeTests.swift covering token type detection and color application
- [X] T028 [US1] Write FormatterViewModel tests in Tests/Unit/FormatterViewModelTests.swift covering paste operation, format trigger, error state, copy to clipboard

### Implementation for User Story 1

- [X] T029 [P] [US1] Create JSONParser service in OkJson/Services/JSONParser.swift with parse(_:) returning Result<JSONNode, ParseError>
- [X] T030 [P] [US1] Create validate(_:) method in OkJson/Services/JSONParser.swift for quick validation
- [X] T031 [US1] Create getNode(atPath:) method in OkJson/Services/JSONParser.swift for path-based node retrieval
- [X] T032 [P] [US1] Create JSONFormatter service in OkJson/Services/JSONFormatter.swift with format(_:options:) method
- [X] T033 [P] [US1] Create minify(_:) method in OkJson/Services/JSONFormatter.swift for JSON compression
- [X] T034 [US1] Create highlight(_:colors:) method in OkJson/Services/JSONFormatter.swift returning AttributedString
- [X] T035 [P] [US1] Create ClipboardService in OkJson/Services/ClipboardService.swift with copy(_:) and read() methods
- [X] T036 [P] [US1] Create hasJSON() method in OkJson/Services/ClipboardService.swift for clipboard content detection
- [X] T037 [US1] Create FormatterViewModel in OkJson/ViewModels/FormatterViewModel.swift with @Published inputText, formattedText, parseError properties
- [X] T038 [US1] Implement formatJSON() method in OkJson/ViewModels/FormatterViewModel.swift using JSONParser and JSONFormatter services
- [X] T039 [US1] Implement copyFormatted() method in OkJson/ViewModels/FormatterViewModel.swift using ClipboardService
- [X] T040 [US1] Implement pasteFromClipboard() method in OkJson/ViewModels/FormatterViewModel.swift using ClipboardService
- [X] T041 [P] [US1] Create CodeHighlightView in OkJson/Views/Components/CodeHighlightView.swift for syntax-highlighted JSON display
- [X] T042 [P] [US1] Create ErrorView in OkJson/Views/ErrorView.swift for parse error display with line/column indicators
- [X] T043 [US1] Create ToolbarView in OkJson/Views/Components/ToolbarView.swift with Format, Minify, Copy buttons and keyboard shortcuts
- [X] T044 [US1] Create FormatterView in OkJson/Views/FormatterView.swift as main formatting UI with TextEditor, CodeHighlightView, ErrorView, ToolbarView
- [X] T045 [US1] Add accessibility labels to FormatterView in OkJson/Views/FormatterView.swift for all interactive elements
- [X] T046 [US1] Wire FormatterView to FormatterViewModel in OkJson/Views/FormatterView.swift with bindings

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently - users can paste JSON, see it formatted with syntax highlighting, get error feedback, and copy results

---

## Phase 4: User Story 2 - JSON Comparison (Priority: P2)

**Goal**: Enable side-by-side JSON comparison with diff highlighting (additions green, deletions red, modifications yellow)

**Independent Test**: Load two different JSON documents and verify additions, deletions, and modifications are clearly highlighted in each panel

### Tests for User Story 2

- [ ] T047 [P] [US2] Write JSONComparator tests in Tests/Unit/JSONComparatorTests.swift covering addition detection, deletion detection, modification detection, array index changes, nested object diffs
- [ ] T048 [P] [US2] Write DiffResult tests in Tests/Unit/DiffResultTests.swift covering summary calculation, change sorting by path
- [ ] T049 [US2] Write ComparatorViewModel tests in Tests/Unit/ComparatorViewModelTests.swift covering two-document loading, comparison trigger, synchronized scrolling state

### Implementation for User Story 2

- [ ] T050 [P] [US2] Create JSONComparator service in OkJson/Services/JSONComparator.swift with compare(left:right:) returning DiffResult
- [ ] T051 [US2] Implement recursive comparison algorithm in OkJson/Services/JSONComparator.swift for object, array, and primitive value comparison
- [ ] T052 [US2] Create changesAtPath(_:) method in OkJson/Services/JSONComparator.swift for filtering changes by path prefix
- [ ] T053 [US2] Create renderDiff(_:forSide:) method in OkJson/Services/JSONComparator.swift returning highlighted AttributedString
- [ ] T054 [US2] Create ComparatorViewModel in OkJson/ViewModels/ComparatorViewModel.swift with @Published leftText, rightText, diffResult, synchronizedScroll properties
- [ ] T055 [US2] Implement compare() method in OkJson/ViewModels/ComparatorViewModel.swift using JSONComparator service
- [ ] T056 [US2] Implement toggleSynchronizedScroll() method in OkJson/ViewModels/ComparatorViewModel.swift for scroll mode switching
- [ ] T057 [P] [US2] Create DiffPanelView in OkJson/Views/Components/DiffPanelView.swift for single diff panel with highlighting
- [ ] T058 [US2] Create ComparatorView in OkJson/Views/ComparatorView.swift with side-by-side DiffPanelViews, synchronized scrolling
- [ ] T059 [US2] Add diff summary bar to ComparatorView in OkJson/Views/ComparatorView.swift showing additions/deletions/modifications count
- [ ] T060 [US2] Add accessibility labels to ComparatorView in OkJson/Views/ComparatorView.swift for diff navigation

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - File Import/Export (Priority: P3)

**Goal**: Enable opening .json files from disk, saving formatted results, and drag-and-drop file loading

**Independent Test**: Open .json files from Finder and use File > Save to write formatted output

### Tests for User Story 3

- [ ] T061 [P] [US3] Write FileService tests in Tests/Unit/FileServiceTests.swift covering successful load, file not found, permission denied, encoding error, file too large, network drive rejection
- [ ] T062 [P] [US3] Write FileService save tests in Tests/Unit/FileServiceTests.swift covering successful save, disk full, permission denied, invalid path
- [ ] T063 [US3] Write drag-drop integration tests in Tests/UI/DragDropUITests.swift covering .json file drop onto window

### Implementation for User Story 3

- [ ] T064 [P] [US3] Create FileService in OkJson/Services/FileService.swift with load(url:) returning Result<String, FileError>
- [ ] T065 [P] [US3] Create save(_:url:) method in OkJson/Services/FileService.swift returning Result<Void, FileError>
- [ ] T066 [P] [US3] Create validate(url:) method in OkJson/Services/FileService.swift for URL validation
- [ ] T067 [P] [US3] Create file_size(url:) method in OkJson/Services/FileService.swift for pre-load size checking
- [ ] T068 [US3] Create FileError enum in OkJson/Services/FileService.swift with notFound, permissionDenied, encodingError, tooLarge, networkDrive cases
- [ ] T069 [US3] Update OkJsonApp.swift in OkJson/ to support .json file association using UTType
- [ ] T070 [US3] Update FormatterViewModel in OkJson/ViewModels/FormatterViewModel.swift with loadFromFile(url:) method using FileService
- [ ] T071 [US3] Update FormatterViewModel in OkJson/ViewModels/FormatterViewModel.swift with saveToFile(url:) method using FileService
- [ ] T072 [US3] Add .onDrop modifier to FormatterView in OkJson/Views/FormatterView.swift for drag-drop file handling
- [ ] T073 [US3] Add File > Open menu command with Cmd+O shortcut to OkJsonApp.swift in OkJson/
- [ ] T074 [US3] Add File > Save As menu command with Cmd+Shift+S shortcut to OkJsonApp.swift in OkJson/
- [ ] T075 [US3] Add accessibility labels for file operations in OkJson/Views/FormatterView.swift

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T076 [P] Create JSONTreeView in OkJson/Views/JSONTreeView.swift using DisclosureGroup for collapsible tree navigation
- [ ] T077 [P] Create PreferencesView in OkJson/Views/PreferencesView.swift with @AppStorage bindings for indentation, sortKeys, colorScheme, maxDepth, showLineNumbers
- [ ] T078 [P] Create PreferencesViewModel in OkJson/ViewModels/PreferencesViewModel.swift for settings management
- [ ] T079 Add TabView to main window in OkJson/Views/MainTabView.swift with Formatter, Compare, Settings tabs
- [ ] T080 [P] Add keyboard shortcuts (Cmd+Shift+F format, Cmd+Shift+M minify, Cmd+C copy) to ToolbarView in OkJson/Views/Components/ToolbarView.swift
- [ ] T081 Implement large file handling with background Task in FormatterViewModel in OkJson/ViewModels/FormatterViewModel.swift using async/await
- [ ] T082 Add 10MB file size limit warning to FileService in OkJson/Services/FileService.swift with user alert
- [ ] T083 [P] Create sample JSON files for testing in Resources/Samples/ directory (simple.json, nested.json, large.json, invalid.json)
- [ ] T084 Add VoiceOver support to all views in OkJson/Views/ with accessibilityLabel and accessibilityHint
- [ ] T085 Add Dynamic Type support to code views in OkJson/Views/Components/CodeHighlightView.swift using .font(.system(size:))
- [ ] T086 Run Instruments leak check on all ViewModels in OkJson/ViewModels/ and verify [weak self] usage
- [ ] T087 Run quickstart.md validation and ensure all 10 test scenarios pass
- [ ] T088 Update README.md with usage instructions, keyboard shortcuts, and feature overview
- [ ] T089 Create app icon and update Assets.xcassets in OkJson/Resources/
- [ ] T090 Code cleanup: ensure MARK comments in all files, verify line counts under 300, verify access control is explicit

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Shares JSONDocument, JSONNode models from US1 but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Integrates with FormatterView from US1 but file operations independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Models before services
- Services before ViewModels
- ViewModels before Views
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks (T002-T008) can run in parallel
- All Foundational model tasks (T009-T011, T013-T014, T018-T019) can run in parallel
- All test tasks for a story marked [P] can run in parallel
- Service implementations marked [P] can run in parallel (no shared files)
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
T024: JSONParser tests
T025: JSONFormatter tests
T026: JSONNode tests
T027: Syntax highlighting tests
T028: FormatterViewModel tests

# Launch all service implementations together:
T029: JSONParser.parse
T030: JSONParser.validate
T032: JSONFormatter.format
T033: JSONFormatter.minify
T034: JSONFormatter.highlight
T035: ClipboardService.copy
T036: ClipboardService.hasJSON

# Launch view component creation together:
T041: CodeHighlightView
T042: ErrorView
T043: ToolbarView
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

**MVP Deliverable**: A working JSON formatter where users can paste JSON, see it formatted with syntax highlighting, get error feedback, and copy results. This alone solves the primary pain point of slow web tools.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Complete Phase 6: Polish → Final release

Each story adds value without breaking previous stories.

---

## Notes

- [P] tasks = different files, no dependencies
- [US1], [US2], [US3] labels map task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- TDD is NON-NEGOTIABLE per constitution - tests must exist before implementation
- All code must pass SwiftLint with no force-unwrap violations
- Memory safety: use [weak self] in all closure captures
- Error handling: use Result<Type, Error> for all fallible operations
