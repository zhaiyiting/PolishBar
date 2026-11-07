/// Flat configuration, loaded from `~/.config/polishbar/config.toml`.
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
    /// Value for the request's `reasoning_effort` field. Nil omits it (provider
    /// default). Command Code expects `"off"` to disable thinking; OpenAI-style
    /// providers expect `"none"`/`"low"`/... The right value depends on the model,
    /// so it is passed through verbatim.
    public var reasoningEffort: String?
    /// When true, the full raw LLM response body is logged (for verifying
    /// thinking/reasoning behaviour).
    public var logRawResponse: Bool

    public init(
        hotkey: String = "cmd+shift+j",
        provider: String = "openai",
        model: String = "gpt-4o-mini",
        baseURL: String = "https://api.openai.com/v1",
        prompt: String = DefaultPrompt.polish,
        captureMode: String = "selection_then_sentence",
        maxSentenceLength: Int = 400,
        clipboardRestoreDelayMS: Int = 250,
        reasoningEffort: String? = nil,
        logRawResponse: Bool = false
    ) {
        self.hotkey = hotkey
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.prompt = prompt
        self.captureMode = captureMode
        self.maxSentenceLength = maxSentenceLength
        self.clipboardRestoreDelayMS = clipboardRestoreDelayMS
        self.reasoningEffort = reasoningEffort
        self.logRawResponse = logRawResponse
    }

    public static let `default` = Config()

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
        case "hotkey": if let v = Self.decodeString(value) { hotkey = v }
        case "provider": if let v = Self.decodeString(value) { provider = v }
        case "model": if let v = Self.decodeString(value) { model = v }
        case "base_url": if let v = Self.decodeString(value) { baseURL = v }
        case "prompt": if let v = Self.decodeString(value) { prompt = v }
        case "capture_mode": if let v = Self.decodeString(value) { captureMode = v }
        case "max_sentence_len": if let v = Int(value) { maxSentenceLength = v }
        case "clipboard_restore_delay_ms": if let v = Int(value) { clipboardRestoreDelayMS = v }
        case "reasoning_effort": if let v = Self.decodeString(value) { reasoningEffort = v }
        case "log_raw_response": if let v = Self.bool(value) { logRawResponse = v }
        default: break
        }
    }

    /// Serializes back into the flat TOML format `parse` reads (round-trippable).
    public func encode() -> String {
        var lines: [String] = []
        func addString(_ key: String, _ value: String) {
            lines.append("\(key) = \(Self.encodeString(value))")
        }
        addString("hotkey", hotkey)
        addString("provider", provider)
        addString("model", model)
        addString("base_url", baseURL)
        addString("prompt", prompt)
        addString("capture_mode", captureMode)
        lines.append("max_sentence_len = \(maxSentenceLength)")
        lines.append("clipboard_restore_delay_ms = \(clipboardRestoreDelayMS)")
        if let reasoningEffort {
            addString("reasoning_effort", reasoningEffort)
        }
        lines.append("log_raw_response = \(logRawResponse ? "true" : "false")")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func decodeString(_ value: String) -> String? {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return nil }
        var result = ""
        var escaped = false
        for character in value.dropFirst().dropLast() {
            if escaped {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func encodeString(_ value: String) -> String {
        var result = "\""
        for character in value {
            switch character {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default: result.append(character)
            }
        }
        return result + "\""
    }

    private static func bool(_ value: String) -> Bool? {
        switch value {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
}

/// Resolves the API key with the documented precedence: environment over storedKey.
public enum APIKeyResolver {
    public static let environmentVariable = "POLISHBAR_API_KEY"
    /// Pre-rename name, still read so existing shells keep working.
    public static let legacyEnvironmentVariable = "POLISH_API_KEY"

    /// Returns the first non-empty environment value, preferring the current
    /// variable name over the legacy one.
    public static func environmentValue(in environment: [String: String]) -> String? {
        for name in [environmentVariable, legacyEnvironmentVariable] {
            if let value = environment[name], !value.trimmed().isEmpty {
                return value
            }
        }
        return nil
    }

    public static func resolve(environment: [String: String], storedKey: String?) -> String? {
        if let env = environmentValue(in: environment) {
            return env
        }
        if let storedKey, !storedKey.trimmed().isEmpty {
            return storedKey
        }
        return nil
    }
}

private func stripComment(_ line: String) -> String {
    var inQuote = false
    var escaped = false
    var result = ""
    for character in line {
        if escaped {
            result.append(character)
            escaped = false
            continue
        }
        if character == "\\" {
            result.append(character)
            escaped = true
            continue
        }
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
