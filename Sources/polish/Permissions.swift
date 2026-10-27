import ApplicationServices
import Foundation

/// macOS Accessibility (TCC) trust. Without it, AX reads and CGEvent posting
/// fail silently.
enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func executablePath() -> String {
        Bundle.main.executablePath ?? CommandLine.arguments.first ?? "polish"
    }
}
