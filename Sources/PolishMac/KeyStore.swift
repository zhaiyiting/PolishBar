import Foundation
import PolishCore

/// Stores the API key in a user-only (0600) file.
///
/// This replaces the keychain for the app: an ad-hoc-signed app's identity
/// changes on every rebuild, so macOS re-prompts for keychain access each time.
/// A 0600 file has equivalent *local* security (only this user can read it) and
/// never prompts.
public enum KeyStore {
    public static var path: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.config/polish/api-key"
    }

    public static func read() -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let value = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    public static func write(_ value: String) throws {
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try value.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    public static func delete() {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Resolution order: environment (`POLISH_API_KEY`) → stored file.
    public static func resolve(environment: [String: String]) -> String? {
        if let env = environment[APIKeyResolver.environmentVariable],
           !env.trimmingCharacters(in: .whitespaces).isEmpty {
            return env
        }
        return read()
    }
}
