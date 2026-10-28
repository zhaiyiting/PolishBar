import AppKit
import SwiftUI

@main
struct PolishAppMain: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.isRunning ? "text.badge.checkmark" : "text.badge.xmark")
        }

        Window("Polish Settings", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusMessage)

        Divider()

        Button(model.isRunning ? "Stop" : "Start") { model.toggle() }

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }

        Divider()

        Button("Quit Polish") { NSApplication.shared.terminate(nil) }
    }
}
