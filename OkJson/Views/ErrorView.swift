//  ErrorView.swift
//  OkJson
//
//  Parse error display view
//

import SwiftUI

/// Parse error display with line/column indicators
struct ErrorView: View {
    // MARK: - Properties

    /// The parse error to display
    var error: ParseError

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("JSON Parse Error")
                    .font(.headline)
                    .foregroundColor(.red)

                Text(error.message)
                    .font(.body)

                HStack(spacing: 8) {
                    Image(systemName: "location")

                    Text("Line \(error.line), Column \(error.column)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let context = error.context {
                    Divider()

                    Text("Context:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ErrorView(
        error: ParseError(
            message: "Unexpected token",
            line: 4,
            column: 5,
            offset: 30,
            context: "\"active\": true,\n}    \n"
        )
    )
    .frame(width: 400)
}
