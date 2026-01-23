//  CodeHighlightView.swift
//  OkJson
//
//  Syntax-highlighted JSON display view
//

import SwiftUI

/// Syntax-highlighted JSON code display view
struct CodeHighlightView: View {
    // MARK: - Properties

    /// The formatted JSON to display
    var text: String

    /// Color scheme for syntax highlighting
    var colorScheme: ColorSchemeEnum = .default

    /// Show line numbers
    var showLineNumbers: Bool = false

    /// Font to use
    var font: Font = .system(.body, design: .monospaced)

    // MARK: - Body

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if showLineNumbers {
                HStack(alignment: .top, spacing: 8) {
                    lineNumbersView
                    Divider()
                    codeView
                }
            } else {
                codeView
            }
        }
        .font(font)
    }

    // MARK: - Code View

    private var codeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(textLines.enumerated()), id: \.offset) { _, line in
                highlightedLine(line)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Highlighted Line

    private func highlightedLine(_ line: String) -> Text {
        var text = Text("")  // 修复：从空 Text 开始，而不是 Text(line)
        let components = tokenize(line)

        for component in components {
            let color = colorFor(token: component.type, scheme: colorScheme)
            text = text + Text(component.value).foregroundColor(color)
        }

        return text
    }

    // MARK: - Line Numbers View

    private var lineNumbersView: some View {
        let lines = text.components(separatedBy: "\n")

        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .foregroundColor(.secondary)
                    .font(font)
                    .frame(minWidth: 30)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Text Lines

    private var textLines: [String] {
        text.components(separatedBy: "\n")
    }

    // MARK: - Tokenization

    private struct Token {
        let type: TokenType
        let value: String
    }

    private func tokenize(_ line: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var inString = false
        var escapeNext = false

        for char in line {
            if escapeNext {
                current.append(char)
                escapeNext = false
                continue
            }

            if char == "\\" && inString {
                current.append(char)
                escapeNext = true
                continue
            }

            if char == "\"" {
                if inString {
                    current.append(char)
                    if !current.isEmpty {
                        tokens.append(Token(type: .string, value: current))
                    }
                    current = ""
                    inString = false
                } else {
                    if !current.isEmpty {
                        tokens.append(Token(type: .unknown, value: current))
                    }
                    current = "\""
                    inString = true
                }
                continue
            }

            if inString {
                current.append(char)
                continue
            }

            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(Token(type: .unknown, value: current))
                    current = ""
                }
                tokens.append(Token(type: .whitespace, value: String(char)))
            } else if "{".contains(char) || "}".contains(char) || "[".contains(char) || "]".contains(char) || ":".contains(char) || ",".contains(char) {
                if !current.isEmpty {
                    tokens.append(Token(type: .unknown, value: current))
                    current = ""
                }
                tokens.append(Token(type: .punctuation, value: String(char)))
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(Token(type: .unknown, value: current))
        }

        // Post-process to identify keys, numbers, booleans, null
        return identifyTokens(tokens)
    }

    private func identifyTokens(_ tokens: [Token]) -> [Token] {
        var result: [Token] = []
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            if token.type == .unknown {
                let trimmed = token.value.trimmingCharacters(in: .whitespaces)

                if trimmed == "true" || trimmed == "false" {
                    result.append(Token(type: .boolean, value: token.value))
                } else if trimmed == "null" {
                    result.append(Token(type: .null, value: token.value))
                } else if Double(trimmed) != nil {
                    result.append(Token(type: .number, value: token.value))
                } else if i > 0 && tokens[i-1].type == .punctuation && tokens[i-1].value == ":" {
                    // This is a key value
                    result.append(Token(type: .key, value: token.value))
                } else if trimmed.hasPrefix("\"") {
                    result.append(Token(type: .string, value: token.value))
                } else {
                    result.append(token)
                }
            } else {
                result.append(token)
            }

            i += 1
        }

        return result
    }
}

// MARK: - Preview

#Preview {
    CodeHighlightView(
        text: #"""
        {
            "name": "John Doe",
            "age": 30,
            "active": true,
            "tags": ["admin", "user"]
        }
        """#,
        colorScheme: .default,
        showLineNumbers: true
    )
    .frame(width: 400, height: 300)
}
