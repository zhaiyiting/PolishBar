# Text Polish Daemon — Design

Date: 2026-10-27
Status: Validated (design approved, implementation not started)

## Problem

Capturing input text anywhere in the OS via a hotkey, sending it to an LLM, and
replacing it in place. Sources include terminals, browsers, and other apps.

## MVP Scope

- **Platform:** macOS only (Linux later).
- **Form:** a command-line daemon (no menubar, no dock icon, no UI window). Started
  from the terminal; config read from a file.
- **Action:** one fixed action — polish/rewrite the captured text — then replace it
  in place.
- **LLM:** cloud API with the user's own key, but **mocked for MVP** (`provider = "mock"`).

### Capture modes (both in MVP)

- **Mode A — selection present:** capture the selected text.
- **Mode B — no selection:** capture the sentence immediately before the caret.

### Deferred (not in MVP)

- Whole-field capture (entire focused input).
- Terminal-specific handling.
- Linux support.
- Preset prompt list / free-form instruction box.
- Result popup UI.
- Real cloud LLM integration (interface is defined; body is mocked).

## Architecture

1. **Daemon** — `NSApplication` with `.prohibited` activation policy, no window or
   status item. Holds the run loop for the global hotkey. Quit via `Ctrl+C` or
   `polish stop`.
2. **Config** — TOML file at `~/.config/polish/config.toml`.
3. **HotkeyManager** — global hotkey via Carbon `RegisterEventHotKey`.
4. **CaptureService** — Mode A/B logic through AX; clipboard-synthesis fallback.
5. **ClipboardManager** — snapshot/restore the pasteboard around capture and replace.
6. **InputSynthesizer** — `CGEvent` posting of `Cmd+C` / `Cmd+V`.
7. **LLMService** — mocked transformer with the same interface as the future
   streaming client.
8. **Replacer** — paste result over the active range via pasteboard + `Cmd+V`.
9. **PermissionManager** — Accessibility (TCC) trust check/request/guidance.

Every OS touchpoint sits behind a protocol so the orchestration logic is testable.

## Data Flow

1. **Hotkey** (`Cmd+Shift+J`) fires the Carbon handler.
2. **Snapshot:** record `NSWorkspace.shared.frontmostApplication` and set a processing
   guard (ignore re-press while busy).
3. **Capture (CaptureService):**
   - `AXUIElementCreateSystemWide()` -> `kAXFocusedUIElement`.
   - **Mode A:** read `kAXSelectedText`. Non-empty -> use it; remember the selected range.
   - **Mode B:** read `kAXValue` (full text) + `kAXSelectedTextRange` (caret). Walk
     backward to a sentence boundary (`. ? ! 。 ？ ！` and newline), capped at
     `max_sentence_len`. Programmatically set the AX selection to that range; use the
     substring.
   - **Fallback:** if AX yields nothing usable, snapshot the clipboard, synthesize
     `Cmd+C`, and read the pasteboard. Text -> use it; otherwise log
     "nothing to capture" and abort.
4. **LLM:** `LLMService.transform(text)` (mocked) with a small async delay.
5. **Replace (Replacer):** put the result on the pasteboard -> verify the frontmost app
   still matches the snapshot -> synthesize `Cmd+V` (this replaces the active
   selection/range) -> brief delay -> restore the original clipboard.
6. **Log** the outcome.

### Why the clipboard path is still used

AX reads/writes are clean but inconsistent (Electron, terminals, and many custom
views do not expose value/selection). The pasteboard path (synthesized `Cmd+C` /
`Cmd+V`) works almost everywhere, so it is the fallback for capture and the mechanism
for replace. The clipboard is snapshotted and restored so the user's clipboard is
preserved.

## Config

`~/.config/polish/config.toml`:

```toml
hotkey = "cmd+shift+j"
provider = "mock"          # mock | openai | anthropic
model = "gpt-4o-mini"
base_url = "https://api.openai.com/v1"
prompt = "Rewrite the following text to be clear and concise. Reply with only the rewritten text."
capture_mode = "selection_then_sentence"
max_sentence_len = 400
clipboard_restore_delay_ms = 250
```

**API key precedence:** env (`POLISH_API_KEY`) > Keychain > error. Only required once
`provider != mock`.

## Permissions

All of the following require macOS **Accessibility (TCC)** trust, and fail **silently**
without it:

- Posting `CGEvent`s (synthetic `Cmd+C` / `Cmd+V`).
- Reading AX attributes (`kAXSelectedText`, `kAXValue`, `kAXSelectedTextRange`).

Plain `NSPasteboard` access does **not** require this permission.

`PermissionManager`:

1. Checks `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`.
2. If untrusted, prompts and opens System Settings -> Privacy -> Accessibility, with
   guidance to add the binary path manually.
3. Exposes status so the daemon prints a clear startup warning and supports a
   `polish doctor` subcommand instead of silent failure.
4. Re-checks, because a restart is usually required after the user grants permission.

**Gotcha:** a bare CLI binary must be ad-hoc code-signed and added to
System Settings -> Privacy -> Accessibility by hand.

## CLI

- `polish` — start the daemon.
- `polish doctor` — print permission + config status.
- `polish stop` — stop a running daemon.
- `polish --version`.

## Project Layout (SwiftPM)

```
Package.swift
Sources/polish/         # executable: CLI args, daemon bootstrap
Sources/PolishCore/     # all logic, behind protocols
Tests/PolishCoreTests/
```

## Testability

Protocols abstract every OS touchpoint:

- `TextCapturing` (AX + clipboard), `TextReplacing`, `Pasteboard`,
  `KeystrokePosting`, `FocusProviding`, `LLMService`.

### Unit tests (XCTest, `swift test`)

- Sentence-boundary computation: punctuation, CJK `。？！`, newlines, `max_sentence_len` cap.
- Config parsing and API-key precedence.
- Mock LLM behavior.
- Replace-flow orchestration with fake capture/pasteboard.
- Abort-on-focus-change.

### Manual integration checklist

AX + `CGEvent` cannot be unit-tested. Verify by hand in:

- TextEdit, Chrome/Gmail, VS Code, Slack, Terminal.
- Both selection and no-selection cases.
- "Nothing copied" and "clicked away mid-flow" cases.

## Error Handling

- Nothing focused / no usable text -> abort with a log line.
- Non-AX app + empty `Cmd+C` -> abort.
- Frontmost app changed between hotkey and paste -> skip replace (never paste into the
  wrong window).
- Reentrancy while processing -> debounce.
- Secure/password fields: AX empty and copy often blocked -> naturally safe.

## Open Questions

- None blocking. Terminal-specific capture and Linux are explicitly deferred.
