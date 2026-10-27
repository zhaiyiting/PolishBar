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
        let cfg = Config.parse("provider = \"mock\"\nunknown_key = \"whatever\"\nnope = 9")
        equal(cfg, Config(provider: "mock"), "ignores unknown keys")
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

    check(Config.default.needsAPIKey == false, "mock provider needs no key")
    check(Config(provider: "openai").needsAPIKey, "cloud provider needs a key")
}
