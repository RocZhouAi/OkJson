# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OkJson is a native macOS JSON formatter app. Pure Swift 5.9+ with AppKit (no SwiftUI), zero external dependencies, built with Swift Package Manager. Targets macOS 13+.

## Commands

```bash
# Build
swift build                    # Debug build
swift build -c release         # Release build
make app                       # Build + create .app bundle + launch

# Test
swift test                     # Run all tests (note: not all currently pass)
swift test --filter JSONParserTests                          # Single test class
swift test --filter JSONParserTests/testValidateValidJSON    # Single test method
make test                      # Tests with coverage

# Lint
swiftlint lint --strict        # Strict check (required before delivery)
swiftlint --fix                # Auto-fix

# Other
make clean                     # Remove .build/, OkJson.app, *.dmg
make package                   # Release build + DMG installer
```

## Architecture

MVVM pattern with pure AppKit:

```
AppDelegate (lifecycle, menus)
  └─ MainWindowController
       └─ AppContainerViewController (root container + footer bar controls)
            └─ MainViewController (NSSplitViewController, manages dynamic columns)
                 └─ FormatterViewController (per column: text input + tree output)
                      └─ UnifiedJsonViewController (custom tree view renderer)

FormatterViewModel ← central state: parsing, formatting, search, file I/O, settings
Services: JSONParser, JSONFormatter, ClipboardService
Core model: IndexedJSONNode (zero-copy byte-indexed JSON representation)
```

Key architectural decisions:
- **Multi-column**: Users add columns with `Cmd+D`; `MainViewController` manages N `FormatterViewController` instances in a split view
- **Zero-copy parsing**: `IndexedJSONNode` stores byte offsets into raw data, avoiding string copies for performance
- **Lazy loading**: Tree nodes with >50 children load on demand
- **Background processing**: Heavy JSON parsing/formatting runs off main thread via `DispatchQueue`

## Code Conventions

- 4-space indentation, 150-char line length warning
- No force-unwrap (`!`) or `try!` in production code
- Prefer `struct`/`enum` over `class`; add `final` to classes that won't be subclassed
- Use `guard` for early returns, `[weak self]` in closures capturing self
- UI updates on main thread only
- Error messages reuse `Constants.ErrorMessages`
- Import order: `Foundation` first, then `AppKit`/`Combine`
- One primary type per file, filename matches type name
- Responses and documentation in Chinese (user preference)

## Current State

- `swift test` is **not fully green** — some tests reference removed/renamed APIs. Report actual results; never claim "all tests pass" without verification.
- Priority order for conflicting instructions: user request > `.specify/memory/constitution.md` > `AGENTS.md` > existing file conventions.
