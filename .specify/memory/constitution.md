<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0
- Modified principles: N/A
- Added sections: Principle VI - Requirements Clarification, added to Development Workflow section
- Removed sections: N/A
- Templates requiring updates:
  ✅ plan-template.md - reviewed, constitution check section compatible
  ✅ spec-template.md - reviewed, no hardcoded principles
  ✅ tasks-template.md - reviewed, no constitution conflicts
  ✅ All command files (.claude/commands/speckit.*.md) - reviewed, agent-agnostic language
  ✅ CLAUDE.md - updated with new principle reference
- Follow-up TODOs: None
-->
# OkJson Constitution

## Core Principles

### I. Requirements Clarification (NON-NEGOTIABLE)

When user requirements are unclear, ambiguous, or incomplete, agents MUST analyze and ask clarifying questions BEFORE writing any code.

- Ambiguous requirements MUST trigger clarification questions before implementation
- Open-ended requests MUST be broken down into specific, confirmable options
- Missing edge cases or error handling MUST be explicitly confirmed with user
- User preferences (UI patterns, libraries, approaches) MUST be asked when not specified
- NEVER implement based on assumptions when clarification is feasible

**Rationale**: Implementing unclear requirements leads to wasted effort, rework, and frustration. A few clarification questions upfront save significant downstream time and ensure the delivered solution matches actual user intent.

### II. Swift Native Development

All code MUST use Swift and native macOS frameworks. No cross-platform frameworks or abstraction layers unless explicitly justified.

- Prefer Swift standard library and Foundation over third-party dependencies
- Use SwiftUI for new UI components; AppKit acceptable for legacy compatibility
- Leverage native macOS patterns: bindings, KVO, notifications, Combine
- Async/await preferred over callbacks/closures for asynchronous operations

**Rationale**: Native code provides best performance, smallest bundle size, and most seamless macOS user experience. Cross-platform abstractions inevitably create lowest-common-denominator UX.

### III. Testing Discipline (NON-NEGOTIABLE)

Tests MUST be written before implementation for all non-trivial features.

- Use XCTest for unit and integration tests
- Arrange-Act-Assert (AAA) pattern mandatory for test structure
- All public APIs MUST have unit tests covering:
  - Happy path
  - Error conditions
  - Edge cases (empty, nil, boundary values)
- UI interactions MUST have UI tests when user-facing behavior is non-obvious

**Rationale**: TDD ensures APIs are designed for testability from the start, reduces bugs, and serves as living documentation. Swift's type system works best when testability is considered upfront.

### IV. Memory Safety & Performance

Swift ARC (Automatic Reference Counting) rules MUST be followed strictly.

- [weak self] MUST be used in closures capturing self to avoid retain cycles
- @escaping closures documented with ownership expectations
- Value types (struct, enum) preferred over reference types (class) by default
- Copy-on-write semantics understood when using Copying protocol
- Instruments profiling required before declaring performance "acceptable"

**Rationale**: Memory leaks and retain cycles are common in macOS apps. Swift's value semantics reduce shared mutable state bugs.

### V. Error Handling

Errors MUST be handled explicitly; never crash silently in production.

- Use Swift's Result<Type, Error> or throws for fallible operations
- Custom error types conform to Error and provide localized description
- Never use force unwrap (!) except on IBOutlets and constants guaranteed by framework
- Never use try! outside of tests/demos with clear documentation
- All async failures reported to user with actionable message

**Rationale**: Swift's error handling is explicit at call sites. Silent failures make debugging impossible and damage user trust.

### VI. Code Organization

Project structure follows clear conventions with single responsibility per file.

- One type (struct/class/enum/protocol) per file, named after the type
- File organization: Models/, Views/, ViewModels/, Services/, Utilities/
- MARK comments used to organize extensions within files
- No files exceeding 300 lines; extract when exceeded
- Access control (private/internal/public) explicit; default to internal

**Rationale**: Large files with multiple types are difficult to navigate and understand. Clear organization scales with team size.

## Additional Constraints

### Dependency Management

- Swift Package Manager (SPM) for all dependencies; no CocoaPods or Carthage
- Dependencies audited for: macOS version compatibility, license, maintenance status
- Prefer system frameworks over external packages when functionality overlaps
- Package.swift always defines explicit version constraints (not branch-based)

### macOS Version Targeting

- Minimum deployment target: macOS 13.0 (Ventura) unless business requirement justifies older
- @available checks required when using APIs newer than deployment target
- No conditional compilation (#if) for OS version differences; use runtime checks

### Accessibility

- All UI elements MUST have accessibility labels and hints
- VoiceOver compatibility verified before marking feature complete
- Keyboard navigation supported for all mouse-driven actions
- Dynamic Type respected; no hardcoded font sizes

## Development Workflow

### Code Review Requirements

- All changes reviewed by at least one other developer
- Review checklist: tests pass, accessibility verified, no force-unwrap, error handling complete
- CI MUST pass before merge

### Quality Gates

- Unit test coverage minimum 80% for new code
- All compiler warnings treated as errors
- SwiftLint configured; violations block merge
- Instruments leak check required before release

## Governance

This constitution supersedes all other practices and conventions. Conflicts between this document and external style guides are resolved in favor of this document.

**Amendment Procedure**:
1. Proposed change documented with rationale
2. Team review and approval
3. Version number incremented per semantic versioning
4. All dependent templates updated for consistency
5. Migration plan provided for breaking changes

**Compliance Review**:
- All PRs must verify constitutional compliance
- Violations require explicit justification in PR description
- Complexity beyond principles must be documented in plan.md Complexity Tracking section

**Version**: 1.1.0 | **Ratified**: 2026-01-22 | **Last Amended**: 2026-01-22
