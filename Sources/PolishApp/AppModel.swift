import AppKit
import Combine
import Foundation
import PolishCore
import PolishMac
import Security

/// View-model backing the menu bar and the settings window.
@MainActor
final class AppModel: ObservableObject {
    @Published var config: Config
    /// Newly typed key, held only until saved. Never prefilled with the stored
    /// secret, so the key isn't sitting in the UI/memory.
    @Published var apiKeyInput = ""
    @Published private(set) var hasStoredKey = false
    /// A non-secret hint for display, e.g. "••••1234".
    @Published private(set) var storedKeyHint: String?
    @Published var isRunning = false
    @Published var accessibilityTrusted = false
    @Published var statusMessage = "Stopped"
    @Published var logLines: [String] = []

    private var service: PolishService?
    private static let hintDefaultsKey = "polish.apiKeyHint"

    init() {
        config = ConfigStore.load()
        hasStoredKey = Keychain.apiKey() != nil
        storedKeyHint = UserDefaults.standard.string(forKey: Self.hintDefaultsKey)
        accessibilityTrusted = Permissions.isTrusted
    }

    // MARK: - Service

    func refreshSystemState() {
        accessibilityTrusted = Permissions.isTrusted
        hasStoredKey = Keychain.apiKey() != nil
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        let key = resolvedKey()
        guard !key.isEmpty else {
            statusMessage = "No API key — store one in Settings"
            return
        }
        let service = PolishService(config: config, apiKey: key, log: appendLog)
        isRunning = service.start()
        self.service = service
        statusMessage = isRunning ? "Running (\(config.hotkey))" : "Hotkey failed"
    }

    func stop() {
        service?.stop()
        service = nil
        isRunning = false
        statusMessage = "Stopped"
    }

    // MARK: - Settings

    func save() {
        do {
            try ConfigStore.save(config)
        } catch {
            appendLog("failed to save config: \(error)")
            statusMessage = "Save failed"
            return
        }
        if !apiKeyInput.isEmpty {
            saveKey()
        }
        statusMessage = "Settings saved"
        appendLog("settings saved")
        restartIfRunning()
    }

    /// Saves the typed key to the keychain. Forgiving: if the field is empty it
    /// just explains what to do rather than being disabled.
    func saveKey() {
        let value = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            statusMessage = "Paste your API key first"
            return
        }
        let status = Keychain.set(apiKey: value)
        guard status == errSecSuccess else {
            statusMessage = "Keychain error \(status)"
            appendLog("keychain error \(status)")
            return
        }
        apiKeyInput = ""
        hasStoredKey = true
        storedKeyHint = Self.hint(for: value)
        UserDefaults.standard.set(storedKeyHint, forKey: Self.hintDefaultsKey)
        statusMessage = "API key saved"
        appendLog("API key saved to keychain")
        restartIfRunning()
    }

    func clearKey() {
        let status = Keychain.set(apiKey: "")
        guard status == errSecSuccess else {
            statusMessage = "Keychain error \(status)"
            appendLog("keychain error \(status)")
            return
        }
        apiKeyInput = ""
        hasStoredKey = false
        storedKeyHint = nil
        UserDefaults.standard.removeObject(forKey: Self.hintDefaultsKey)
        statusMessage = "API key removed"
        appendLog("API key removed")
    }

    private static func hint(for key: String) -> String {
        key.count <= 4 ? "••••" : "••••" + String(key.suffix(4))
    }

    func requestAccessibility() {
        Permissions.request()
        refreshSystemState()
    }

    func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    // MARK: - Internals

    /// Environment (handy when launched from a terminal) → keychain.
    private func resolvedKey() -> String {
        APIKeyResolver.resolve(
            environment: ProcessInfo.processInfo.environment,
            keychain: Keychain.apiKey()
        ) ?? ""
    }

    private func restartIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 200 {
            logLines.removeFirst(logLines.count - 200)
        }
    }
}
