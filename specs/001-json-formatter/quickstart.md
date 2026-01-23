# Quickstart Guide: JSON Formatter and Comparison Tool

**Feature**: 001-json-formatter
**Date**: 2026-01-22
**Audience**: Developers testing the implementation

## Overview

This guide provides hands-on scenarios for validating the JSON Formatter and Comparison Tool implementation. Use these scenarios to verify features work as specified.

---

## Prerequisites

1. macOS 13.0+ installed
2. Xcode 15+ or Swift command-line tools
3. Application built and running

---

## Test Scenarios

### Scenario 1: Format and Validate JSON (P1 - MVP)

**Goal**: Verify core JSON formatting functionality

**Steps**:

1. Launch the application
2. Copy the following minified JSON:
   ```json
   {"name":"John Doe","age":30,"active":true,"tags":["admin","user"],"address":{"city":"NYC","zip":10001}}
   ```
3. Paste into the input area
4. Click "Format" button (or Cmd+Shift+F)

**Expected Result**:
- JSON displays with 2-space indentation
- Keys highlighted in light blue
- Strings highlighted in green
- Numbers highlighted in blue
- Booleans highlighted in orange
- Format is readable with proper line breaks

**Success Criteria**:
- [ ] JSON is formatted correctly
- [ ] Syntax highlighting is visible
- [ ] No errors displayed

---

### Scenario 2: Invalid JSON Error Reporting

**Goal**: Verify error detection and reporting

**Steps**:

1. Paste the following invalid JSON:
   ```json
   {
     "name": "John",
     "age": 30,
     "active": true,
   }
   ```
2. Click "Format"

**Expected Result**:
- Error message displayed
- Error indicates line 4, column 4 (trailing comma)
- Erroneous line is highlighted

**Success Criteria**:
- [ ] Error is detected
- [ ] Line/column position is accurate
- [ ] Error message is understandable

---

### Scenario 3: Compare Two JSON Documents

**Goal**: Verify side-by-side diff functionality

**Steps**:

1. Switch to "Compare" tab
2. In left panel, paste:
   ```json
   {
     "users": [
       {"id": 1, "name": "Alice", "active": true},
       {"id": 2, "name": "Bob", "active": false}
     ]
   }
   ```
3. In right panel, paste:
   ```json
   {
     "users": [
       {"id": 1, "name": "Alice", "active": true},
       {"id": 2, "name": "Robert", "active": true},
       {"id": 3, "name": "Carol", "active": true}
     ]
   }
   ```
4. Click "Compare"

**Expected Result**:
- `$.users[1].name` shows modification: "Bob" → "Robert" (yellow)
- `$.users[1].active` shows modification: false → true (yellow)
- `$.users[2]` shows addition (green in right panel)
- Summary shows: 1 addition, 1 deletion, 2 modifications

**Success Criteria**:
- [ ] All changes detected
- [ ] Correct highlighting colors
- [ ] Summary counts are accurate

---

### Scenario 4: File Open and Save

**Goal**: Verify file I/O operations

**Steps**:

1. Create a test file `test.json` with:
   ```json
   {"format":"test","value":123}
   ```
2. Double-click `test.json` in Finder (or use File > Open)
3. Verify JSON loads and formats
4. Modify indentation setting to 4 spaces
5. Use File > Save As → `test_formatted.json`
6. Open saved file in text editor

**Expected Result**:
- File opens in the application
- JSON is formatted with 4 spaces
- Saved file matches displayed format

**Success Criteria**:
- [ ] File association works
- [ ] Content loads correctly
- [ ] Save produces correctly formatted output

---

### Scenario 5: Large File Performance

**Goal**: Verify performance requirements are met

**Steps**:

1. Generate or download a ~5MB JSON file
2. Open the file in the application
3. Measure time to format
4. Check application responsiveness

**Expected Result**:
- Formatting completes within 2 seconds
- UI remains responsive (no beach ball)
- Memory usage stays below 200MB

**Success Criteria**:
- [ ] Performance target met
- [ ] No UI freezing
- [ ] Memory within limits

---

### Scenario 6: Tree View Navigation

**Goal**: Verify collapsible tree view for large nested structures

