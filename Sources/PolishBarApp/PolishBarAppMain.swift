import AppKit
import SwiftUI

@main
struct PolishBarAppMain: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: MenuBarGlyph.image)
                .opacity(model.isRunning ? 1.0 : 0.55)
        }

        Window("PolishBar Settings", id: "settings") {
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

        Button("Quit PolishBar") { NSApplication.shared.terminate(nil) }
    }
}
