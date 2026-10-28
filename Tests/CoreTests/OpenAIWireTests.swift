import Foundation
import PolishCore

func runOpenAIWireTests() {
    suite("OpenAIWire.requestBody")

    do {
        let data = try! OpenAIWire.requestBody(model: "gpt-x", systemPrompt: "SYS", userText: "USER")
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        equal(object["model"] as? String, "gpt-x", "sets model")
        equal(object["temperature"] as? Int, 0, "temperature is 0")

        let messages = object["messages"] as! [[String: Any]]
        equal(messages.count, 2, "two messages")
        equal(messages[0]["role"] as? String, "system", "first message is system")
        equal(messages[0]["content"] as? String, "SYS", "system content")
        equal(messages[1]["role"] as? String, "user", "second message is user")
        equal(messages[1]["content"] as? String, "USER", "user content")
    }

    suite("OpenAIWire.content")

    do {
        let body = #"{"choices":[{"message":{"role":"assistant","content":"Hello there"}}]}"#
        equal(try! OpenAIWire.content(fromResponseBody: Data(body.utf8)), "Hello there", "extracts content")
    }

    do {
        let body = #"{"choices":[{"message":{"role":"assistant","content":"  padded  "}}]}"#
        equal(try! OpenAIWire.content(fromResponseBody: Data(body.utf8)), "padded", "trims whitespace")
    }

    checkThrows("empty choices throws") {
        _ = try OpenAIWire.content(fromResponseBody: Data(#"{"choices":[]}"#.utf8))
    }

    checkThrows("malformed JSON throws") {
        _ = try OpenAIWire.content(fromResponseBody: Data("not json".utf8))
    }

    suite("OpenAIWire.reasoning_effort")

    do {
        let data = try! OpenAIWire.requestBody(model: "m", systemPrompt: "s", userText: "u", reasoningEffort: "off")
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        equal(object["reasoning_effort"] as? String, "off", "reasoning_effort passes through")
    }

    do {
        let data = try! OpenAIWire.requestBody(model: "m", systemPrompt: "s", userText: "u")
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        check(object["reasoning_effort"] == nil, "reasoning_effort omitted by default")
    }

    suite("OpenAIWire.result")

    do {
        let body = #"{"choices":[{"message":{"content":"Hi","reasoning_content":"hmm..."}}],"usage":{"completion_tokens_details":{"reasoning_tokens":42}}}"#
        let result = try! OpenAIWire.result(fromResponseBody: Data(body.utf8))
        equal(result.content, "Hi", "extracts content")
        equalOptional(result.reasoningContent, "hmm...", "extracts reasoning_content")
        equalOptional(result.reasoningTokens, 42, "extracts reasoning token count")
        check(result.usedReasoning, "flags that reasoning happened")
    }

    do {
        let body = #"{"choices":[{"message":{"content":"Hi"}}]}"#
        let result = try! OpenAIWire.result(fromResponseBody: Data(body.utf8))
        equalOptional(result.reasoningContent, nil, "no reasoning_content")
        equalOptional(result.reasoningTokens, nil, "no reasoning tokens")
        check(!result.usedReasoning, "does not flag reasoning")
    }
}
