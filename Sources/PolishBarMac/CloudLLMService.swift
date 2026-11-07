import Foundation
import PolishBarCore

/// OpenAI-compatible chat-completions client. The key comes from
/// `POLISHBAR_API_KEY` (or the stored key file); see `APIKeyResolver`.
final class CloudLLMService: LLMService {
    struct APIError: Error, CustomStringConvertible {
        let description: String
    }

    private let config: Config
    private let apiKey: String
    private let session: URLSession
    private let log: (String) -> Void

    init(
        config: Config,
        apiKey: String,
        session: URLSession = .shared,
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.config = config
        self.apiKey = apiKey
        self.session = session
        self.log = log
    }

    func transform(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError(description: "no API key (set POLISHBAR_API_KEY)")
        }
        guard let url = URL(string: config.baseURL + "/chat/completions") else {
            throw APIError(description: "invalid base_url: \(config.baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try OpenAIWire.requestBody(
            model: config.model,
            systemPrompt: config.prompt,
            userText: text,
            reasoningEffort: config.reasoningEffort
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(description: "no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw APIError(description: "HTTP \(http.statusCode): \(raw)")
        }

        let result = try OpenAIWire.result(fromResponseBody: data)
        if config.logRawResponse {
            log("llm raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
        }
        log("llm detail: reason=\(describe(result)) effort=\(config.reasoningEffort ?? "<unset>")")
        return result.content
    }

    private func describe(_ result: ChatResult) -> String {
        if let reasoning = result.reasoningContent {
            return "reasoning_content(\(reasoning.count) chars)"
        }
        if let tokens = result.reasoningTokens, tokens > 0 {
            return "reasoning_tokens=\(tokens)"
        }
        return "none"
    }
}
