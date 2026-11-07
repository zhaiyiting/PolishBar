#!/bin/sh
# Build the menu-bar app and assemble a signed Polish.app bundle.
#
# Usage: ./scripts/build-app.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Polish"
BUNDLE_ID="local.polish.app"
VERSION="0.1.0"
APP_DIR="$ROOT/dist/$APP_NAME.app"

echo "[app] building (release)…"
swift build -c release --product PolishApp
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "[app] assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/PolishApp" "$APP_DIR/Contents/MacOS/$APP_NAME"

ICON="$ROOT/Resources/AppIcon.icns"
if [ -f "$ICON" ]; then
    cp "$ICON" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "[app] warning: $ICON not found (run scripts/make-icon.swift)"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "[app] ad-hoc signing"
codesign --force --sign - "$APP_DIR"

echo
echo "Built: $APP_DIR"
echo
echo "Next:"
echo "  1. Grant Accessibility to the app so it can read text and paste:"
echo "     System Settings > Privacy & Security > Accessibility > + , then add:"
echo "     $APP_DIR"
echo "  2. Launch it (it lives in the menu bar). Use Start/Stop and Settings from the menu."
echo "  Optional: cp -R \"$APP_DIR\" /Applications/"
