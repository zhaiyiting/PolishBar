import PolishCore

private struct FixedLLM: LLMService {
    let value: String
    func transform(_ text: String) async throws -> String { value }
}

private struct ThrowingLLM: LLMService {
    struct Boom: Error {}
    func transform(_ text: String) async throws -> String { throw Boom() }
}

private final class LogLines {
    var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
}

private final class SequenceClock {
    private let times: [Double]
    private var index = 0
    init(_ times: [Double]) { self.times = times }
    func next() -> Double {
        defer { index += 1 }
        return times[min(index, times.count - 1)]
    }
}

func runLoggingTests() async {
    suite("LoggingLLMService")

    do {
        let logs = LogLines()
        let clock = SequenceClock([1000.0, 1000.25])
        let service = LoggingLLMService(wrapping: FixedLLM(value: "OUT"), now: clock.next, log: logs.append)
        let output = try? await service.transform("IN")
        equalOptional(output, "OUT", "passes through the wrapped value")
        equal(logs.lines.count, 2, "logs an input and an output line")
        check(logs.lines.first?.contains("IN") == true, "logs the input text")
        check(logs.lines.last?.contains("OUT") == true, "logs the output text")
        check(logs.lines.last?.contains("250") == true, "logs latency in ms")
    }

    do {
        let logs = LogLines()
        let clock = SequenceClock([0.0, 0.1])
        let service = LoggingLLMService(wrapping: ThrowingLLM(), now: clock.next, log: logs.append)
        var threw = false
        do { _ = try await service.transform("IN") } catch { threw = true }
        check(threw, "rethrows the wrapped error")
        equal(logs.lines.count, 2, "logs input and error line")
        check(logs.lines.last?.contains("100") == true, "error line includes latency")
    }
}
