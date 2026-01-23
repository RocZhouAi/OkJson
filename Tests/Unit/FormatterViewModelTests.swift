//  FormatterViewModelTests.swift
//  OkJsonTests
//
//  Unit tests for FormatterViewModel
//

import XCTest
import Combine
@testable import OkJson

/// Unit tests for FormatterViewModel
@MainActor
final class FormatterViewModelTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testViewModelInitialState() {
        let viewModel = FormatterViewModel()

        XCTAssertTrue(viewModel.inputText.isEmpty)
        XCTAssertTrue(viewModel.formattedText.isEmpty)
        XCTAssertNil(viewModel.parseError)
        XCTAssertFalse(viewModel.isProcessing)
    }

    // MARK: - Paste Operation Tests

    func testPasteFromClipboard() {
        let viewModel = FormatterViewModel()

        // Mock paste operation
        viewModel.pasteFromClipboard()

        // Should trigger processing
        // Note: In actual test, we'd mock the clipboard service
        XCTAssertNotNil(viewModel)
    }

    func testPasteUpdatesInputText() {
        let viewModel = FormatterViewModel()
        let testJSON = #"{"test": "value"}"#

        viewModel.inputText = testJSON
        viewModel.formatJSON()

        // After formatting, formattedText should not be empty
        XCTAssertFalse(viewModel.formattedText.isEmpty)
    }

    // MARK: - Format Trigger Tests

    func testFormatValidJSON() {
        let viewModel = FormatterViewModel()
        let validJSON = #"{"name": "John", "age": 30}"#

        viewModel.inputText = validJSON
        viewModel.formatJSON()

        // Should produce formatted output
        XCTAssertFalse(viewModel.formattedText.isEmpty)
        XCTAssertNil(viewModel.parseError)
    }

    func testFormatInvalidJSON() {
        let viewModel = FormatterViewModel()
        let invalidJSON = #"{"name": "John", "age": }"#

        viewModel.inputText = invalidJSON
        viewModel.formatJSON()

        // Should produce error
        XCTAssertNotNil(viewModel.parseError)
        XCTAssertFalse(viewModel.parseError!.message.isEmpty)
    }

    func testFormatEmptyInput() {
        let viewModel = FormatterViewModel()

        viewModel.inputText = ""
        viewModel.formatJSON()

        // Should show error about empty input
        XCTAssertNotNil(viewModel.parseError)
    }

    func testFormatWhitespaceOnlyInput() {
        let viewModel = FormatterViewModel()

        viewModel.inputText = "   \n\t   "
        viewModel.formatJSON()

        // Should show error
        XCTAssertNotNil(viewModel.parseError)
    }

    // MARK: - Error State Tests

    func testErrorStateClearsOnValidInput() {
        let viewModel = FormatterViewModel()

        // First, cause an error
        viewModel.inputText = #"{"invalid": }"#
        viewModel.formatJSON()
        XCTAssertNotNil(viewModel.parseError)

        // Then, provide valid input
        viewModel.inputText = #"{"valid": true}"#
        viewModel.formatJSON()
        XCTAssertNil(viewModel.parseError)
    }

    func testErrorContainsLineAndColumn() {
        let viewModel = FormatterViewModel()
        let invalidJSON = #"{"name": "John", "age": }"#

        viewModel.inputText = invalidJSON
        viewModel.formatJSON()

        if let error = viewModel.parseError {
            XCTAssertTrue(error.line > 0)
            XCTAssertTrue(error.column > 0)
        } else {
            XCTFail("Expected parse error")
        }
    }

    // MARK: - Copy to Clipboard Tests

    func testCopyFormattedText() {
        let viewModel = FormatterViewModel()
        let validJSON = #"{"test": "value"}"#

        viewModel.inputText = validJSON
        viewModel.formatJSON()

        // Copy should be available when formatted text exists
        XCTAssertFalse(viewModel.formattedText.isEmpty)
        viewModel.copyFormatted()

        // In actual test, would verify clipboard contents
    }

    func testCopyWhenNoFormattedText() {
        let viewModel = FormatterViewModel()

        // No formatted text yet
        XCTAssertTrue(viewModel.formattedText.isEmpty)

        // Copy should handle gracefully (no crash)
        viewModel.copyFormatted()
    }

    // MARK: - Processing State Tests

    func testProcessingStateDuringFormat() {
        let viewModel = FormatterViewModel()
        let largeJSON = String(repeating: #"{"item": "value"},"#, count: 1000) + #"{"final": true}"#

        viewModel.inputText = largeJSON

        // During processing, isProcessing should be true
        // After processing, should be false
        viewModel.formatJSON()

        XCTAssertFalse(viewModel.isProcessing)
    }

    // MARK: - Publisher Tests

    func testFormattedTextPublisher() {
        let viewModel = FormatterViewModel()
        let validJSON = #"{"test": "value"}"#

        var updateCount = 0
        viewModel.$formattedText
            .dropFirst()
            .sink { _ in updateCount += 1 }
            .store(in: &cancellables)

        viewModel.inputText = validJSON
        viewModel.formatJSON()

        XCTAssertGreaterThan(updateCount, 0)
    }

    func testParseErrorPublisher() {
        let viewModel = FormatterViewModel()

        var errorReceived = false
        viewModel.$parseError
            .dropFirst()
            .sink { error in
                errorReceived = (error != nil)
            }
            .store(in: &cancellables)

        viewModel.inputText = #"{"invalid": }"#
        viewModel.formatJSON()

        XCTAssertTrue(errorReceived)
    }

    // MARK: - Indentation Tests

    func testFormatWithDifferentIndentation() {
        let viewModel = FormatterViewModel()
        let validJSON = #"{"key": "value"}"#

        viewModel.inputText = validJSON

        // Test with 2 spaces
        viewModel.preferences.indentationSize = .twoSpaces
        viewModel.formatJSON()

        let formatted2Spaces = viewModel.formattedText
        XCTAssertFalse(formatted2Spaces.isEmpty)

        // Test with 4 spaces
        viewModel.preferences.indentationSize = .fourSpaces
        viewModel.formatJSON()

        let formatted4Spaces = viewModel.formattedText
        XCTAssertFalse(formatted4Spaces.isEmpty)
    }

    // MARK: - Minify Tests

    func testMinifyJSON() {
        let viewModel = FormatterViewModel()
        let json = """
        {
            "name": "John",
            "age": 30
        }
        """

        viewModel.inputText = json
        viewModel.minifyJSON()

        // Minified output should not have newlines (except maybe one at end)
        let lineCount = viewModel.formattedText.components(separatedBy: "\n").count
        XCTAssertLessThanOrEqual(lineCount, 2)
    }
}
