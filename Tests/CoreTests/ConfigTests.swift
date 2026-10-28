import PolishCore

func runConfigTests() {
    suite("Config")

    do {
        let cfg = Config.parse("""
        hotkey = "cmd+shift+j"
        provider = "openai"
        model = "gpt-4o-mini"
        max_sentence_len = 250
        """)
        equal(cfg.hotkey, "cmd+shift+j", "parses string value")
        equal(cfg.provider, "openai", "parses provider")
        equal(cfg.model, "gpt-4o-mini", "parses model")
        equal(cfg.maxSentenceLength, 250, "parses integer value")
    }

    do {
        let cfg = Config.parse("""
        # a comment
        hotkey = "cmd+j"   # trailing comment

        provider = "mock"
        """)
        equal(cfg.hotkey, "cmd+j", "strips trailing comment")
        equal(cfg.provider, "mock", "ignores blank lines and full-line comments")
    }

    do {
        let cfg = Config.parse("provider = \"openai\"\nunknown_key = \"whatever\"\nnope = 9")
        equal(cfg, Config.default, "ignores unknown keys")
    }

    do {
        let cfg = Config.parse("prompt = \"keep # this\" # drop this")
        equal(cfg.prompt, "keep # this", "hash inside quotes is preserved")
    }

    do {
        let cfg = Config.parse("")
        equal(cfg, Config.default, "empty config yields defaults")
    }

    do {
        let cfg = Config.parse("hotkey = cmd+shift+j")
        equal(cfg.hotkey, Config.default.hotkey, "unquoted value is ignored (keeps default)")
    }

    do {
        equalOptional(Config.parse("reasoning_effort = \"off\"").reasoningEffort, "off", "parses reasoning_effort")
        equalOptional(Config.default.reasoningEffort, nil, "reasoning_effort omitted by default")
    }

    do {
        equal(Config.parse("log_raw_response = true").logRawResponse, true, "parses log_raw_response = true")
        equal(Config.default.logRawResponse, false, "log_raw_response defaults to false")
    }

    suite("API key precedence")

    equalOptional(
        APIKeyResolver.resolve(environment: ["POLISH_API_KEY": "env-key"], keychain: "kc-key"),
        "env-key",
        "environment wins over keychain"
    )
    equalOptional(
        APIKeyResolver.resolve(environment: [:], keychain: "kc-key"),
        "kc-key",
        "falls back to keychain"
    )
    equalOptional(
        APIKeyResolver.resolve(environment: ["POLISH_API_KEY": ""], keychain: "kc-key"),
        "kc-key",
        "empty env var is treated as absent"
    )
    equalOptional(
        APIKeyResolver.resolve(environment: [:], keychain: nil),
        nil,
        "nil when nothing is available"
    )

    suite("Config.encode round-trip")

    do {
        var config = Config.default
        config.hotkey = "ctrl+alt+p"
        config.provider = "commandcode"
        config.model = "deepseek-v4-flash"
        config.baseURL = "https://api.example.com/v1"
        config.prompt = "line one\nline \"two\" with \\ backslash and # hash"
        config.maxSentenceLength = 123
        config.clipboardRestoreDelayMS = 42
        config.reasoningEffort = "off"
        config.logRawResponse = true

        let encoded = config.encode()
        equal(Config.parse(encoded), config, "encode -> parse round-trips all fields")
    }

    do {
        let encoded = Config.default.encode()
        check(encoded.contains("log_raw_response = false"), "encodes booleans unquoted")
        check(!encoded.contains("reasoning_effort"), "omits nil reasoning_effort")
        equal(Config.parse(encoded), Config.default, "default round-trips")
    }
}
