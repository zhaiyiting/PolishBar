#!/bin/sh
# Build (release), ad-hoc sign, and launch the polishbar daemon.
#
# Usage:
#   ./scripts/run.sh            # build, sign, run the daemon
#   ./scripts/run.sh doctor     # build, sign, then run any polishbar subcommand
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[run] building (release)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/polishbar"

echo "[run] ad-hoc signing: $BIN"
codesign --force --sign - --timestamp=none "$BIN"

echo "[run] binary: $BIN"
echo "[run] if the hotkey does nothing, add this path under"
echo "      System Settings > Privacy & Security > Accessibility."

exec "$BIN" "$@"