**Steps**:

1. Paste a deeply nested JSON:
   ```json
   {
     "level1": {
       "level2": {
         "level3": {
           "level4": {
             "level5": "deep value"
           }
         }
       }
     }
   }
   ```
2. Switch to Tree View (if separate from code view)
3. Click collapse/expand arrows

**Expected Result**:
- Nodes beyond depth 3 are collapsed by default
- Clicking expands/collapses sections
- Indentation shows nesting level

**Success Criteria**:
- [ ] Tree view renders correctly
- [ ] Collapse/expand works
- [ ] Default collapse depth is 3

---

### Scenario 7: Minify JSON

**Goal**: Verify JSON minification

**Steps**:

1. Format a JSON (e.g., from Scenario 1)
2. Click "Minify" button
3. Copy the result

**Expected Result**:
- Output is single line
- All unnecessary whitespace removed
- Valid JSON maintained

**Success Criteria**:
- [ ] Minified output is valid JSON
- [ ] Size is significantly smaller
- [ ] Can be copied to clipboard

---

### Scenario 8: Drag and Drop

**Goal**: Verify drag-drop file loading

**Steps**:

1. Have a `.json` file ready on desktop
2. Drag and drop onto application window
3. Verify JSON loads

**Expected Result**:
- File content loads automatically
- JSON is formatted
- No error messages

**Success Criteria**:
- [ ] Drag-drop works
- [ ] File loads correctly
- [ ] Visual feedback during drag

---

### Scenario 9: Settings Persistence

**Goal**: Verify user preferences are saved

**Steps**:

1. Change settings:
   - Indentation: 4 spaces
   - Sort keys: enabled
   - Color scheme: dark
2. Quit application
3. Relaunch application

**Expected Result**:
- All settings persist across launches

**Success Criteria**:
- [ ] Indentation remembers 4 spaces
- [ ] Sort keys remains enabled
- [ ] Color scheme is dark

---

### Scenario 10: Keyboard Shortcuts

**Goal**: Verify keyboard navigation

**Steps**:

1. Test each shortcut:

| Shortcut | Action |
|----------|--------|
| Cmd+V | Paste from clipboard |
| Cmd+C | Copy formatted output |
| Cmd+Shift+F | Format |
| Cmd+Shift+M | Minify |
| Cmd+O | Open file |
| Cmd+S | Save file |
| Cmd+, | Open preferences |

**Expected Result**:
- All shortcuts work as expected

**Success Criteria**:
- [ ] All shortcuts functional
- [ ] Shortcuts shown in menus
- [ ] No conflicts with system shortcuts

---

## Edge Cases to Test

| Scenario | Input | Expected |
|----------|-------|----------|
| Empty JSON | `{}` | Displays as `{}` |
| Null value | `{"key": null}` | Null highlighted correctly |
| Unicode | `{"emoji": "😀"}` | Displays correctly |
| Large numbers | `{"big": 9007199254740992}` | Preserved accurately |
| Empty array | `{"items": []}` | Displays as `[]` |
| Escaped chars | `{"text": "Line\nBreak"}` | Handles escapes |
| Very long string | 10KB string value | No crash |
| Deep nesting | 50 levels deep | Gracefully handles |

---

## Performance Benchmarks

Run these tests using Instruments or a stopwatch:

| Operation | Target | Actual |
|-----------|--------|--------|
| Parse 1MB JSON | < 0.5s | ___ |
| Format 5MB JSON | < 2s | ___ |
| Diff 2×2MB JSON | < 2s | ___ |
| Idle memory | < 200MB | ___ |
| Launch time | < 3s | ___ |

---

## Accessibility Validation

1. Enable VoiceOver (Cmd+F5)
2. Navigate the interface using Tab
3. Verify all elements have labels
4. Verify tree view is navigable

**Success Criteria**:
- [ ] All buttons have accessibility labels
- [ ] Keyboard navigation works
- [ ] VoiceOver announces changes correctly

---

## Next Steps

After completing all scenarios:
1. Report any failures in the project issue tracker
2. Update test cases in `Tests/` directory
3. Mark feature as complete if all pass
4. Proceed to `/speckit.tasks` for implementation planning
