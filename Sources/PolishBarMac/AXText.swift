import ApplicationServices
import Foundation
import PolishBarCore

/// Captures text from the focused element (AX first, clipboard fallback) and
/// replaces text via the pasteboard.
///
/// Capture strategy:
///  1. If a selection exists, use it.
///  2. Otherwise read the field value + caret and select the sentence before
///     the caret (so the later paste replaces exactly that range).
///  3. If AX yields nothing usable, synthesize Cmd+C and read the pasteboard.
final class AXText: TextCapturing, TextReplacing {
    private let clipboard: Clipboard
    private let synth: KeystrokeSynthesizer
    private let copySettleMS: Int
    private let restoreDelayMS: Int

    init(clipboard: Clipboard, synth: KeystrokeSynthesizer, copySettleMS: Int = 120, restoreDelayMS: Int = 250) {
        self.clipboard = clipboard
        self.synth = synth
        self.copySettleMS = copySettleMS
        self.restoreDelayMS = restoreDelayMS
    }

    // MARK: - TextCapturing

    func capture(focusedApp: FocusedApp, maxSentenceLength: Int) -> CapturedText? {
        if let element = Self.focusedElement() {
            if let selection = Self.stringAttribute(element, kAXSelectedTextAttribute), !selection.isEmpty {
                return CapturedText(text: selection, app: focusedApp)
            }

            if let value = Self.stringAttribute(element, kAXValueAttribute),
               let caret16 = Self.selectedRange(element)?.location,
               let caret = Self.characterOffset(fromUTF16: caret16, in: value),
               let sentence = SentenceCapture.beforeCaret(in: value, caret: caret, maxLength: maxSentenceLength),
               let start16 = Self.utf16Offset(ofCharacter: sentence.start, in: value),
               let end16 = Self.utf16Offset(ofCharacter: sentence.start + sentence.text.count, in: value) {
                Self.setSelectedRange(element, CFRange(location: start16, length: end16 - start16))
                let range = sentence.start..<(sentence.start + sentence.text.count)
                return CapturedText(text: sentence.text, app: focusedApp, anchor: TextAnchor(range: range))
            }
        }

        return clipboardFallback(focusedApp)
    }

    private func clipboardFallback(_ app: FocusedApp) -> CapturedText? {
        let saved = clipboard.snapshot()
        let before = clipboard.changeCount
        synth.copy()
        wait(copySettleMS)

        defer { clipboard.restore(saved) }
        guard clipboard.changeCount != before,
              let text = clipboard.readString(),
              !text.isEmpty else { return nil }
        return CapturedText(text: text, app: app)
    }

    // MARK: - TextReplacing

    func replace(captured: CapturedText, with newText: String) -> Bool {
        let saved = clipboard.snapshot()
        clipboard.writeString(newText)
        synth.paste()
        wait(restoreDelayMS)
        clipboard.restore(saved)
        return true
    }

    private func wait(_ milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
    }

    // MARK: - AX helpers

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return (value as! String)
    }

    private static func selectedRange(_ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func setSelectedRange(_ element: AXUIElement, _ range: CFRange) {
        var range = range
        guard let axValue = AXValueCreate(.cfRange, &range) else { return }
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue)
    }

    private static func characterOffset(fromUTF16 location: Int, in text: String) -> Int? {
        guard location >= 0, location <= text.utf16.count else { return nil }
        let index16 = text.utf16.index(text.utf16.startIndex, offsetBy: location)
        guard let index = String.Index(index16, within: text) else { return nil }
        return text.distance(from: text.startIndex, to: index)
    }

    private static func utf16Offset(ofCharacter offset: Int, in text: String) -> Int? {
        guard offset >= 0, offset <= text.count else { return nil }
        let index = text.index(text.startIndex, offsetBy: offset)
        guard let index16 = index.samePosition(in: text.utf16) else { return nil }
        return text.utf16.distance(from: text.utf16.startIndex, to: index16)
    }
}
