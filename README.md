# PolishBar

A tiny macOS menu-bar app that rewrites the text you are writing — in place, with one hotkey.

Select a sentence (or just leave the caret at the end of one), press `⌘⇧J`, and PolishBar sends it to an LLM, then pastes the polished result back over the original. It works in any app that supports copy and paste: Mail, Slack, Chrome, VS Code, Notes, terminals.

PolishBar is especially useful when you write in a second language: the default prompt fixes grammar, spelling, punctuation, and word choice, translates Chinese into idiomatic English, and preserves your meaning, tone, technical terms, code, and formatting.

## Features

- **Rewrite in place.** No extra window, no copy/paste by hand. The original clipboard is snapshotted and restored.
- **Selection or preceding sentence.** With text selected, it polishes the selection. With no selection, it finds the sentence before the caret.
- **Any OpenAI-compatible endpoint.** OpenAI, Command Code, OpenRouter, Ollama, LM Studio, or your own gateway — set the base URL and model.
- **Menu-bar app for everyday use.** Start/stop, settings, API-key sheet, Accessibility status, and a live log.
- **CLI for scripting and headless use.** `polishbar exec`, `doctor`, `stop`.
- **One shared kernel.** The app and CLI drive the same `PolishBarService`; pure logic is unit-tested.

## Requirements

- macOS 13 Ventura or later
- Swift 6 toolchain (Xcode 16 or the Swift toolchain from swift.org)
- An API key for an OpenAI-compatible chat-completions endpoint

## Install

```bash
git clone https://github.com/zhaiyiting/PolishBar.git
cd PolishBar
./scripts/build-app.sh
open dist/PolishBar.app
```

The script builds a release binary, assembles `dist/PolishBar.app` with its icon and `Info.plist`, and ad-hoc signs the bundle. To keep it around, copy it to Applications:

```bash
cp -R dist/PolishBar.app /Applications/
```

### Grant Accessibility permission

macOS requires Accessibility (TCC) trust before an app may read text with the
Accessibility API or synthesize `⌘C` / `⌘V`. Without it, the hotkey appears to do
nothing.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Click **+** and add `PolishBar.app` (the built bundle or the copy in Applications).
3. Turn the switch on. If it was already on after a rebuild, turn it off and on again.

In the app, **Settings → Service → Open Settings** jumps to that pane, while
**Grant Access…** raises the macOS permission prompt.

The CLI binary needs the same permission when run from a terminal; grant it to
the terminal app or the built `polishbar` binary.

### Upgrading from the old `Polish` name

Move your existing settings and key, then stop any daemon started by the old
build:

```bash
mkdir -p ~/.config/polishbar
cp ~/.config/polish/config.toml ~/.config/polishbar/config.toml
cp -p ~/.config/polish/api-key ~/.config/polishbar/api-key
kill "$(cat ~/.config/polish/polish.pid)" 2>/dev/null || true
```

The bundle identifier changed, so grant Accessibility to the new `PolishBar.app`
again.

## API key

Set the key in **Settings → Set API Key…**. It is stored in a user-only file:

```
~/.config/polishbar/api-key   (0600)
```

You can also provide it through the environment, which takes precedence:

```bash
export POLISHBAR_API_KEY="sk-..."
```

The pre-rename variable `POLISH_API_KEY` is still read as a fallback.

A copy of the app launched from Finder or the Dock does not inherit shell
exports, so use Settings for the app and export the variable when running the
CLI.

## Usage

1. Put the caret in a text field, or select the text you want to rewrite.
2. Press `⌘⇧J` (configurable).
3. Wait a moment. The text is replaced when the result comes back.

If you change the frontmost app mid-request, PolishBar skips the replace rather
than pasting into the wrong window.

### CLI

```bash
swift build -c release
./scripts/run.sh              # build, sign, start the daemon
./scripts/run.sh doctor       # permissions, config, and key status
./scripts/run.sh exec "text"  # one-shot transform, print the result
./scripts/run.sh stop         # stop the running daemon
```

`polishbar` with no arguments is the same as `polishbar run`.

## Configuration

The app writes `~/.config/polishbar/config.toml` automatically as you edit
Settings. You can also edit it by hand; `config.example.toml` documents every
key.

| Key | Default | Meaning |
|---|---|---|
| `hotkey` | `"cmd+shift+j"` | Global hotkey. Modifiers: `cmd`, `shift`, `alt`, `ctrl`. |
| `provider` | `"openai"` | Label only; any OpenAI-compatible endpoint works. |
| `model` | `"gpt-4o-mini"` | Model name sent to the endpoint. |
| `base_url` | `"https://api.openai.com/v1"` | Chat-completions base URL. |
| `prompt` | built-in editor prompt | Instruction sent with the text. |
| `capture_mode` | `"selection_then_sentence"` | Capture strategy. |
| `max_sentence_len` | `400` | Cap on the preceding-sentence capture. |
| `clipboard_restore_delay_ms` | `250` | Delay before restoring the clipboard after paste. |
| `reasoning_effort` | unset | Passed through as `reasoning_effort`; `"off"` for Command Code, `"minimal"`/`"low"` for most OpenAI-style endpoints, or omit for the provider default. |
| `log_raw_response` | `false` | Log the full raw LLM response (to verify thinking/reasoning). |

## How it works

```
hotkey ──▶ capture ──▶ LLM transform ──▶ replace in place
             │                              │
      AX selection / value          pasteboard + ⌘V
      clipboard fallback            focus re-check first
```

- `PolishBarCore` — pure logic: config parsing, sentence-boundary capture,
  the capture→transform→replace controller, OpenAI wire codec, prompt.
- `PolishBarMac` — macOS kernel: Accessibility reads/writes, pasteboard,
  Carbon hotkey, synthesized keystrokes, permissions, key storage, LLM client.
- `PolishBarApp` — SwiftUI menu-bar front-end.
- `polishbar` — CLI daemon and subcommands.

Every OS touchpoint sits behind a protocol, so the orchestration is tested with
fakes.

## Development

```bash
./scripts/test-core.sh   # compile core + tests directly with swiftc (94 checks)
swift run PolishBarTests # same harness through SwiftPM
swift build              # debug build
./scripts/build-app.sh   # release app bundle in dist/
```

The test harness is dependency-free and runs on Command Line Tools installs
where SwiftPM's test support may be unavailable.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Hotkey does nothing | Grant Accessibility to `PolishBar.app`; after rebuilding, toggle the permission off and on. |
| `Hotkey failed` | Another app owns the shortcut; pick a different `hotkey`. |
| `No API key` | Set one in Settings or export `POLISHBAR_API_KEY`. |
| Nothing was captured | Select text, or put the caret after a sentence in a normal text field. Secure fields intentionally expose nothing. |
| Paste did not happen | You switched apps mid-request; PolishBar refuses to paste into the wrong window. |
| Request fails / 401 | Check `base_url`, `model`, and the key. Use `doctor` and the app log. |

## Privacy

PolishBar has no telemetry and no bundled analytics. The captured text and your
prompt are sent only to the `base_url` you configure. The API key lives in a
`0600` file or your environment; it is never written into `config.toml`.

## License

MIT — see [LICENSE](LICENSE).
