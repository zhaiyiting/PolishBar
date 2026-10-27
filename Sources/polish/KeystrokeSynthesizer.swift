import CoreGraphics
import Carbon.HIToolbox

/// Posts synthetic keyboard shortcuts (requires Accessibility trust).
final class KeystrokeSynthesizer {
    func copy() { sendCommandKey(CGKeyCode(kVK_ANSI_C)) }
    func paste() { sendCommandKey(CGKeyCode(kVK_ANSI_V)) }

    private func sendCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
