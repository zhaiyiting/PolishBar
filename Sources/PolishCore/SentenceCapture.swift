/// A sentence located immediately before the caret.
public struct CapturedSentence: Equatable, Sendable {
    /// The sentence text (whitespace-trimmed, length-capped).
    public let text: String
    /// Character offset of `text`'s first character within the original string.
    public let start: Int

    public init(text: String, start: Int) {
        self.text = text
        self.start = start
    }
}

/// Pure logic for locating the sentence immediately before the caret.
///
/// There is no OS-wide "select sentence" primitive, so callers read the full
/// field text plus the caret offset and use this to derive the range.
public enum SentenceCapture {
    private static let terminators: Set<Character> = [".", "?", "!", "。", "？", "！", "\n"]

    /// Returns the sentence ending at `caret` (exclusive), or `nil` when there is
    /// no non-whitespace text between the caret and the nearest boundary.
    ///
    /// - Parameters:
    ///   - text: the full text of the focused field.
    ///   - caret: caret offset in `Character` units (0...`text.count`).
    ///   - maxLength: maximum number of characters to return; the text nearest the
    ///     caret is kept when the sentence is longer.
    public static func beforeCaret(in text: String, caret: Int, maxLength: Int) -> CapturedSentence? {
        guard caret > 0, maxLength > 0 else { return nil }

        let chars = Array(text)
        guard caret <= chars.count, !chars.isEmpty else { return nil }

        var start = 0
        var i = caret - 1
        while i >= 0 {
            if terminators.contains(chars[i]) {
                start = i + 1
                break
            }
            i -= 1
        }

        var lower = start
        var upper = caret
        while lower < upper, chars[lower].isWhitespace { lower += 1 }
        while upper > lower, chars[upper - 1].isWhitespace { upper -= 1 }

        guard lower < upper else { return nil }

        if upper - lower > maxLength {
            lower = upper - maxLength
        }

        return CapturedSentence(text: String(chars[lower..<upper]), start: lower)
    }
}
