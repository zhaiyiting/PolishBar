import Foundation
import PolishBarCore

/// Owns the wiring shared by every front-end: the global hotkey and the
/// capture -> transform -> replace controller.
///
/// It does **not** run an event loop — the caller owns that (the CLI daemon
/// uses `NSApplication.run()`; the app uses SwiftUI's run loop). This is the
/// "kernel" that both the CLI and the menu-bar app drive.
public final class PolishBarService {
    public enum Status: Equatable, Sendable {
        case stopped
        case running
        case hotkeyFailed
    }

    public private(set) var status: Status = .stopped
    public var isRunning: Bool { status == .running }

    private let config: Config
    private let apiKey: String
    private let log: (String) -> Void
    private var hotkey: HotkeyManager?

    public init(config: Config, apiKey: String, log: @escaping (String) -> Void = { _ in }) {
        self.config = config
        self.apiKey = apiKey
        self.log = log
    }

    /// Registers the hotkey and starts listening. Returns false if the hotkey
    /// could not be registered.
    @discardableResult
    public func start() -> Bool {
        if status == .running { return true }

        let clipboard = Clipboard()
        let synth = KeystrokeSynthesizer()
        let ax = AXText(clipboard: clipboard, synth: synth, restoreDelayMS: config.clipboardRestoreDelayMS)
        let controller = PolishBarController(
            focus: SystemFocus(),
            capture: ax,
            replacer: ax,
            llm: makePolishBarLLM(config: config, apiKey: apiKey, log: log),
            config: config,
            log: log
        )

        let manager = HotkeyManager {
            Task { _ = await controller.handleHotkey() }
        }
        let registered = manager.register(config.hotkey)
        hotkey = manager

        if registered {
            status = .running
            log("ready — hotkey=\(config.hotkey) provider=\(config.provider) model=\(config.model)")
        } else {
            status = .hotkeyFailed
            log("failed to register hotkey '\(config.hotkey)'")
        }
        return registered
    }

    public func stop() {
        hotkey?.unregister()
        hotkey = nil
        status = .stopped
        log("stopped")
    }
}
