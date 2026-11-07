#!/bin/sh
# Compile and run the PolishBarCore tests with swiftc directly.
# (Bypasses SwiftPM; handy on Command Line Tools installs where SwiftPM is broken.)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.build-core"
mkdir -p "$OUT"

SWIFTC="${SWIFTC:-swiftc}"

"$SWIFTC" -module-name PolishBarCore \
    -emit-library -emit-module \
    -o "$OUT/libPolishBarCore.dylib" \
    "$ROOT"/Sources/PolishBarCore/*.swift

"$SWIFTC" \
    -I "$OUT" -L "$OUT" -lPolishBarCore \
    -Xlinker -rpath -Xlinker "$OUT" \
    -o "$OUT/coretests" \
    "$ROOT"/Tests/PolishBarTests/*.swift

"$OUT/coretests"
