import Foundation
import PolishCore

/// Reads the flat TOML config from `~/.config/polish/config.toml`.
enum ConfigStore {
    static var defaultPath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.config/polish/config.toml"
    }

    static func load(path: String = defaultPath) -> Config {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return .default
        }
        return Config.parse(contents)
    }
}
