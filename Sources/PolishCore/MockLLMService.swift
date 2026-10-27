/// Deterministic stand-in for a real cloud LLM. Keeps the same interface so
/// switching `provider` later is a one-line change.
public struct MockLLMService: LLMService {
    private let body: @Sendable (String) -> String

    public init(transform: @escaping @Sendable (String) -> String = { "[polished] " + $0 }) {
        self.body = transform
    }

    public func transform(_ text: String) async throws -> String {
        body(text)
    }
}
