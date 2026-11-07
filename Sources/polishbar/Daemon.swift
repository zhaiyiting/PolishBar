import AppKit
import Foundation
import PolishBarCore
import PolishBarMac

/// CLI bootstrap: loads config/key, starts the shared `PolishBarService`, and runs
/// the AppKit event loop (which delivers the Carbon hotkey events).
final class Daemon {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func run() {
        guard let apiKey = KeyStore.resolve(environment: ProcessInfo.processInfo.environment) else {
            Daemon.log("no API key found — set POLISHBAR_API_KEY or store one (app Settings / ~/.config/polishbar/api-key).")
            exit(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if !Permissions.isTrusted {
            Daemon.log("Accessibility permission is NOT granted; AX/CGEvent calls will fail.")
            Daemon.log("Add this binary under System Settings > Privacy & Security > Accessibility:")
            Daemon.log("  \(Permissions.executablePath())")
            Permissions.request()
        }

        Daemon.writePidFile()

        let service = PolishBarService(config: config, apiKey: apiKey, log: Daemon.log)
        service.start()

        app.run()
        service.stop()
        Daemon.removePidFile()
    }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("[polishbar] \(message)\n".utf8))
    }

    static var pidFilePath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.config/polishbar/polishbar.pid"
    }

    static func writePidFile() {
        let path = pidFilePath
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )
        try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func removePidFile() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }
}
