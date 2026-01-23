//  ToolbarView.swift
//  OkJson
//
//  Common toolbar with actions
//

import SwiftUI

/// Toolbar with format, minify actions
struct ToolbarView: View {
    // MARK: - Properties

    /// Format action callback
    var onFormat: () -> Void = {}

    /// Minify action callback
    var onMinify: () -> Void = {}

    /// Paste action callback
    var onPaste: () -> Void = {}

    /// Clear action callback
    var onClear: () -> Void = {}

    /// Whether formatted text is available
    var hasFormattedText: Bool = false

    /// Whether processing is in progress
    var isProcessing: Bool = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Format button
            Button(action: onFormat) {
                Label("Format", systemImage: "text.alignleft")
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(isProcessing)

            // Minify button
            Button(action: onMinify) {
                Label("Minify", systemImage: "text.compress")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(isProcessing)

            Divider()
                .frame(height: 20)

            // Paste button
            Button(action: onPaste) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command])
            .disabled(isProcessing)

            Spacer()

            // Clear button
            Button(action: onClear) {
                Label("Clear", systemImage: "trash")
            }
            .disabled(isProcessing)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    ToolbarView(
        hasFormattedText: true,
        isProcessing: false
    )
    .frame(width: 500)
}
