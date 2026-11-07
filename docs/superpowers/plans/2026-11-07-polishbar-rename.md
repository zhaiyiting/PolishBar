# PolishBar Rename & Repository Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the project end to end to PolishBar, tidy the repository, add README + MIT license, and publish it publicly on GitHub.

**Architecture:** Mechanical rename across four SwiftPM targets, runtime paths, and packaging scripts, followed by documentation and publication. Behavior must not change; the existing 92-check core harness is the regression gate.

**Tech Stack:** Swift 6 / SwiftPM, macOS 13+, AppKit/SwiftUI, shell scripts, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-11-07-polishbar-rename-design.md`

## Global Constraints

- macOS 13+; Swift language mode 5.
- New names: package `PolishBar`; modules `PolishBarCore`, `PolishBarMac`; binaries `polishbar`, `PolishBar`; bundle ID `local.polishbar.app`; config dir `~/.config/polishbar`; env `POLISHBAR_API_KEY` (legacy `POLISH_API_KEY` also accepted).
- No product behavior changes.
- Historical dated docs under `docs/plans/` are records; do not rewrite them.
- Never commit `~/.config/polishbar/api-key` or the value of `POLISH_API_KEY`.

## Review Focus

- Typing into a text field with no selection captures the preceding sentence — unchanged by the rename.
- Missing API key still produces the same actionable error instead of a crash.
- Focus change between capture and paste still aborts the replace.
- Legacy `POLISH_API_KEY` still resolves so the current shell keeps working.
- Fresh clone builds and tests without the old `Polish` names leaking in.

---

### Task 1: Commit in-progress work

**Files:**
- Modify: all currently modified/untracked source files.

- [ ] **Step 1: Verify the baseline harness**

Run: `./scripts/test-core.sh`
Expected: `94 checks, 0 failed` and `ALL PASS`.

- [ ] **Step 2: Commit the in-progress menu-bar work**

```bash
git add -A
git commit -m "feat: API key sheet, shared key store, and app icon tooling"
```

- [ ] **Step 3: Confirm a clean tree**

Run: `git status --short`
Expected: no output.

### Task 2: Rename Swift package, modules, and types

**Files:**
- Modify: `Package.swift`
- Rename: `Sources/PolishCore` → `Sources/PolishBarCore`
- Rename: `Sources/PolishMac` → `Sources/PolishBarMac`
- Rename: `Sources/PolishApp` → `Sources/PolishBarApp`
- Rename: `Sources/polish` → `Sources/polishbar`
- Rename: `Tests/CoreTests` → `Tests/PolishBarTests`
- Modify: all `*.swift` files under `Sources/` and `Tests/`

**Interfaces:**
- Produces: modules `PolishBarCore`, `PolishBarMac`; types `PolishBarController`, `PolishBarService`, `PolishBarAppMain`; function `makePolishBarLLM(config:apiKey:log:)`.

- [ ] **Step 1: Move directories with `git mv`**

```bash
git mv Sources/PolishCore Sources/PolishBarCore
git mv Sources/PolishMac Sources/PolishBarMac
git mv Sources/PolishApp Sources/PolishBarApp
git mv Sources/polish Sources/polishbar
git mv Tests/CoreTests Tests/PolishBarTests
git mv Sources/PolishBarMac/PolishLLM.swift Sources/PolishBarMac/PolishBarLLM.swift
git mv Sources/PolishBarMac/PolishService.swift Sources/PolishBarMac/PolishBarService.swift
git mv Sources/PolishBarApp/PolishAppMain.swift Sources/PolishBarApp/PolishBarAppMain.swift
```

- [ ] **Step 2: Rewrite identifiers**

Apply these exact replacements across `Sources/`, `Tests/`, and `Package.swift`:
`PolishCore`→`PolishBarCore`, `PolishMac`→`PolishBarMac`, `PolishApp`→`PolishBarApp`,
`PolishController`→`PolishBarController`, `PolishService`→`PolishBarService`,
`PolishAppMain`→`PolishBarAppMain`, `makePolishLLM`→`makePolishBarLLM`,
`CoreTests`→`PolishBarTests`. Package product names: `polish`→`polishbar`,
`PolishBarApp`→`PolishBar`.

- [ ] **Step 3: Run the harness**

Run: `./scripts/test-core.sh` (first update its `-module-name`/library names to `PolishBarCore`)
Expected: `94 checks, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename package, modules, and types to PolishBar"
```

### Task 3: Rename runtime surface and migration

**Files:**
- Modify: `Sources/PolishBarMac/ConfigStore.swift`, `KeyStore.swift`, `Permissions.swift`
- Modify: `Sources/polishbar/main.swift`, `Daemon.swift`
- Modify: `Sources/PolishBarApp/AppModel.swift`, `PolishBarAppMain.swift`, `SettingsView.swift`, `APIKeySheet.swift`
- Modify: `scripts/build-app.sh`, `scripts/run.sh`, `config.example.toml`
- Migrate: `~/.config/polish/{config.toml,api-key}` → `~/.config/polishbar/`

- [ ] **Step 1: Replace runtime strings**

`~/.config/polish`→`~/.config/polishbar`; `polish.pid`→`polishbar.pid`;
`POLISH_API_KEY`→`POLISHBAR_API_KEY`; `local.polish.app`→`local.polishbar.app`;
`polish.apiKeyHint`→`polishbar.apiKeyHint`; `[polish]`→`[polishbar]`;
`Quit Polish`→`Quit PolishBar`; `Polish Settings`→`PolishBar Settings`;
CLI usage text `polish`→`polishbar`; script binary `polish`→`polishbar`.

- [ ] **Step 2: Keep the legacy env var readable**

In `main.swift`, `Daemon.swift`, and `AppModel.swift`, resolve
`POLISHBAR_API_KEY` first, then fall back to `POLISH_API_KEY`.

- [ ] **Step 3: Migrate the local config**

```bash
mkdir -p ~/.config/polishbar
[ -f ~/.config/polishbar/config.toml ] || cp ~/.config/polish/config.toml ~/.config/polishbar/config.toml
[ -f ~/.config/polishbar/api-key ] || cp -p ~/.config/polish/api-key ~/.config/polishbar/api-key
```

- [ ] **Step 4: Run checks and build**

Run: `./scripts/test-core.sh && swift build -c release && ./scripts/build-app.sh`
Expected: tests pass; `dist/PolishBar.app` is produced.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename runtime paths, env vars, and app bundle to PolishBar"
```

