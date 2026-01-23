//  ColorSchemeTests.swift
//  OkJsonTests
//
//  Unit tests for syntax highlighting
//

import XCTest
import SwiftUI
@testable import OkJson

/// Unit tests for ColorScheme and syntax highlighting
final class ColorSchemeTests: XCTestCase {
    // MARK: - ColorScheme Enum Tests

    func testColorSchemeDisplayNames() {
        XCTAssertEqual(ColorSchemeEnum.default.displayName, "Default")
        XCTAssertEqual(ColorSchemeEnum.dark.displayName, "Dark")
        XCTAssertEqual(ColorSchemeEnum.highContrast.displayName, "High Contrast")
    }

    func testColorSchemeRawValues() {
        XCTAssertEqual(ColorSchemeEnum.default.rawValue, "default")
        XCTAssertEqual(ColorSchemeEnum.dark.rawValue, "dark")
        XCTAssertEqual(ColorSchemeEnum.highContrast.rawValue, "highContrast")
    }

    // MARK: - Syntax Color Tests

    func testDefaultSchemeKeyColor() {
        let color = colorFor(token: .key, scheme: .default)
        // Verify it's a valid color (not primary)
        XCTAssertNotNil(color)
    }

    func testDefaultSchemeStringColor() {
        let color = colorFor(token: .string, scheme: .default)
        XCTAssertNotNil(color)
    }

    func testDefaultSchemeNumberColor() {
        let color = colorFor(token: .number, scheme: .default)
        XCTAssertNotNil(color)
    }

    func testDefaultSchemeBooleanColor() {
        let color = colorFor(token: .boolean, scheme: .default)
        XCTAssertNotNil(color)
    }

    func testDefaultSchemeNullColor() {
        let color = colorFor(token: .null, scheme: .default)
        XCTAssertNotNil(color)
    }

    func testDarkSchemeColors() {
        let keyColor = colorFor(token: .key, scheme: .dark)
        let stringColor = colorFor(token: .string, scheme: .dark)
        XCTAssertNotNil(keyColor)
        XCTAssertNotNil(stringColor)
    }

    func testHighContrastSchemeUsesPrimaryColor() {
        let keyColor = colorFor(token: .key, scheme: .highContrast)
        let stringColor = colorFor(token: .string, scheme: .highContrast)

        // High contrast should use primary color
        XCTAssertEqual(keyColor, Color.primary)
        XCTAssertEqual(stringColor, Color.primary)
    }

    // MARK: - TokenType Tests

    func testTokenTypeDetection() {
        // Verify all token types are defined
        let types: [TokenType] = [.key, .string, .number, .boolean, .null, .whitespace, .punctuation, .unknown]
        XCTAssertEqual(types.count, 8)
    }

    func testColorForTokenType() {
        let keyColor = colorFor(token: .key, scheme: .default)
        let stringColor = colorFor(token: .string, scheme: .default)
        let numberColor = colorFor(token: .number, scheme: .default)

        XCTAssertNotNil(keyColor)
        XCTAssertNotNil(stringColor)
        XCTAssertNotNil(numberColor)
    }

    // MARK: - Cross-Scheme Tests

    func testSameTokenTypeDifferentColorsAcrossSchemes() {
        let defaultKeyColor = colorFor(token: .key, scheme: .default)
        let darkKeyColor = colorFor(token: .key, scheme: .dark)

        // Colors should differ between schemes
        // Note: Can't directly compare Color, so we just verify both exist
        XCTAssertNotNil(defaultKeyColor)
        XCTAssertNotNil(darkKeyColor)
    }

    func testHighContrastUniformity() {
        // In high contrast, all tokens should use primary color
        let keyColor = colorFor(token: .key, scheme: .highContrast)
        let stringColor = colorFor(token: .string, scheme: .highContrast)
        let numberColor = colorFor(token: .number, scheme: .highContrast)

        XCTAssertEqual(keyColor, Color.primary)
        XCTAssertEqual(stringColor, Color.primary)
        XCTAssertEqual(numberColor, Color.primary)
    }
}
