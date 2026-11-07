import AppKit
import PolishBarCore

/// Reports the frontmost application via NSWorkspace.
struct SystemFocus: FocusProviding {
    func frontmostApp() -> FocusedApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FocusedApp(pid: Int(app.processIdentifier), bundleID: app.bundleIdentifier)
    }
}
