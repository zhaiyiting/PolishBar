#!/bin/sh
# Compile and run the Foundation-free PolishCore tests with swiftc directly.
# (SwiftPM is unavailable in some Command Line Tools installs; this bypasses it.)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.build-core"
mkdir -p "$OUT"

SWIFTC="${SWIFTC:-swiftc}"

"$SWIFTC" -module-name PolishCore \
    -emit-library -emit-module \
    -o "$OUT/libPolishCore.dylib" \
    "$ROOT"/Sources/PolishCore/*.swift

"$SWIFTC" \
    -I "$OUT" -L "$OUT" -lPolishCore \
    -Xlinker -rpath -Xlinker "$OUT" \
    -o "$OUT/coretests" \
    "$ROOT"/Tests/CoreTests/*.swift

"$OUT/coretests"
