# PolishBar Rename & Repository Polish — Design

Date: 2026-11-07
Status: Approved

## Intent

The project is a working macOS menu-bar app plus CLI that rewrites the selected
text (or the sentence before the caret) in place using an OpenAI-compatible
LLM. It has outgrown the working title "Polish" and the local directory
`opencode_polish`. Publish it as **PolishBar** — a name that says what the
product is — with a clean repository, a README someone can follow from zero,
and an MIT license.

## Goals

- Rename the project end to end: package, targets, modules, types, binary,
  app bundle, bundle identifier, config directory, environment variable,
  scripts, and active docs.
- Preserve the current behavior. No new product features.
- Commit the in-progress menu-bar work (key storage, API-key sheet, icon
  tooling) before the rename so its history stays readable.
- Add a README covering what it does, requirements, install/build, permissions,
  configuration, usage, architecture, and development.
- Add an MIT license.
- Verify: core test harness passes, release build succeeds, app bundle builds.
- Create `zhaiyiting/PolishBar` on GitHub as a public repository and push.

## Non-goals

- Notarization, Developer ID signing, CI, Homebrew packaging.
- New capture modes, UI redesign, or LLM-provider work.
- Keeping old configuration paths working indefinitely. This is a pre-1.0,
  unpublished project.

## Constraints

- macOS 13+, Swift 6 toolchain (Swift language mode 5), SwiftPM only.
- Renaming the bundle identifier resets the Accessibility grant and
  `UserDefaults`; the user must re-add the app in System Settings.
- The local environment already has `~/.config/polish/` and `POLISH_API_KEY`.
  Migrate the files as part of this work, and keep reading the legacy env var
  as a fallback.

## Approaches Considered

1. **Thorough rename (chosen).** Rename internals, paths, and public surface.
   Consistent afterward, one breaking change now, before anyone depends on it.
2. **Repository-only rename.** Least churn, but the package, binary, config
   path, and docs would keep saying "Polish" — the inconsistency this task is
   meant to remove.
3. **Keep the name.** No work, but "Polish" is ambiguous and already crowded.

## Decisions

| Surface | New value |
|---|---|
| GitHub repo / directory | `PolishBar` / `polishbar` |
| Swift package | `PolishBar` |
| Modules | `PolishBarCore`, `PolishBarMac` |
| Executables | `polishbar` (CLI), `PolishBar` (app) |
| Key types | `PolishBarController`, `PolishBarService` |
| Config | `~/.config/polishbar/config.toml` |
| API key file | `~/.config/polishbar/api-key` |
| Env var | `POLISHBAR_API_KEY` (legacy `POLISH_API_KEY` also accepted) |
| PID file | `~/.config/polishbar/polishbar.pid` |
| Bundle ID | `local.polishbar.app` |
| UserDefaults hint key | `polishbar.apiKeyHint` |
| License | MIT, Copyright 2026 Tyler Zhai |

Historical dated design/implementation docs stay as written; they are records.
The README and current docs use the new name.

## Migration

Copy `~/.config/polish/{config.toml,api-key}` to `~/.config/polishbar/` if the
destination files do not exist. Leave the old directory in place.

## What Is Left to the Builder

Commit granularity, exact README wording, and any incidental cleanup (stale
build artifacts, `.gitignore` additions).
