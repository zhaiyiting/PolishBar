import Foundation
import PolishCore

/// Reads and writes the flat TOML config at `~/.config/polish/config.toml`.
public enum ConfigStore {
    public static var defaultPath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.config/polish/config.toml"
    }

    public static func load(path: String = defaultPath) -> Config {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return .default
        }
        return Config.parse(contents)
    }

    /// Writes `config` (creating the directory if needed).
    public static func save(_ config: Config, path: String = defaultPath) throws {
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try config.encode().write(toFile: path, atomically: true, encoding: .utf8)
    }
}
