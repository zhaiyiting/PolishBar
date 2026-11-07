import AppKit
import Combine
import Foundation
import PolishBarCore
import PolishBarMac

/// View-model backing the menu bar and the settings window.
@MainActor
final class AppModel: ObservableObject {
    @Published var config: Config
    /// Newly typed key in the key sheet, held only until saved.
    @Published var apiKeyInput = ""
    @Published private(set) var hasStoredKey = false
    /// A non-secret hint for display, e.g. "••••1234".
    @Published private(set) var storedKeyHint: String?
    @Published var showAPIKeySheet = false
    @Published var isRunning = false
    @Published var accessibilityTrusted = false
    @Published var statusMessage = "Stopped"
    @Published var logLines: [String] = []

    private var service: PolishBarService?
    private var configSink: AnyCancellable?
    private var saveTask: Task<Void, Never>?
    /// In-memory copy of the stored key, read from disk once (and on explicit
    /// refresh) so we never hit the filesystem on every UI event.
    private var cachedKey: String?
    private static let hintDefaultsKey = "polishbar.apiKeyHint"

    init() {
        config = ConfigStore.load()
        cachedKey = KeyStore.read()
        hasStoredKey = cachedKey != nil
        storedKeyHint = UserDefaults.standard.string(forKey: Self.hintDefaultsKey)
        accessibilityTrusted = Permissions.isTrusted

        // Auto-save config on any change (debounced).
        configSink = $config.dropFirst().sink { [weak self] _ in
            self?.scheduleConfigSave()
        }
    }

    // MARK: - Service

    func refreshSystemState() {
        accessibilityTrusted = Permissions.isTrusted
        cachedKey = KeyStore.read()
        hasStoredKey = cachedKey != nil
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        let key = resolvedKey()
        guard !key.isEmpty else {
            statusMessage = "No API key — set one in Settings"
            return
        }
        let service = PolishBarService(config: config, apiKey: key, log: appendLog)
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

    // MARK: - Config (auto-saved)

    /// Debounced save; restarts the service if it is running so changes apply.
    func scheduleConfigSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.saveConfigNow()
        }
    }

    func saveConfigNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try ConfigStore.save(config)
        } catch {
            appendLog("failed to save config: \(error)")
            return
        }
        if isRunning { restartIfRunning() }
    }

    // MARK: - API key

    func presentAPIKeySheet() {
        apiKeyInput = ""
        showAPIKeySheet = true
    }

    /// Stores the key. Returns false on failure (so the sheet can stay open).
    @discardableResult
    func saveKey() -> Bool {
        let value = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            statusMessage = "Paste your API key first"
            return false
        }
        do {
            try KeyStore.write(value)
        } catch {
            statusMessage = "Could not save key"
            appendLog("failed to save key: \(error)")
            return false
        }
        cachedKey = value
        apiKeyInput = ""
        hasStoredKey = true
        storedKeyHint = Self.hint(for: value)
        UserDefaults.standard.set(storedKeyHint, forKey: Self.hintDefaultsKey)
        statusMessage = "API key saved"
        appendLog("API key saved")
        restartIfRunning()
        return true
    }

    func clearKey() {
        KeyStore.delete()
        cachedKey = nil
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

    // MARK: - Accessibility

    func requestAccessibility() {
        Permissions.request()
        refreshSystemState()
    }

    func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    // MARK: - Internals

    /// Environment (handy when launched from a terminal) → stored file.
    private func resolvedKey() -> String {
        KeyStore.resolve(environment: ProcessInfo.processInfo.environment) ?? cachedKey ?? ""
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
