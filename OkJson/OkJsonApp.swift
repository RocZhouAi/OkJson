//  OkJsonApp.swift
//  OkJson
//
//  Main app entry point
//

import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct OkJsonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .commands {
            // Keep standard Edit menu with Copy/Paste
            CommandGroup(replacing: .newItem) {
                Button("Clear Input") {
                    NotificationCenter.default.post(name: .clearInput, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])
            }

            CommandMenu("JSON") {
                Button("Format JSON") {
                    NotificationCenter.default.post(name: .formatJSON, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Minify JSON") {
                    NotificationCenter.default.post(name: .minifyJSON, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])



                Button("Paste JSON") {
                    NotificationCenter.default.post(name: .pasteJSON, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clearInput = Notification.Name("clearInput")
    static let formatJSON = Notification.Name("formatJSON")
    static let minifyJSON = Notification.Name("minifyJSON")

    static let pasteJSON = Notification.Name("pasteJSON")
}

// MARK: - MainTabView

struct MainTabView: View {
    var body: some View {
        TabView {
            FormatterViewWithNotifications()
                .tabItem {
                    Label("Formatter", systemImage: "doc.text")
                }

            ComparatorView()
                .tabItem {
                    Label("Compare", systemImage: "doc.on.doc")
                }

            PreferencesView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - FormatterView with Notifications

struct FormatterViewWithNotifications: View {
    @StateObject private var viewModel = FormatterViewModel()

    var body: some View {
        FormatterView()
            .environmentObject(viewModel)
            .onReceive(NotificationCenter.default.publisher(for: .formatJSON)) { _ in
                viewModel.formatJSON()
            }
            .onReceive(NotificationCenter.default.publisher(for: .minifyJSON)) { _ in
                viewModel.minifyJSON()
            }

            .onReceive(NotificationCenter.default.publisher(for: .pasteJSON)) { _ in
                viewModel.pasteFromClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearInput)) { _ in
                viewModel.clear()
            }
    }
}