### Task 4: README, license, and repository tidying

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Modify: `.gitignore` if gaps appear

- [ ] **Step 1: Write README.md**

Cover: what it does; how it works (hotkey → capture → LLM → in-place replace);
requirements; build (`swift build -c release`) and app packaging
(`./scripts/build-app.sh`); Accessibility permission steps; API key
(`POLISHBAR_API_KEY` or `~/.config/polishbar/api-key`); configuration table for
every key in `config.example.toml`; CLI subcommands; architecture/module map;
tests (`./scripts/test-core.sh` or `swift run PolishBarTests`); license.

- [ ] **Step 2: Add MIT LICENSE**

Copyright line: `Copyright (c) 2026 Tyler Zhai`.

- [ ] **Step 3: Scan for stale names**

Run: `grep -rn "PolishCore\|PolishMac\|PolishApp\|PolishController\|local\.polish\.app\|config/polish/\|POLISH_API_KEY" README.md Sources Tests scripts config.example.toml Package.swift`
Expected: only the intentional legacy env-var fallback hits.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: add README and MIT license"
```

### Task 5: Publish to GitHub

**Files:** none.

- [ ] **Step 1: Rename the local directory**

```bash
cd .. && mv opencode_polish polishbar
```

- [ ] **Step 2: Create and push the public repository**

```bash
gh repo create zhaiyiting/PolishBar --public \
  --description "Menu-bar macOS app that rewrites selected text in place with an LLM" \
  --source=. --remote=origin --push
```

- [ ] **Step 3: Verify**

Run: `gh repo view zhaiyiting/PolishBar --json name,visibility,url,defaultBranchRef`
Expected: `PolishBar`, `PUBLIC`, branch `main`.

- [ ] **Step 4: Final status check**

Run: `git status --short && git log --oneline -5`
Expected: clean tree; three new commits on `main`.
