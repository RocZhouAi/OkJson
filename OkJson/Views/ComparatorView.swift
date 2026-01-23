//  ComparatorView.swift
//  OkJson
//
//  JSON comparison view (placeholder for Phase 4)
//

import SwiftUI

/// Side-by-side JSON comparison view
struct ComparatorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("JSON Comparison")
                .font(.largeTitle)

            Text("Compare two JSON documents side-by-side")
                .foregroundColor(.secondary)

            Text("This feature will be implemented in Phase 4")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("JSON comparator")
    }
}

#Preview {
    ComparatorView()
}
