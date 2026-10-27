import AppKit
import Foundation
import PolishCore

/// Wires the concrete macOS implementations and runs the event loop.
final class Daemon {
    private let config: Config
    private let controller: PolishController
    private var hotkey: HotkeyManager?

    init(config: Config) {
        self.config = config
        let clipboard = Clipboard()
        let synth = KeystrokeSynthesizer()
        let ax = AXText(clipboard: clipboard, synth: synth, restoreDelayMS: config.clipboardRestoreDelayMS)
        self.controller = PolishController(
            focus: SystemFocus(),
            capture: ax,
            replacer: ax,
            llm: Daemon.makeLLM(config: config),
            config: config,
            log: Daemon.log
        )
    }

    static func makeLLM(config: Config) -> LLMService {
        if config.provider.lowercased() == "mock" {
            return MockLLMService()
        }
        let key = APIKeyResolver.resolve(
            environment: ProcessInfo.processInfo.environment,
            keychain: Keychain.apiKey()
        ) ?? ""
        return CloudLLMService(config: config, apiKey: key)
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if !Permissions.isTrusted {
            Daemon.log("Accessibility permission is NOT granted; AX/CGEvent calls will fail.")
            Daemon.log("Add this binary under System Settings > Privacy & Security > Accessibility:")
            Daemon.log("  \(Permissions.executablePath())")
            Permissions.request()
        }

        Daemon.writePidFile()

        let controller = self.controller
        let manager = HotkeyManager {
            Task { _ = await controller.handleHotkey() }
        }
        if manager.register(config.hotkey) {
            Daemon.log("ready — hotkey=\(config.hotkey) provider=\(config.provider) mode=\(config.captureMode)")
        } else {
            Daemon.log("failed to register hotkey '\(config.hotkey)'")
        }
        self.hotkey = manager

        app.run()
        Daemon.removePidFile()
    }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("[polish] \(message)\n".utf8))
    }

    static var pidFilePath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.config/polish/polish.pid"
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
