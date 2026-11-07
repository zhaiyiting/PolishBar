/// The application that currently has keyboard focus.
public struct FocusedApp: Equatable, Sendable {
    public let pid: Int
    public let bundleID: String?

    public init(pid: Int, bundleID: String?) {
        self.pid = pid
        self.bundleID = bundleID
    }
}

/// Text captured from the focused app, plus the context needed to replace it.
public struct CapturedText: Equatable {
    /// The captured selection or sentence.
    public let text: String
    /// Which app it came from (used to skip the paste if focus moved).
    public let app: FocusedApp
    /// Opaque handle telling the replacer *how* to replace (e.g. an AX range or
    /// "use the active selection"). Nil means "paste over the active selection".
    public let anchor: TextAnchor?

    public init(text: String, app: FocusedApp, anchor: TextAnchor? = nil) {
        self.text = text
        self.app = app
        self.anchor = anchor
    }
}

/// Opaque replacement handle produced by the capturer and consumed by the replacer.
public struct TextAnchor: Equatable {
    /// Character range within the focused element's value, when known.
    public let range: Range<Int>?
    public init(range: Range<Int>?) { self.range = range }
}

/// Reports the frontmost application.
public protocol FocusProviding {
    func frontmostApp() -> FocusedApp?
}

/// Captures text from the focused app.
public protocol TextCapturing {
    /// - Parameter maxSentenceLength: cap used by sentence mode.
    func capture(focusedApp: FocusedApp, maxSentenceLength: Int) -> CapturedText?
}

/// Replaces previously captured text with new text.
public protocol TextReplacing {
    /// - Returns: true on success.
    func replace(captured: CapturedText, with newText: String) -> Bool
}

/// Transforms text (e.g. calls an LLM to polish it).
public protocol LLMService {
    func transform(_ text: String) async throws -> String
}
