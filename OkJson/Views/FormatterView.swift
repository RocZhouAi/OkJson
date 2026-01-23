//  FormatterView.swift
//  OkJson
//
//  Main JSON formatter UI
//

import SwiftUI
import AppKit

/// Native NSTextView wrapper for reliable text editing on macOS
struct NativeTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextView

        init(_ parent: NativeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            DispatchQueue.main.async {
                self.parent.text = textView.string
            }
        }
    }
}

/// Main JSON formatting view
struct FormatterView: View {
    @EnvironmentObject private var viewModel: FormatterViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(
                onFormat: { viewModel.formatJSON() },
                onMinify: { viewModel.minifyJSON() },
                onPaste: { viewModel.pasteFromClipboard() },
                onClear: { viewModel.clear() },
                hasFormattedText: viewModel.parsedTree != nil || !viewModel.formattedText.isEmpty,
                isProcessing: viewModel.isProcessing
            )

            Divider()

            // Main content area - 移除 GeometryReader 测试
            HStack(spacing: 1) {
                // Left: Input panel
                VStack(alignment: .leading, spacing: 0) {
                    Text("Input")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    TextEditor(text: $viewModel.inputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 300)
                .background(Color(nsColor: .textBackgroundColor))

                // Divider
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)

                // Right: Output panel
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Output")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Divider()

                    // Output content
                    outputContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private var outputContent: some View {
        if let error = viewModel.parseError {
            ScrollView {
                ErrorView(error: error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } else if let tree = viewModel.parsedTree {
            JSONTreeView(
                rootNode: tree,
                colorScheme: viewModel.preferences.colorScheme
            )
        } else {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Enter or paste JSON to format")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    FormatterView()
        .environmentObject(FormatterViewModel())
        .frame(width: 900, height: 600)
}
