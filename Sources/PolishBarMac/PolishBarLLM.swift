import PolishBarCore

/// Builds the configured LLM service: the real OpenAI-compatible client,
/// wrapped with input/output/latency logging.
public func makePolishBarLLM(config: Config, apiKey: String, log: @escaping (String) -> Void) -> LLMService {
    LoggingLLMService(
        wrapping: CloudLLMService(config: config, apiKey: apiKey, log: log),
        log: log
    )
}
