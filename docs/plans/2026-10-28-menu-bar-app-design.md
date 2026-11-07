# Menu-bar App Wrapper — Design

Date: 2026-10-28
Status: Implemented (builds; GUI not yet manually exercised)

## Goal

Add a real macOS menu-bar app that can **start/stop the service and edit the
configuration**, without disturbing the existing CLI daemon. Same core, one
kernel: users drive the app, developers drive the CLI.

## Module split

The integration code used to live inside the `polish` executable, so nothing
could reuse it. It is now a library:

- **`PolishCore`** (unchanged): pure logic + wire codec (`Config`,
  `SentenceCapture`, `PolishController`, `OpenAIWire`, `LLMService`,
  `LoggingLLMService`, `DefaultPrompt`, `Version`, `APIKeyResolver`).
- **`PolishMac`** (new library): the shared "kernel" — `AXText`, `Clipboard`,
  `CloudLLMService`, `ConfigStore`, `HotkeyManager`, `Keychain`, `Permissions`,
  `SystemFocus`, `KeystrokeSynthesizer`, `makePolishLLM`, and the new
  **`PolishService`**.
- **`polish`** (CLI executable, dev): `main.swift` + `Daemon` only.
- **`PolishApp`** (new SwiftUI executable, users): menu-bar app.

## Shared kernel: `PolishService`

`PolishService.start()`/`stop()` own the hotkey registration and the
capture→transform→replace controller. It does **not** run an event loop — the
caller owns that:

- CLI daemon: `NSApplication.shared.run()` (AppKit loop delivers Carbon hotkeys).
- App: SwiftUI's run loop (MenuBarExtra).

Both front-ends therefore behave identically; the app is not a reimplementation.

## Config persistence

The app must write settings. Added:

- `Config.encode()` — flat-TOML serializer, round-trip tested
  (`Config.parse(Config.encode(c)) == c`), with `\n`/`\t`/`"`/`\` escaping and a
  matching parser `decodeString` + escape-aware comment stripping.
- `ConfigStore.save(_:)`.
- `KeyStore` — the API key lives in a user-only (0600) file
  `~/.config/polish/api-key`, **not** the keychain: an ad-hoc-signed app's
  identity changes on every rebuild, so the keychain re-prompts for access each
  time. Resolution order: env `POLISH_API_KEY` → file. The app caches the key in
  memory (read once) to avoid repeated disk reads.

## App UI

- **Menu bar** (`MenuBarExtra`): status line, Start/Stop, Settings…, Quit.
- **Settings window** (`Window(id: "settings")`, opened via `openWindow`):
  service status + Accessibility grant buttons, LLM fields (provider, model,
  base URL, `reasoning_effort`), hotkey & capture fields, the prompt (text
  editor), and a live log pane.
- **Settings auto-save**: there is no Save button. Any config change is written
  800 ms after typing stops (and flushed on window close); if the service is
  running it restarts so changes take effect.
- **API key**: set/replaced via a **popup sheet** ("Set API Key…" / "Change…"),
  with a status badge showing `Configured ••••1234` / `Not configured`. Stored in
  `~/.config/polish/api-key` (0600); a non-secret last-4 hint is kept in
  `UserDefaults`.

## Packaging & permissions

`scripts/build-app.sh` builds `PolishApp` (release), assembles
`dist/Polish.app` (Info.plist with `LSUIElement=true`, bundle id
`local.polish.app`, `AppIcon.icns`), and ad-hoc signs it. The icon is generated
by `scripts/make-icon.swift` (Core Graphics) → `Resources/AppIcon.icns`.
Accessibility permission attaches to the **.app**, not the binary: add
`dist/Polish.app` under System Settings → Privacy & Security → Accessibility.

## App vs CLI

Independent, last-wins: no lock file. If both register the same hotkey, the
second registration fails and is logged; the process keeps running.

## Testing

- Round-trip config encode/parse via the `CoreTests` harness (92 checks green).
- `PolishService` is thin glue over `PolishController` (already unit-tested with
  fakes); the OS adapters are verified manually.
- Manual GUI checklist: launch, Start/Stop, Save, Accessibility prompt, run a
  hotkey capture from the app.

## Deferred

- Hotkey recorder widget (currently a text field).
- In-app config import/export, multiple profiles.
- Notarization / Developer ID signing.
