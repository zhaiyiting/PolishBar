/// Orchestrates one hotkey press: capture -> transform -> replace.
///
/// All OS interaction is injected via protocols, so this type is fully testable
/// with fakes and contains no AppKit/Carbon/Foundation dependencies.
public final class PolishController {
    public enum Status: Equatable, Sendable {
        case replaced
        case busy
        case noFocus
        case nothingToCapture
        case focusChanged
        case llmFailed
        case replaceFailed
    }

    public struct Outcome: Equatable, Sendable {
        public let status: Status
        public let input: String?
        public let output: String?

        public init(status: Status, input: String? = nil, output: String? = nil) {
            self.status = status
            self.input = input
            self.output = output
        }
    }

    private let focus: FocusProviding
    private let capture: TextCapturing
    private let replacer: TextReplacing
    private let llm: LLMService
    private let config: Config
    private let log: (String) -> Void

    private var isProcessing = false

    public init(
        focus: FocusProviding,
        capture: TextCapturing,
        replacer: TextReplacing,
        llm: LLMService,
        config: Config,
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.focus = focus
        self.capture = capture
        self.replacer = replacer
        self.llm = llm
        self.config = config
        self.log = log
    }

    public func handleHotkey() async -> Outcome {
        if isProcessing {
            log("ignoring hotkey: already processing")
            return Outcome(status: .busy)
        }
        isProcessing = true
        defer { isProcessing = false }

        guard let app = focus.frontmostApp() else {
            log("no focused application")
            return Outcome(status: .noFocus)
        }

        guard let captured = capture.capture(focusedApp: app, maxSentenceLength: config.maxSentenceLength) else {
            log("nothing to capture")
            return Outcome(status: .nothingToCapture)
        }

        let transformed: String
        do {
            transformed = try await llm.transform(captured.text)
        } catch {
            log("llm failed: \(error)")
            return Outcome(status: .llmFailed, input: captured.text)
        }

        guard focus.frontmostApp() == app else {
            log("focus changed before replace; skipping")
            return Outcome(status: .focusChanged, input: captured.text, output: transformed)
        }

        guard replacer.replace(captured: captured, with: transformed) else {
            log("replace failed")
            return Outcome(status: .replaceFailed, input: captured.text, output: transformed)
        }

        log("replaced \(captured.text.count) character(s)")
        return Outcome(status: .replaced, input: captured.text, output: transformed)
    }
}
