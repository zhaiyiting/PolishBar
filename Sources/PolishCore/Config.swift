/// Flat configuration, loaded from `~/.config/polish/config.toml`.
///
/// Only flat `key = value` lines are supported (string values must be
/// double-quoted). Unknown keys, comments and blank lines are ignored.
public struct Config: Equatable, Sendable {
    public var hotkey: String
    public var provider: String
    public var model: String
    public var baseURL: String
    public var prompt: String
    public var captureMode: String
    public var maxSentenceLength: Int
    public var clipboardRestoreDelayMS: Int

    public init(
        hotkey: String = "cmd+shift+j",
        provider: String = "mock",
        model: String = "gpt-4o-mini",
        baseURL: String = "https://api.openai.com/v1",
        prompt: String = "Rewrite the following text to be clear and concise. Reply with only the rewritten text.",
        captureMode: String = "selection_then_sentence",
        maxSentenceLength: Int = 400,
        clipboardRestoreDelayMS: Int = 250
    ) {
        self.hotkey = hotkey
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.prompt = prompt
        self.captureMode = captureMode
        self.maxSentenceLength = maxSentenceLength
        self.clipboardRestoreDelayMS = clipboardRestoreDelayMS
    }

    public static let `default` = Config()

    /// A real backend is requested (i.e. not the mock).
    public var needsAPIKey: Bool { provider.lowercased() != "mock" }

    public static func parse(_ contents: String) -> Config {
        var config = Config.default
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(String(rawLine)).trimmed()
            if line.isEmpty { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eq]).trimmed()
            let value = String(line[line.index(after: eq)...]).trimmed()
            config.apply(key: key, value: value)
        }
        return config
    }

    private mutating func apply(key: String, value: String) {
        switch key {
        case "hotkey": if let v = Self.quotedString(value) { hotkey = v }
        case "provider": if let v = Self.quotedString(value) { provider = v }
        case "model": if let v = Self.quotedString(value) { model = v }
        case "base_url": if let v = Self.quotedString(value) { baseURL = v }
        case "prompt": if let v = Self.quotedString(value) { prompt = v }
        case "capture_mode": if let v = Self.quotedString(value) { captureMode = v }
        case "max_sentence_len": if let v = Int(value) { maxSentenceLength = v }
        case "clipboard_restore_delay_ms": if let v = Int(value) { clipboardRestoreDelayMS = v }
        default: break
        }
    }

    private static func quotedString(_ value: String) -> String? {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return nil }
        return String(value.dropFirst().dropLast())
    }
}

/// Resolves the API key with the documented precedence: environment over keychain.
public enum APIKeyResolver {
    public static let environmentVariable = "POLISH_API_KEY"

    public static func resolve(environment: [String: String], keychain: String?) -> String? {
        if let env = environment[environmentVariable], !env.trimmed().isEmpty {
            return env
        }
        if let keychain, !keychain.trimmed().isEmpty {
            return keychain
        }
        return nil
    }
}

private func stripComment(_ line: String) -> String {
    var inQuote = false
    var result = ""
    for character in line {
        if character == "\"" {
            inQuote.toggle()
            result.append(character)
            continue
        }
        if character == "#" && !inQuote { break }
        result.append(character)
    }
    return result
}

extension String {
    func trimmed() -> String {
        let chars = Array(self)
        var lower = 0
        var upper = chars.count
        while lower < upper, chars[lower].isWhitespace { lower += 1 }
        while upper > lower, chars[upper - 1].isWhitespace { upper -= 1 }
        return String(chars[lower..<upper])
    }
}
