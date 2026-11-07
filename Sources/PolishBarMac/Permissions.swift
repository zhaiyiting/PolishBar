import AppKit
import ApplicationServices
import Foundation

/// macOS Accessibility (TCC) trust. Without it, AX reads and CGEvent posting
/// fail silently.
public enum Permissions {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    public static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func executablePath() -> String {
        Bundle.main.executablePath ?? CommandLine.arguments.first ?? "polishbar"
    }

    /// Opens System Settings > Privacy & Security > Accessibility.
    public static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        _ = NSWorkspace.shared.open(url)
    }
}
