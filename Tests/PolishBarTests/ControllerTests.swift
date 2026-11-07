import PolishBarCore

// MARK: - Fakes

private final class FakeFocus: FocusProviding {
    private var apps: [FocusedApp?]
    private var index = 0
    init(_ apps: [FocusedApp?]) { self.apps = apps }
    func frontmostApp() -> FocusedApp? {
        let app = apps[min(index, apps.count - 1)]
        index += 1
        return app
    }
}

private final class FakeCapture: TextCapturing {
    var result: CapturedText?
    private(set) var callCount = 0
    func capture(focusedApp: FocusedApp, maxSentenceLength: Int) -> CapturedText? {
        callCount += 1
        return result
    }
}

private final class FakeReplacer: TextReplacing {
    var succeeds = true
    private(set) var calls: [(captured: CapturedText, newText: String)] = []
    func replace(captured: CapturedText, with newText: String) -> Bool {
        calls.append((captured, newText))
        return succeeds
    }
}

private struct PrefixLLM: LLMService {
    let prefix: String
    func transform(_ text: String) async throws -> String { prefix + text }
}

private struct FailingLLM: LLMService {
    struct Boom: Error {}
    func transform(_ text: String) async throws -> String { throw Boom() }
}

/// Blocks inside `transform` until `release()` is called, so a second hotkey
/// press can be observed while the first is still in flight.
private actor GateLLM: LLMService {
    private var isWaiting = false
    private var enteredSignal: CheckedContinuation<Void, Never>?
    private var releaseSignals: [CheckedContinuation<Void, Never>] = []

    func transform(_ text: String) async throws -> String {
        isWaiting = true
        enteredSignal?.resume()
        enteredSignal = nil
        await withCheckedContinuation { releaseSignals.append($0) }
        isWaiting = false
        return "[polished] " + text
    }

    func waitUntilEntered() async {
        if isWaiting { return }
        await withCheckedContinuation { enteredSignal = $0 }
    }

    func release() {
        releaseSignals.forEach { $0.resume() }
        releaseSignals.removeAll()
    }
}

private let appA = FocusedApp(pid: 100, bundleID: "com.example.a")
private let appB = FocusedApp(pid: 200, bundleID: "com.example.b")

func runControllerTests() async {
    suite("PolishBarController")

    do {
        let focus = FakeFocus([appA, appA])
        let capture = FakeCapture()
        capture.result = CapturedText(text: "hello", app: appA)
        let replacer = FakeReplacer()
        let controller = PolishBarController(
            focus: focus, capture: capture, replacer: replacer,
            llm: PrefixLLM(prefix: "[p] "), config: Config()
        )
        let outcome = await controller.handleHotkey()
        equalOptional(outcome.status, .replaced, "happy path replaces")
        equalOptional(outcome.input, "hello", "reports captured input")
        equalOptional(outcome.output, "[p] hello", "reports transformed output")
        equal(replacer.calls.count, 1, "replacer called once")
        equalOptional(replacer.calls.first?.newText, "[p] hello", "replacer got transformed text")
    }

    do {
        let controller = PolishBarController(
            focus: FakeFocus([nil]), capture: FakeCapture(), replacer: FakeReplacer(),
            llm: PrefixLLM(prefix: ""), config: Config()
        )
        equalOptional((await controller.handleHotkey()).status, .noFocus, "no focus aborts")
    }

    do {
        let capture = FakeCapture()
        let replacer = FakeReplacer()
        let controller = PolishBarController(
            focus: FakeFocus([appA]), capture: capture, replacer: replacer,
            llm: PrefixLLM(prefix: ""), config: Config()
        )
        equalOptional((await controller.handleHotkey()).status, .nothingToCapture, "empty capture aborts")
        equal(replacer.calls.count, 0, "no replace when nothing captured")
    }

    do {
        let capture = FakeCapture()
        capture.result = CapturedText(text: "hi", app: appA)
        let replacer = FakeReplacer()
        let controller = PolishBarController(
            focus: FakeFocus([appA, appB]), capture: capture, replacer: replacer,
            llm: PrefixLLM(prefix: "[p] "), config: Config()
        )
        equalOptional((await controller.handleHotkey()).status, .focusChanged, "focus change aborts replace")
        equal(replacer.calls.count, 0, "no replace when focus changed")
    }

    do {
        let capture = FakeCapture()
        capture.result = CapturedText(text: "hi", app: appA)
        let replacer = FakeReplacer()
        replacer.succeeds = false
        let controller = PolishBarController(
            focus: FakeFocus([appA, appA]), capture: capture, replacer: replacer,
            llm: PrefixLLM(prefix: "[p] "), config: Config()
        )
        equalOptional((await controller.handleHotkey()).status, .replaceFailed, "replace failure reported")
    }

    do {
        let capture = FakeCapture()
        capture.result = CapturedText(text: "hi", app: appA)
        let controller = PolishBarController(
            focus: FakeFocus([appA]), capture: capture, replacer: FakeReplacer(),
            llm: FailingLLM(), config: Config()
        )
        equalOptional((await controller.handleHotkey()).status, .llmFailed, "llm failure reported")
    }

    do {
        let capture = FakeCapture()
        capture.result = CapturedText(text: "hi", app: appA)
        let replacer = FakeReplacer()
        let gate = GateLLM()
        let controller = PolishBarController(
            focus: FakeFocus([appA, appA]), capture: capture, replacer: replacer,
            llm: gate, config: Config()
        )
        let first = Task { await controller.handleHotkey() }
        await gate.waitUntilEntered()
        let second = await controller.handleHotkey()
        equalOptional(second.status, .busy, "second press while busy is rejected")
        await gate.release()
        equalOptional((await first.value).status, .replaced, "first press still completes")
    }
}
