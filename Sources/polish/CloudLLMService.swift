import Foundation
import PolishCore

/// OpenAI-compatible chat-completions client (not exercised in mock mode).
final class CloudLLMService: LLMService {
    struct APIError: Error, CustomStringConvertible {
        let description: String
    }

    private let config: Config
    private let apiKey: String
    private let session: URLSession

    init(config: Config, apiKey: String, session: URLSession = .shared) {
        self.config = config
        self.apiKey = apiKey
        self.session = session
    }

    func transform(_ text: String) async throws -> String {
        guard let url = URL(string: config.baseURL + "/chat/completions") else {
            throw APIError(description: "invalid base_url: \(config.baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": config.prompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw APIError(description: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(raw)")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw APIError(description: "response contained no content")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
        let choices: [Choice]
    }
}
