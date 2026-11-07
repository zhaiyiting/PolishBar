import Foundation

public enum OpenAIWireError: Error, Equatable {
    case missingContent
    case malformedResponse
}

/// The parts of a chat-completions response we care about. `reasoningContent`
/// and `reasoningTokens` are how you tell whether the model actually "thought".
public struct ChatResult: Equatable, Sendable {
    public let content: String
    public let reasoningContent: String?
    public let reasoningTokens: Int?

    public init(content: String, reasoningContent: String?, reasoningTokens: Int?) {
        self.content = content
        self.reasoningContent = reasoningContent
        self.reasoningTokens = reasoningTokens
    }

    public var usedReasoning: Bool {
        reasoningContent != nil || (reasoningTokens ?? 0) > 0
    }
}

/// Encodes requests and decodes responses for the OpenAI-compatible
/// chat-completions API. Kept separate from the transport so it can be tested.
public enum OpenAIWire {
    public static func requestBody(
        model: String,
        systemPrompt: String,
        userText: String,
        reasoningEffort: String? = nil
    ) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText],
            ],
        ]
        if let reasoningEffort {
            body["reasoning_effort"] = reasoningEffort
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    public static func result(fromResponseBody data: Data) throws -> ChatResult {
        guard let response = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw OpenAIWireError.malformedResponse
        }
        let message = response.choices.first?.message
        guard let content = message?.content, !content.isEmpty else {
            throw OpenAIWireError.missingContent
        }
        return ChatResult(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            reasoningContent: message?.reasoningContent,
            reasoningTokens: response.usage?.completionTokensDetails?.reasoningTokens
        )
    }

    public static func content(fromResponseBody data: Data) throws -> String {
        try result(fromResponseBody: data).content
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
                let reasoningContent: String?

                enum CodingKeys: String, CodingKey {
                    case content
                    case reasoningContent = "reasoning_content"
                }
            }
            let message: Message
        }
        struct Usage: Decodable {
            struct CompletionDetails: Decodable {
                let reasoningTokens: Int?

                enum CodingKeys: String, CodingKey {
                    case reasoningTokens = "reasoning_tokens"
                }
            }
            let completionTokensDetails: CompletionDetails?

            enum CodingKeys: String, CodingKey {
                case completionTokensDetails = "completion_tokens_details"
            }
        }
        let choices: [Choice]
        let usage: Usage?
    }
}

