# Text Polish Daemon Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS CLI daemon that captures text (selection, or the sentence before the caret) via a global hotkey, sends it to a (mocked) LLM, and replaces it in place.

**Architecture:** A SwiftPM package with a thin executable (`polish`) that bootstraps an `NSApplication` accessory run loop, and a `PolishCore` library holding all logic. Every OS touchpoint (AX, pasteboard, synthesized keystrokes, keychain, TCC trust) sits behind a protocol so orchestration is unit-tested with fakes; the real adapters are thin and verified manually.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit, Carbon (hotkeys), ApplicationServices/Accessibility (AX), XCTest.

**Reference:** design doc at `docs/plans/2026-10-27-text-polish-daemon-design.md`.

---

## Status (updated 2026-10-28)

**Overall: MVP implemented, building green, running on the target Mac.** The
shipped package deviates from this plan's file/type names and supersedes its
"mocked LLM" scope. Tests run through a dependency-free `CoreTests` harness
(`swift run CoreTests`, or `./scripts/test-core.sh`) rather than XCTest.

**Tests: 88 checks, 0 failed.**

| Task | Status | Notes |
|------|--------|-------|
| 1. Package skeleton | ✅ Done | `Package.swift` (tools 6.0, language mode v5) with products + a `CoreTests` executable; `Version.swift`, `.gitignore`. |
| 2. Config model + TOML | ✅ Done (adapted) | `Config.parse`. Names differ (`maxSentenceLength`, `clipboardRestoreDelayMS`); parsing is lenient (no `ParseError`); adds `reasoningEffort`, `logRawResponse`; default `provider = "openai"`. |
| 3. Config file + API key | ✅ Done (adapted) | `APIKeyResolver` (not `Secrets.swift`/`SecretStore`); file load via `ConfigStore`. |
| 4. Sentence-before-caret | ✅ Done (adapted) | `SentenceCapture.beforeCaret(in:caret:maxLength:) -> CapturedSentence?` (text + start offset, not a `Range`). Unit-tested. |
| 5. OS touchpoint protocols | ✅ Done (subset) | `Protocols.swift`: `FocusProviding`, `TextCapturing`, `TextReplacing`, `LLMService`, `CapturedText`, `FocusedApp`, `TextAnchor`. No `Pasteboard`/`KeystrokePosting`/`TrustChecking` protocols (concrete classes). Fakes live in `ControllerTests`. |
| 6. Mock LLM service | ⛔ Removed | Deliberately dropped — replaced by the real OpenAI-compatible client. |
| 7. Capture service | ⚠️ Done differently | Inside the `AXText` adapter: AX selection → value+caret sentence → `Cmd+C` fallback. Not a pure `CaptureService`; the pure sentence logic is unit-tested. |
| 8. Replace service | ⚠️ Done differently | In `AXText.replace` (pasteboard + `Cmd+V`, snapshot/restore). Focus guard lives in `PolishController`; covered by controller tests. |
| 9. Pipeline orchestrator | ✅ Done (renamed) | `PolishController.handleHotkey()` with reentrancy + focus-change guards; covered by `ControllerTests`. |
| 10. Permission manager | ✅ Done (adapted) | `Permissions` adapter; `doctor` reports status. No pure `permissionWarning` test. |
| 11. Hotkey parsing | ⚠️ Done differently | `HotkeyManager.parse` (Carbon) in the `polish` target; a–z/0–9/space/return. Not unit-tested. |
| 12. CLI parsing | ✅ Done (adapted) | Inline switch in `main.swift` (no `Command` enum); adds an `exec` subcommand. |
| 13. Real adapters | ✅ Done (adapted) | Flat files under `Sources/polish/` (no `Adapters/` folder). |
| 14. Daemon + doctor | ✅ Done (adapted) | `Daemon.run()` + `doctor`; exits with a clear message when no API key. |
| 15. Manual verification + README | ⚠️ Partial | Release build + ad-hoc sign + Accessibility grant done locally. Manual app checklist not fully run. README intentionally not created. |

### Deviations

- **Tests:** plan assumed XCTest + `swift test`; the machine's Command Line Tools
  had a broken SwiftPM/XCTest, so tests use a dependency-free harness in
  `Tests/CoreTests` (`swift run CoreTests`). `scripts/test-core.sh` builds it
  with `swiftc` directly.
- **Naming/layout:** `Pipeline`→`PolishController`, `Sentence.swift`→`SentenceCapture.swift`,
  `Secrets.swift`→`Config.swift`/`APIKeyResolver`; adapters flattened into `Sources/polish/`.
- **Scope:** the planned "mock LLM" was replaced by a real OpenAI-compatible client.

### Added beyond this plan

- Real LLM client (`OpenAIWire`, `CloudLLMService`) with the key from `POLISH_API_KEY` (fallback: keychain).
- `DefaultPrompt.polish` — native-English rewrite, grammar fixes, mixed Chinese/English input, output-only.
- `LoggingLLMService` (logs input, output, latency) + opt-in raw response + a reasoning summary.
- `reasoning_effort` config (Command Code: `"off"` disables thinking; `"none"` returns 400).
- `polish exec TEXT` one-shot command; `scripts/run.sh` (build + sign + run); `config.example.toml`.
- Menu-bar app (`PolishApp`) + shared `PolishMac` library and `PolishService`
  (see `docs/plans/2026-10-28-menu-bar-app-design.md`); `scripts/build-app.sh`.

### Remaining

- Manual integration checklist (Task 15): selection and sentence capture in
  TextEdit/Chrome/VS Code/Slack/terminal, focus-change skip, clipboard restore,
  password-field safety.
- Optional: add a README; refresh the design doc's "mocked LLM" wording.

---

## Conventions

- Run all commands from the repo root: `/Users/zhai/wsp/opencode_polish`.
- Build: `swift build` — Test: `swift test` — Run: `swift run polish`.
- Commit after every task (messages given per task).
- TDD: write the failing test, watch it fail, implement minimally, watch it pass, commit.

---

### Task 1: Package skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/polish/main.swift`
- Create: `Sources/PolishCore/Version.swift`
- Create: `Tests/PolishCoreTests/VersionTests.swift`
- Create: `.gitignore`

**Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "polish",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "polish", dependencies: ["PolishCore"]),
        .target(name: "PolishCore"),
        .testTarget(name: "PolishCoreTests", dependencies: ["PolishCore"]),
    ]
)
```

**Step 2: Write `Sources/PolishCore/Version.swift`**

```swift
public enum Version {
    public static let current = "0.1.0"
}
```

**Step 3: Write failing test `Tests/PolishCoreTests/VersionTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class VersionTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertEqual(Version.current, "0.1.0")
    }
}
```

**Step 4: Write `Sources/polish/main.swift`**

```swift
import PolishCore
print("polish \(Version.current)")
```

**Step 5: Write `.gitignore`**

```
.build/
.swiftpm/
*.xcodeproj
.DS_Store
```

**Step 6: Run tests**

Run: `swift test`
Expected: PASS (1 test).

**Step 7: Run the executable**

Run: `swift run polish`
Expected: prints `polish 0.1.0`.

**Step 8: Commit**

```bash
git add Package.swift Sources Tests .gitignore
git commit -m "chore: bootstrap swiftpm package"
```

---

### Task 2: Config model + TOML parsing

**Files:**
- Create: `Sources/PolishCore/Config.swift`
- Test: `Tests/PolishCoreTests/ConfigTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/ConfigTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class ConfigTests: XCTestCase {
    func testDefaults() {
        let c = Config.default
        XCTAssertEqual(c.hotkey, "cmd+shift+j")
        XCTAssertEqual(c.provider, "mock")
        XCTAssertEqual(c.maxSentenceLen, 400)
        XCTAssertEqual(c.clipboardRestoreDelayMs, 250)
    }

    func testParsesFlatToml() throws {
        let toml = """
        # comment
        hotkey = "cmd+alt+p"
        provider = "openai"
        max_sentence_len = 200

        prompt = "Rewrite this:"
        """
        let c = try Config.parse(toml)
        XCTAssertEqual(c.hotkey, "cmd+alt+p")
        XCTAssertEqual(c.provider, "openai")
        XCTAssertEqual(c.maxSentenceLen, 200)
        XCTAssertEqual(c.prompt, "Rewrite this:")
    }

    func testMissingKeysKeepDefaults() throws {
        let c = try Config.parse("provider = \"mock\"\n")
        XCTAssertEqual(c.maxSentenceLen, 400)
        XCTAssertEqual(c.hotkey, "cmd+shift+j")
    }

    func testIgnoresBlankAndCommentLines() throws {
        let c = try Config.parse("\n# x\n  \nprovider = \"mock\"\n")
        XCTAssertEqual(c.provider, "mock")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ConfigTests`
Expected: FAIL — `Config` not defined.

**Step 3: Implement `Sources/PolishCore/Config.swift`**

```swift
import Foundation

public struct Config: Equatable {
    public var hotkey: String
    public var provider: String
    public var model: String
    public var baseURL: String
    public var prompt: String
    public var captureMode: String
    public var maxSentenceLen: Int
    public var clipboardRestoreDelayMs: Int

    public static let `default` = Config(
        hotkey: "cmd+shift+j",
        provider: "mock",
        model: "gpt-4o-mini",
        baseURL: "https://api.openai.com/v1",
        prompt: "Rewrite the following text to be clear and concise. Reply with only the rewritten text.",
        captureMode: "selection_then_sentence",
        maxSentenceLen: 400,
        clipboardRestoreDelayMs: 250
    )

    public enum ParseError: Error, Equatable { case badLine(String) }

    public static func parse(_ text: String) throws -> Config {
        var values: [String: String] = [:]
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else {
                throw ParseError.badLine(line)
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var val = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if val.hasPrefix("\"") && val.hasSuffix("\"") && val.count >= 2 {
                val = String(val.dropFirst().dropLast())
            }
            values[key] = val
        }

        var c = Config.default
        if let v = values["hotkey"] { c.hotkey = v }
        if let v = values["provider"] { c.provider = v }
        if let v = values["model"] { c.model = v }
        if let v = values["base_url"] { c.baseURL = v }
        if let v = values["prompt"] { c.prompt = v }
        if let v = values["capture_mode"] { c.captureMode = v }
        if let v = values["max_sentence_len"], let n = Int(v) { c.maxSentenceLen = n }
        if let v = values["clipboard_restore_delay_ms"], let n = Int(v) { c.clipboardRestoreDelayMs = n }
        return c
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ConfigTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/Config.swift Tests/PolishCoreTests/ConfigTests.swift
git commit -m "feat: config model with minimal toml parsing"
```

---

### Task 3: Config file loading + API key precedence

**Files:**
- Create: `Sources/PolishCore/Secrets.swift`
- Test: `Tests/PolishCoreTests/SecretsTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/SecretsTests.swift`**

```swift
import XCTest
@testable import PolishCore

private struct FakeStore: SecretStore {
    var values: [String: String]
    func secret(for provider: String) -> String? { values[provider] }
}

final class SecretsTests: XCTestCase {
    func testEnvWins() {
        let key = resolveAPIKey(
            provider: "openai",
            environment: ["POLISH_API_KEY": "env-key"],
            store: FakeStore(values: ["openai": "keychain-key"])
        )
        XCTAssertEqual(key, "env-key")
    }

    func testFallsBackToStore() {
        let key = resolveAPIKey(
            provider: "openai",
            environment: [:],
            store: FakeStore(values: ["openai": "keychain-key"])
        )
        XCTAssertEqual(key, "keychain-key")
    }

    func testEmptyEnvFallsBackToStore() {
        let key = resolveAPIKey(
            provider: "openai",
            environment: ["POLISH_API_KEY": ""],
            store: FakeStore(values: ["openai": "keychain-key"])
        )
        XCTAssertEqual(key, "keychain-key")
    }

    func testNilWhenNothingFound() {
        XCTAssertNil(resolveAPIKey(provider: "openai", environment: [:], store: FakeStore(values: [:])))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter SecretsTests`
Expected: FAIL — `SecretStore`/`resolveAPIKey` not defined.

**Step 3: Implement `Sources/PolishCore/Secrets.swift`**

```swift
import Foundation

public protocol SecretStore {
    func secret(for provider: String) -> String?
}

public func resolveAPIKey(
    provider: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    store: SecretStore
) -> String? {
    if let env = environment["POLISH_API_KEY"], !env.isEmpty { return env }
    if let s = store.secret(for: provider), !s.isEmpty { return s }
    return nil
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter SecretsTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/Secrets.swift Tests/PolishCoreTests/SecretsTests.swift
git commit -m "feat: api key resolution precedence"
```

---

### Task 4: Sentence-before-caret computation

This is the core pure logic; be thorough.

**Files:**
- Create: `Sources/PolishCore/Sentence.swift`
- Test: `Tests/PolishCoreTests/SentenceTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/SentenceTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class SentenceTests: XCTestCase {
    private func sub(_ s: String, _ caret: Int, cap: Int = 400) -> String? {
        let chars = Array(s)
        guard let r = sentenceBeforeCaret(in: chars, caret: caret, maxLen: cap) else { return nil }
        return String(chars[r])
    }

    func testNoCaretReturnsNil() {
        XCTAssertNil(sub("Hello.", 0))
    }

    func testSingleSentence() {
        XCTAssertEqual(sub("Hello world.", 12), "Hello world.")
    }

    func testTakesOnlyTextAfterLastTerminator() {
        XCTAssertEqual(sub("One. Two ok?", 12), "Two ok?")
    }

    func testExclamationAndNewline() {
        XCTAssertEqual(sub("Yes!\nRun now", 12), "Run now")
    }

    func testCJKPunctuation() {
        XCTAssertEqual(sub("你好。世界", 4), "世界")
    }

    func testFullWidthQuestion() {
        XCTAssertEqual(sub("好？世界", 4), "世界")
    }

    func testTrailingWhitespaceTrimmed() {
        XCTAssertEqual(sub("Done.   ", 8), "Done.")
    }

    func testAllWhitespaceReturnsNil() {
        XCTAssertNil(sub("    ", 4))
    }

    func testCapLimitsScan() {
        XCTAssertEqual(sub("abcdefghij", 10, cap: 3), "hij")
    }

    func testCaretInMiddleStopsAtTerminator() {
        XCTAssertEqual(sub("Alpha. Beta gamma", 12), "Beta")
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter SentenceTests`
Expected: FAIL — `sentenceBeforeCaret` not defined.

**Step 3: Implement `Sources/PolishCore/Sentence.swift`**

```swift
import Foundation

let sentenceTerminators: Set<Character> = [".", "?", "!", "。", "？", "！", "\n"]

/// Returns the character-index range of the sentence immediately before `caret`.
/// Scans backward at most `maxLen` characters. Returns nil if there is no
/// non-whitespace content to capture.
public func sentenceBeforeCaret(in chars: [Character], caret: Int, maxLen: Int) -> Range<Int>? {
    guard caret > 0, caret <= chars.count else { return nil }

    var start = caret
    var i = caret - 1
    var scanned = 0
    while i >= 0 && scanned < maxLen {
        if sentenceTerminators.contains(chars[i]) {
            start = i + 1
            break
        }
        start = i
        i -= 1
        scanned += 1
    }

    var end = caret
    while start < end && chars[start].isWhitespace { start += 1 }
    while end > start && chars[end - 1].isWhitespace { end -= 1 }

    guard start < end else { return nil }
    return start..<end
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter SentenceTests`
Expected: PASS (10 tests).

**Step 5: Commit**

```bash
git add Sources/PolishCore/Sentence.swift Tests/PolishCoreTests/SentenceTests.swift
git commit -m "feat: sentence-before-caret computation"
```

---

### Task 5: OS touchpoint protocols

**Files:**
- Create: `Sources/PolishCore/Protocols.swift`
- Test: `Tests/PolishCoreTests/Fakes.swift`

**Step 1: Implement `Sources/PolishCore/Protocols.swift`**

```swift
import Foundation

public protocol Pasteboard {
    func string() -> String?
    func setString(_ value: String)
    func clear()
}

public protocol KeystrokePosting {
    func copy()   // synthesize Cmd+C
    func paste()  // synthesize Cmd+V
}

public struct CapturedText: Equatable {
    public enum Source: Equatable { case selection, sentence, clipboard }
    public var text: String
    public var source: Source
    /// Character-index range of the captured text within the focused field, when known.
    public var range: Range<Int>?
    public init(text: String, source: Source, range: Range<Int>?) {
        self.text = text
        self.source = source
        self.range = range
    }
}

public protocol TextCapturing {
    /// Text currently selected in the focused element, if any.
    func selectedText() -> String?
    /// Full text + caret (character index) of the focused element, if available.
    func fieldTextAndCaret() -> (text: [Character], caret: Int)?
}

public protocol LLMService {
    func transform(_ text: String) async throws -> String
}

public protocol FocusProviding {
    /// Stable id of the frontmost application (e.g. bundle id or pid string).
    func frontmostAppID() -> String?
}

public protocol TrustChecking {
    func isTrusted() -> Bool
}
```

**Step 2: Add test fakes `Tests/PolishCoreTests/Fakes.swift`**

```swift
import Foundation
import PolishCore

final class FakePasteboard: Pasteboard {
    private(set) var value: String?
    func string() -> String? { value }
    func setString(_ v: String) { value = v }
    func clear() { value = nil }
}

final class FakeKeystrokes: KeystrokePosting {
    private(set) var copies = 0
    private(set) var pastes = 0
    var onCopy: (() -> Void)?
    func copy() { copies += 1; onCopy?() }
    func paste() { pastes += 1 }
}

final class FakeCapturer: TextCapturing {
    var selection: String?
    var field: (text: [Character], caret: Int)?
    func selectedText() -> String? { selection }
    func fieldTextAndCaret() -> (text: [Character], caret: Int)? { field }
}

final class FakeLLM: LLMService {
    var result: String = ""
    private(set) var received: String?
    func transform(_ text: String) async throws -> String {
        received = text
        return result
    }
}

final class FakeFocus: FocusProviding {
    var id: String?
    func frontmostAppID() -> String? { id }
}
```

**Step 3: Verify it compiles**

Run: `swift build`
Expected: builds with no errors.

**Step 4: Commit**

```bash
git add Sources/PolishCore/Protocols.swift Tests/PolishCoreTests/Fakes.swift
git commit -m "feat: os touchpoint protocols and test fakes"
```

---

### Task 6: Mock LLM service

**Files:**
- Create: `Sources/PolishCore/MockLLM.swift`
- Test: `Tests/PolishCoreTests/MockLLMTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/MockLLMTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class MockLLMTests: XCTestCase {
    func testPrefixesInput() async throws {
        let svc = MockLLMService()
        let out = try await svc.transform("hello")
        XCTAssertEqual(out, "[polished] hello")
    }

    func testEmptyInput() async throws {
        let svc = MockLLMService()
        XCTAssertEqual(try await svc.transform(""), "[polished] ")
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter MockLLMTests`
Expected: FAIL — `MockLLMService` not defined.

**Step 3: Implement `Sources/PolishCore/MockLLM.swift`**

```swift
import Foundation

public struct MockLLMService: LLMService {
    public init() {}
    public func transform(_ text: String) async throws -> String {
        try? await Task.sleep(nanoseconds: 50_000_000)
        return "[polished] " + text
    }
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter MockLLMTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/MockLLM.swift Tests/PolishCoreTests/MockLLMTests.swift
git commit -m "feat: mock llm service"
```

---

### Task 7: Capture service orchestration

**Files:**
- Create: `Sources/PolishCore/CaptureService.swift`
- Test: `Tests/PolishCoreTests/CaptureServiceTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/CaptureServiceTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class CaptureServiceTests: XCTestCase {
    func testSelectionWins() {
        let cap = FakeCapturer()
        cap.selection = "selected text"
        cap.field = (Array("irrelevant"), 3)
        let svc = CaptureService(capturer: cap, pasteboard: FakePasteboard(), keystrokes: FakeKeystrokes())
        let result = svc.capture(mode: "selection_then_sentence", maxSentenceLen: 400)
        XCTAssertEqual(result?.text, "selected text")
        XCTAssertEqual(result?.source, .selection)
    }

    func testSentenceWhenNoSelection() {
        let cap = FakeCapturer()
        cap.selection = nil
        cap.field = (Array("One. Two words"), 14)
        let svc = CaptureService(capturer: cap, pasteboard: FakePasteboard(), keystrokes: FakeKeystrokes())
        let result = svc.capture(mode: "selection_then_sentence", maxSentenceLen: 400)
        XCTAssertEqual(result?.text, "Two words")
        XCTAssertEqual(result?.source, .sentence)
        XCTAssertEqual(result?.range, 5..<14)
    }

    func testWhitespaceSelectionTreatedAsEmpty() {
        let cap = FakeCapturer()
        cap.selection = "   "
        cap.field = (Array("Hello there"), 11)
        let svc = CaptureService(capturer: cap, pasteboard: FakePasteboard(), keystrokes: FakeKeystrokes())
        let result = svc.capture(mode: "selection_then_sentence", maxSentenceLen: 400)
        XCTAssertEqual(result?.text, "Hello there")
    }

    func testClipboardFallbackWhenNoAX() {
        let cap = FakeCapturer()
        cap.selection = nil
        cap.field = nil
        let pb = FakePasteboard()
        let keys = FakeKeystrokes()
        keys.onCopy = { pb.setString("from clipboard") }
        let svc = CaptureService(capturer: cap, pasteboard: pb, keystrokes: keys)
        let result = svc.capture(mode: "selection_then_sentence", maxSentenceLen: 400)
        XCTAssertEqual(result?.text, "from clipboard")
        XCTAssertEqual(result?.source, .clipboard)
        XCTAssertEqual(keys.copies, 1)
    }

    func testNilWhenNothingAvailable() {
        let cap = FakeCapturer()
        let svc = CaptureService(capturer: cap, pasteboard: FakePasteboard(), keystrokes: FakeKeystrokes())
        XCTAssertNil(svc.capture(mode: "selection_then_sentence", maxSentenceLen: 400))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter CaptureServiceTests`
Expected: FAIL — `CaptureService` not defined.

**Step 3: Implement `Sources/PolishCore/CaptureService.swift`**

```swift
import Foundation

public struct CaptureService {
    let capturer: TextCapturing
    let pasteboard: Pasteboard
    let keystrokes: KeystrokePosting
    let clipboardRestoreDelayMs: Int

    public init(capturer: TextCapturing, pasteboard: Pasteboard, keystrokes: KeystrokePosting, clipboardRestoreDelayMs: Int = 250) {
        self.capturer = capturer
        self.pasteboard = pasteboard
        self.keystrokes = keystrokes
        self.clipboardRestoreDelayMs = clipboardRestoreDelayMs
    }

    public func capture(mode: String, maxSentenceLen: Int) -> CapturedText? {
        if let sel = capturer.selectedText(), !sel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CapturedText(text: sel, source: .selection, range: nil)
        }

        if mode == "selection_then_sentence", let (text, caret) = capturer.fieldTextAndCaret(),
           let range = sentenceBeforeCaret(in: text, caret: caret, maxLen: maxSentenceLen) {
            return CapturedText(text: String(text[range]), source: .sentence, range: range)
        }

        let original = pasteboard.string()
        keystrokes.copy()
        if let clipped = pasteboard.string(), !clipped.isEmpty, clipped != original {
            return CapturedText(text: clipped, source: .clipboard, range: nil)
        }
        return nil
    }
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter CaptureServiceTests`
Expected: PASS (5 tests).

**Step 5: Commit**

```bash
git add Sources/PolishCore/CaptureService.swift Tests/PolishCoreTests/CaptureServiceTests.swift
git commit -m "feat: capture service with selection/sentence/clipboard modes"
```

---

### Task 8: Replace service orchestration

**Files:**
- Create: `Sources/PolishCore/ReplaceService.swift`
- Test: `Tests/PolishCoreTests/ReplaceServiceTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/ReplaceServiceTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class ReplaceServiceTests: XCTestCase {
    func testReplacesAndRestoresClipboard() {
        let pb = FakePasteboard()
        pb.setString("original clip")
        let keys = FakeKeystrokes()
        let focus = FakeFocus(); focus.id = "app"
        let svc = ReplaceService(pasteboard: pb, keystrokes: keys, focus: focus)

        let ok = svc.replace(result: "new text", expectedAppID: "app", delayMs: 0)
        XCTAssertTrue(ok)
        XCTAssertEqual(keys.pastes, 1)
        XCTAssertEqual(pb.string(), "original clip")
    }

    func testAbortsWhenFocusChanged() {
        let pb = FakePasteboard()
        let keys = FakeKeystrokes()
        let focus = FakeFocus(); focus.id = "other"
        let svc = ReplaceService(pasteboard: pb, keystrokes: keys, focus: focus)

        let ok = svc.replace(result: "new text", expectedAppID: "app", delayMs: 0)
        XCTAssertFalse(ok)
        XCTAssertEqual(keys.pastes, 0)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter ReplaceServiceTests`
Expected: FAIL — `ReplaceService` not defined.

**Step 3: Implement `Sources/PolishCore/ReplaceService.swift`**

```swift
import Foundation

public struct ReplaceService {
    let pasteboard: Pasteboard
    let keystrokes: KeystrokePosting
    let focus: FocusProviding

    public init(pasteboard: Pasteboard, keystrokes: KeystrokePosting, focus: FocusProviding) {
        self.pasteboard = pasteboard
        self.keystrokes = keystrokes
        self.focus = focus
    }

    /// Pastes `result` over the active selection/range. Returns false (and does
    /// nothing) if the frontmost app no longer matches `expectedAppID`.
    @discardableResult
    public func replace(result: String, expectedAppID: String?, delayMs: Int) -> Bool {
        guard focus.frontmostAppID() == expectedAppID else { return false }
        let saved = pasteboard.string()
        pasteboard.setString(result)
        keystrokes.paste()
        scheduleRestore(saved, delayMs: delayMs)
        return true
    }

    private func scheduleRestore(_ saved: String?, delayMs: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [pasteboard] in
            if let saved { pasteboard.setString(saved) } else { pasteboard.clear() }
        }
    }
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter ReplaceServiceTests`
Expected: PASS.

> Note: with `delayMs: 0` the async restore runs after the test's synchronous asserts may have read the pasteboard. If the second assert is flaky, pump the run loop: replace the check with `RunLoop.current.run(until: Date().addingTimeInterval(0.05))` before asserting `pb.string()`. Prefer that if needed.

**Step 5: Commit**

```bash
git add Sources/PolishCore/ReplaceService.swift Tests/PolishCoreTests/ReplaceServiceTests.swift
git commit -m "feat: replace service with focus guard and clipboard restore"
```

---

### Task 9: Pipeline orchestrator (capture -> llm -> replace)

**Files:**
- Create: `Sources/PolishCore/Pipeline.swift`
- Test: `Tests/PolishCoreTests/PipelineTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/PipelineTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class PipelineTests: XCTestCase {
    private func makePipeline(
        cap: FakeCapturer, llm: FakeLLM, pb: FakePasteboard, keys: FakeKeystrokes, focus: FakeFocus
    ) -> Pipeline {
        Pipeline(
            capture: CaptureService(capturer: cap, pasteboard: pb, keystrokes: keys),
            replace: ReplaceService(pasteboard: pb, keystrokes: keys, focus: focus),
            llm: llm,
            config: .default
        )
    }

    func testHappyPath() async {
        let cap = FakeCapturer(); cap.selection = "hi"
        let llm = FakeLLM(); llm.result = "HI"
        let pb = FakePasteboard()
        let keys = FakeKeystrokes()
        let focus = FakeFocus(); focus.id = "app"
        let pipe = makePipeline(cap: cap, llm: llm, pb: pb, keys: keys, focus: focus)

        await pipe.run()

        XCTAssertEqual(llm.received, "hi")
        XCTAssertEqual(keys.pastes, 1)
    }

    func testNoCaptureDoesNothing() async {
        let cap = FakeCapturer()
        let llm = FakeLLM()
        let pb = FakePasteboard()
        let keys = FakeKeystrokes()
        let focus = FakeFocus(); focus.id = "app"
        let pipe = makePipeline(cap: cap, llm: llm, pb: pb, keys: keys, focus: focus)

        await pipe.run()

        XCTAssertNil(llm.received)
        XCTAssertEqual(keys.pastes, 0)
    }

    func testReentrantPressIgnored() async {
        let cap = FakeCapturer(); cap.selection = "hi"
        let llm = FakeLLM(); llm.result = "HI"
        let pb = FakePasteboard()
        let keys = FakeKeystrokes()
        let focus = FakeFocus(); focus.id = "app"
        let pipe = makePipeline(cap: cap, llm: llm, pb: pb, keys: keys, focus: focus)

        async let a: Void = pipe.run()
        async let b: Void = pipe.run()
        _ = await (a, b)

        XCTAssertEqual(keys.pastes, 1)
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter PipelineTests`
Expected: FAIL — `Pipeline` not defined.

**Step 3: Implement `Sources/PolishCore/Pipeline.swift`**

```swift
import Foundation

public actor Pipeline {
    let capture: CaptureService
    let replace: ReplaceService
    let llm: LLMService
    let config: Config
    private var busy = false

    public init(capture: CaptureService, replace: ReplaceService, llm: LLMService, config: Config) {
        self.capture = capture
        self.replace = replace
        self.llm = llm
        self.config = config
    }

    public func run() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        guard let captured = capture.capture(mode: config.captureMode, maxSentenceLen: config.maxSentenceLen) else {
            print("polish: nothing to capture")
            return
        }

        let appID = replace.focus.frontmostAppID()
        do {
            let out = try await llm.transform(captured.text)
            let ok = replace.replace(result: out, expectedAppID: appID, delayMs: config.clipboardRestoreDelayMs)
            print(ok ? "polish: replaced" : "polish: focus changed, skipped")
        } catch {
            print("polish: llm error: \(error)")
        }
    }
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter PipelineTests`
Expected: PASS (3 tests).

**Step 5: Commit**

```bash
git add Sources/PolishCore/Pipeline.swift Tests/PolishCoreTests/PipelineTests.swift
git commit -m "feat: pipeline orchestrator with reentrancy guard"
```

---

### Task 10: Permission manager (TCC trust)

**Files:**
- Create: `Sources/PolishCore/Permissions.swift`
- Test: `Tests/PolishCoreTests/PermissionTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/PermissionTests.swift`**

```swift
import XCTest
@testable import PolishCore

private struct FakeTrust: TrustChecking {
    var trusted: Bool
    func isTrusted() -> Bool { trusted }
}

final class PermissionTests: XCTestCase {
    func testTrustedNoWarning() {
        XCTAssertNil(permissionWarning(trust: FakeTrust(trusted: true), binaryPath: "/x/polish"))
    }

    func testUntrustedWarningMentionsPathAndSettings() {
        let w = permissionWarning(trust: FakeTrust(trusted: false), binaryPath: "/x/polish")
        XCTAssertNotNil(w)
        XCTAssertTrue(w!.contains("/x/polish"))
        XCTAssertTrue(w!.contains("Accessibility"))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter PermissionTests`
Expected: FAIL — `permissionWarning` not defined.

**Step 3: Implement `Sources/PolishCore/Permissions.swift`**

```swift
import Foundation

public func permissionWarning(trust: TrustChecking, binaryPath: String) -> String? {
    guard !trust.isTrusted() else { return nil }
    return """
    polish: Accessibility permission missing — the app cannot read text or send keystrokes.

    Fix:
      1. Open System Settings > Privacy & Security > Accessibility.
      2. Click +, then add: \(binaryPath)
      3. Re-run polish.
    """
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter PermissionTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/Permissions.swift Tests/PolishCoreTests/PermissionTests.swift
git commit -m "feat: accessibility permission check and guidance"
```

---

### Task 11: Hotkey string parsing

**Files:**
- Create: `Sources/PolishCore/Hotkey.swift`
- Test: `Tests/PolishCoreTests/HotkeyTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/HotkeyTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class HotkeyTests: XCTestCase {
    func testParsesModifiersAndKey() throws {
        let hk = try parseHotkey("cmd+shift+j")
        XCTAssertEqual(hk.key, "j")
        XCTAssertEqual(hk.modifiers, [.command, .shift])
    }

    func testAltAndCtrl() throws {
        let hk = try parseHotkey("ctrl+alt+p")
        XCTAssertEqual(hk.modifiers, [.control, .option])
        XCTAssertEqual(hk.key, "p")
    }

    func testCaseInsensitive() throws {
        let hk = try parseHotkey("CMD+SHIFT+J")
        XCTAssertEqual(hk.key, "j")
    }

    func testInvalidThrows() {
        XCTAssertThrowsError(try parseHotkey("cmd+"))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter HotkeyTests`
Expected: FAIL — `parseHotkey` not defined.

**Step 3: Implement `Sources/PolishCore/Hotkey.swift`**

```swift
import Foundation

public enum HotkeyModifier: Equatable {
    case command, shift, option, control
}

public struct ParsedHotkey: Equatable {
    public var key: String
    public var modifiers: [HotkeyModifier]
}

public enum HotkeyError: Error, Equatable { case invalid(String) }

public func parseHotkey(_ spec: String) throws -> ParsedHotkey {
    let parts = spec.lowercased().split(separator: "+").map(String.init).filter { !$0.isEmpty }
    guard parts.count >= 2 else { throw HotkeyError.invalid(spec) }

    var modifiers: [HotkeyModifier] = []
    for m in parts.dropLast() {
        switch m {
        case "cmd", "command": modifiers.append(.command)
        case "shift": modifiers.append(.shift)
        case "alt", "option", "opt": modifiers.append(.option)
        case "ctrl", "control": modifiers.append(.control)
        default: throw HotkeyError.invalid(spec)
        }
    }
    let key = parts.last!
    guard key.count == 1 || key.count > 1 else { throw HotkeyError.invalid(spec) }
    return ParsedHotkey(key: key, modifiers: modifiers)
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter HotkeyTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/Hotkey.swift Tests/PolishCoreTests/HotkeyTests.swift
git commit -m "feat: hotkey string parsing"
```

---

### Task 12: CLI argument parsing

**Files:**
- Create: `Sources/PolishCore/Command.swift`
- Test: `Tests/PolishCoreTests/CommandTests.swift`

**Step 1: Write failing tests `Tests/PolishCoreTests/CommandTests.swift`**

```swift
import XCTest
@testable import PolishCore

final class CommandTests: XCTestCase {
    func testNoArgsRuns() { XCTAssertEqual(parseCommand([]), .run) }
    func testDoctor() { XCTAssertEqual(parseCommand(["doctor"]), .doctor) }
    func testStop() { XCTAssertEqual(parseCommand(["stop"]), .stop) }
    func testVersionFlag() { XCTAssertEqual(parseCommand(["--version"]), .version) }
    func testUnknownIsHelp() { XCTAssertEqual(parseCommand(["wat"]), .help) }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter CommandTests`
Expected: FAIL — `parseCommand` not defined.

**Step 3: Implement `Sources/PolishCore/Command.swift`**

```swift
import Foundation

public enum Command: Equatable {
    case run, doctor, stop, version, help
}

public func parseCommand(_ args: [String]) -> Command {
    switch args.first {
    case nil: return .run
    case "doctor": return .doctor
    case "stop": return .stop
    case "--version", "-v": return .version
    case "--help", "-h", "help": return .help
    default: return .help
    }
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter CommandTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PolishCore/Command.swift Tests/PolishCoreTests/CommandTests.swift
git commit -m "feat: cli command parsing"
```

---

### Task 13: Real adapters (AX, pasteboard, CGEvent, keychain, Carbon)

No unit tests; these are thin OS wrappers verified manually in Task 15.

**Files:**
- Create: `Sources/PolishCore/Adapters/SystemPasteboard.swift`
- Create: `Sources/PolishCore/Adapters/CGKeystrokes.swift`
- Create: `Sources/PolishCore/Adapters/AXCapturer.swift`
- Create: `Sources/PolishCore/Adapters/SystemFocus.swift`
- Create: `Sources/PolishCore/Adapters/KeychainStore.swift`
- Create: `Sources/PolishCore/Adapters/AXTrust.swift`
- Create: `Sources/PolishCore/Adapters/CarbonHotkey.swift`
- Create: `Sources/PolishCore/Adapters/ConfigFile.swift`

**Step 1: `SystemPasteboard.swift`**

```swift
import AppKit

public final class SystemPasteboard: Pasteboard {
    private let pb = NSPasteboard.general
    public init() {}
    public func string() -> String? { pb.string(forType: .string) }
    public func setString(_ value: String) {
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
    public func clear() { pb.clearContents() }
}
```

**Step 2: `CGKeystrokes.swift`**

```swift
import CoreGraphics

private let cmdKey: CGKeyCode = 0x37 // kVK_Command
private let cKey: CGKeyCode = 0x08   // kVK_ANSI_C
private let vKey: CGKeyCode = 0x09   // kVK_ANSI_V

public final class CGKeystrokes: KeystrokePosting {
    public init() {}

    public func copy() { press(cKey) }
    public func paste() { press(vKey) }

    private func press(_ key: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        usleep(20_000)
    }
}
```

**Step 3: `AXCapturer.swift`**

```swift
import ApplicationServices
import Foundation

public final class AXCapturer: TextCapturing {
    public init() {}

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused else { return nil }
        return (el as! AXUIElement)
    }

    public func selectedText() -> String? {
        guard let el = focusedElement() else { return nil }
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }

    public func fieldTextAndCaret() -> (text: [Character], caret: Int)? {
        guard let el = focusedElement() else { return nil }
        var valueRef: CFTypeRef?
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valueRef) == .success,
              let full = valueRef as? String,
              AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeVal = rangeRef else { return nil }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeVal as! AXValue, .cfRange, &cfRange) else { return nil }

        // AX offsets are UTF-16 code units; convert to character index.
        let utf16 = Array(full.utf16)
        let clamped = max(0, min(cfRange.location, utf16.count))
        let caret = String(decoding: utf16[0..<clamped], as: UTF16.self).count
        return (Array(full), caret)
    }
}
```

**Step 4: `SystemFocus.swift`**

```swift
import AppKit

public final class SystemFocus: FocusProviding {
    public init() {}
    public func frontmostAppID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
```

**Step 5: `AXTrust.swift`**

```swift
import ApplicationServices

public final class AXTrust: TrustChecking {
    public init() {}
    public func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }
    public func promptIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
```

**Step 6: `KeychainStore.swift`**

```swift
import Foundation
import Security

public final class KeychainStore: SecretStore {
    let service: String
    public init(service: String = "polish") { self.service = service }

    public func secret(for provider: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

**Step 7: `ConfigFile.swift`**

```swift
import Foundation

public func defaultConfigPath() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/.config/polish/config.toml"
}

public func loadConfig(path: String = defaultConfigPath()) throws -> Config {
    guard let data = FileManager.default.contents(atPath: path),
          let text = String(data: data, encoding: .utf8) else {
        return .default
    }
    return try Config.parse(text)
}
```

**Step 8: `CarbonHotkey.swift`**

```swift
import Carbon

public final class CarbonHotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onFire: () -> Void

    public init(onFire: @escaping () -> Void) { self.onFire = onFire }

    public func register(_ spec: ParsedHotkey) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<CarbonHotkey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onFire() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)

        let id = EventHotKeyID(signature: OSType(0x504F4C4B), id: 1) // 'POLK'
        RegisterEventHotKey(keyCode(spec.key), carbonModifiers(spec.modifiers), id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    private func keyCode(_ key: String) -> UInt32 {
        // Minimal map: extend as needed.
        switch key {
        case "j": return UInt32(kVK_ANSI_J)
        case "p": return UInt32(kVK_ANSI_P)
        default: return UInt32(kVK_ANSI_J)
        }
    }

    private func carbonModifiers(_ mods: [HotkeyModifier]) -> UInt32 {
        var out: UInt32 = 0
        for m in mods {
            switch m {
            case .command: out |= UInt32(cmdKey)
            case .shift: out |= UInt32(shiftKey)
            case .option: out |= UInt32(optionKey)
            case .control: out |= UInt32(controlKey)
            }
        }
        return out
    }
}
```

**Step 9: Verify it builds**

Run: `swift build`
Expected: builds. Fix any `Carbon`/`AXValue` casting issues (e.g. `rangeVal as! AXValue` may need `unsafeBitCast`; use `rangeVal as! AXValue` only if the compiler accepts it, otherwise `unsafeBitCast(rangeVal, to: AXValue.self)`).

**Step 10: Commit**

```bash
git add Sources/PolishCore/Adapters
git commit -m "feat: system adapters for ax, pasteboard, cgevent, keychain, carbon"
```

---

### Task 14: Daemon bootstrap + doctor command

**Files:**
- Modify: `Sources/polish/main.swift`
- Create: `Sources/PolishCore/Doctor.swift`
- Test: `Tests/PolishCoreTests/DoctorTests.swift`

**Step 1: Write failing test `Tests/PolishCoreTests/DoctorTests.swift`**

```swift
import XCTest
@testable import PolishCore

private struct FakeTrust2: TrustChecking {
    var trusted: Bool
    func isTrusted() -> Bool { trusted }
}

final class DoctorTests: XCTestCase {
    func testReportIncludesStatusAndConfig() {
        let report = doctorReport(
            config: .default,
            trust: FakeTrust2(trusted: true),
            binaryPath: "/x/polish",
            apiKeyPresent: false
        )
        XCTAssertTrue(report.contains("Accessibility: OK"))
        XCTAssertTrue(report.contains("provider: mock"))
        XCTAssertTrue(report.contains("api key: not set"))
    }
}
```

**Step 2: Run to verify failure**

Run: `swift test --filter DoctorTests`
Expected: FAIL — `doctorReport` not defined.

**Step 3: Implement `Sources/PolishCore/Doctor.swift`**

```swift
import Foundation

public func doctorReport(config: Config, trust: TrustChecking, binaryPath: String, apiKeyPresent: Bool) -> String {
    var lines: [String] = []
    lines.append("polish doctor")
    lines.append("  Accessibility: \(trust.isTrusted() ? "OK" : "MISSING")")
    lines.append("  binary: \(binaryPath)")
    lines.append("  config hotkey: \(config.hotkey)")
    lines.append("  provider: \(config.provider)")
    lines.append("  model: \(config.model)")
    lines.append("  api key: \(apiKeyPresent ? "set" : "not set")")
    if let w = permissionWarning(trust: trust, binaryPath: binaryPath) {
        lines.append("")
        lines.append(w)
    }
    return lines.joined(separator: "\n")
}
```

**Step 4: Run to verify pass**

Run: `swift test --filter DoctorTests`
Expected: PASS.

**Step 5: Rewrite `Sources/polish/main.swift`**

```swift
import AppKit
import PolishCore

let command = parseCommand(Array(CommandLine.arguments.dropFirst()))
let binaryPath = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "polish"

switch command {
case .version:
    print("polish \(Version.current)")

case .help:
    print("""
    usage: polish [command]
      (no args)   run the daemon
      doctor      print permission and config status
      stop        stop a running daemon
      --version   print version
    """)

case .doctor:
    let config = (try? loadConfig()) ?? .default
    let key = resolveAPIKey(provider: config.provider, store: KeychainStore())
    print(doctorReport(config: config, trust: AXTrust(), binaryPath: binaryPath, apiKeyPresent: key != nil))

case .stop:
    if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "local.polish") as [NSRunningApplication]?,
       let app = existing.first {
        app.terminate()
        print("polish: stopped")
    } else {
        print("polish: no running daemon found")
    }

case .run:
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)

    let config = (try? loadConfig()) ?? .default
    let trust = AXTrust()
    if let w = permissionWarning(trust: trust, binaryPath: binaryPath) {
        FileHandle.standardError.write((w + "\n").data(using: .utf8)!)
        trust.promptIfNeeded()
    }

    let llm: LLMService = config.provider == "mock" ? MockLLMService() : MockLLMService()
    let pipeline = Pipeline(
        capture: CaptureService(capturer: AXCapturer(), pasteboard: SystemPasteboard(), keystrokes: CGKeystrokes()),
        replace: ReplaceService(pasteboard: SystemPasteboard(), keystrokes: CGKeystrokes(), focus: SystemFocus()),
        llm: llm,
        config: config
    )

    let hotkey = try! parseHotkey(config.hotkey)
    let manager = CarbonHotkey { Task { await pipeline.run() } }
    manager.register(hotkey)
    print("polish: running, hotkey \(config.hotkey). Ctrl+C to quit.")

    app.run()
}
```

**Step 6: Build and run doctor**

Run: `swift build && swift run polish doctor`
Expected: prints the doctor report (Accessibility may say MISSING until granted — that's expected).

**Step 7: Commit**

```bash
git add Sources/polish/main.swift Sources/PolishCore/Doctor.swift Tests/PolishCoreTests/DoctorTests.swift
git commit -m "feat: daemon bootstrap and doctor command"
```

---

### Task 15: Manual integration verification + README

**Files:**
- Create: `README.md`

**Step 1: Ad-hoc sign and register the binary**

```bash
swift build -c release
codesign --force --sign - --entitlements /dev/stdin .build/release/polish <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>
EOF
```

**Step 2: Grant Accessibility permission**

Open System Settings > Privacy & Security > Accessibility, click `+`, add `.build/release/polish` (use Cmd+Shift+G to navigate to the hidden `.build` folder). Then restart the process.

**Step 3: Run the daemon**

Run: `.build/release/polish`
Expected: prints `polish: running, hotkey cmd+shift+j`.

**Step 4: Manual test checklist** (verify each by hand)

- [ ] TextEdit — select text, press hotkey → text replaced with `[polished] <text>`.
- [ ] Chrome/Gmail — same.
- [ ] VS Code — same.
- [ ] Slack — same.
- [ ] No selection, caret at end of a sentence in TextEdit → sentence before caret replaced.
- [ ] No selection in a non-AX app → clipboard fallback captures selection if any; otherwise prints "nothing to capture".
- [ ] Press hotkey with nothing focused → "nothing to capture", no paste.
- [ ] Click to another app during the 50ms-LLM window → prints "focus changed, skipped".
- [ ] Press hotkey twice rapidly → only one replace.
- [ ] Clipboard contents before/after a run are unchanged (restore works).
- [ ] Password field: selecting and pressing hotkey does not leak/copy the password.

**Step 5: Write `README.md`**

```markdown
# polish

macOS CLI daemon: press a hotkey to send the selected text (or the sentence
before the caret) to an LLM and replace it in place.

## Install / run

1. `swift build -c release`
2. Ad-hoc sign the binary (see plan Task 15) and add it to
   System Settings > Privacy & Security > Accessibility.
3. Copy `config.toml` to `~/.config/polish/config.toml` (see below) and run
   `.build/release/polish`.

## Config (`~/.config/polish/config.toml`)

    hotkey = "cmd+shift+j"
    provider = "mock"
    max_sentence_len = 400

## Commands

- `polish` — run the daemon
- `polish doctor` — permission + config status
- `polish stop` — stop the daemon
- `polish --version`

## MVP notes

- LLM is mocked (`[polished] ` prefix). Real providers are deferred.
- macOS only. Terminals and Linux are deferred.
```

**Step 6: Commit**

```bash
git add README.md
git commit -m "docs: add readme and manual verification checklist"
```

---

## Done criteria

- `swift run CoreTests` passes with all checks green (88/88). _(Plan originally said `swift test`.)_
- `swift run polish doctor` prints a correct report.
- All manual checklist items in Task 15 pass on the target Mac. _(Not yet fully run.)_

## Deferred (explicitly out of scope)

- ~~Real cloud LLM providers (OpenAI/Anthropic streaming).~~ **OpenAI-compatible client now implemented (non-streaming); Anthropic `/messages` still deferred.**
- Whole-field capture, terminal-specific handling, Linux.
- Result popup UI, preset prompts, free-form instruction box.
