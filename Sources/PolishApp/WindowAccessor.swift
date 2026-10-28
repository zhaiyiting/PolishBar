import AppKit
import SwiftUI

/// Forces the hosting window to become key and bring the app forward.
/// Needed because menu-bar (`LSUIElement`) apps often open windows that are
/// not key, so text fields never receive keystrokes.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
