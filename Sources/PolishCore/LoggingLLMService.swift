import Foundation

/// Wraps any `LLMService` to log the input, output, and latency of each call.
public struct LoggingLLMService: LLMService {
    private let wrapped: LLMService
    private let now: () -> Double
    private let log: (String) -> Void

    public init(
        wrapping service: LLMService,
        now: @escaping () -> Double = { Date().timeIntervalSince1970 },
        log: @escaping (String) -> Void
    ) {
        self.wrapped = service
        self.now = now
        self.log = log
    }

    public func transform(_ text: String) async throws -> String {
        log("llm → \(text)")
        let start = now()
        do {
            let output = try await wrapped.transform(text)
            log("llm ← \(output)  [\(millis(since: start)) ms]")
            return output
        } catch {
            log("llm ✗ \(error)  [\(millis(since: start)) ms]")
            throw error
        }
    }

    private func millis(since start: Double) -> Int {
        Int(((now() - start) * 1000).rounded())
    }
}
