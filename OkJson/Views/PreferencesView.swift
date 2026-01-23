//  PreferencesView.swift
//  OkJson
//
//  Settings view
//

import SwiftUI

/// Settings and preferences view
struct PreferencesView: View {
    @AppStorage("indentation") private var indentation: Int = 2
    @AppStorage("sortKeys") private var sortKeys: Bool = false
    @AppStorage("syncScroll") private var syncScroll: Bool = true
    @AppStorage("colorScheme") private var colorScheme: String = "default"
    @AppStorage("maxDepth") private var maxDepth: Int = 3
    @AppStorage("lineNumbers") private var lineNumbers: Bool = true

    var body: some View {
        Form {
            Section("Formatting") {
                Picker("Indentation", selection: $indentation) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                }

                Toggle("Sort object keys alphabetically", isOn: $sortKeys)
            }

            Section("Comparison") {
                Toggle("Synchronized scrolling", isOn: $syncScroll)
            }

            Section("Display") {
                Picker("Color scheme", selection: $colorScheme) {
                    Text("Default").tag("default")
                    Text("Dark").tag("dark")
                    Text("High Contrast").tag("highContrast")
                }

                Toggle("Show line numbers", isOn: $lineNumbers)

                Picker("Default collapse depth", selection: $maxDepth) {
                    Text("1 level").tag(1)
                    Text("2 levels").tag(2)
                    Text("3 levels").tag(3)
                    Text("4 levels").tag(4)
                    Text("5 levels").tag(5)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .accessibilityLabel("Preferences")
    }
}

#Preview {
    PreferencesView()
}
