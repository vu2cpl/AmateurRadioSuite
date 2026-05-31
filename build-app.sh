#!/bin/bash
# Build "Amateur Radio Suite.app" — a double-clickable macOS bundle that hosts
# the radio plugins. A bundle (with Info.plist) is required for the window to
# activate normally; a raw `swift run` binary has no activation policy.
#
#   ./build-app.sh            # release build into ./dist
#   open "dist/Amateur Radio Suite.app"
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Amateur Radio Suite"
BINARY="RadioSuite"
DIST="dist"
BUNDLE="$DIST/$APP_NAME.app"

echo "▶ Building universal release binary (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64

BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$BINARY"

echo "▶ Assembling app bundle…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/$BINARY"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

# App icon (best-effort — generates a placeholder if none exists).
if [ ! -f "$DIST/AppIcon.icns" ]; then
  ./make-icon.sh || echo "  (icon generation failed — shipping without icon)"
fi
if [ -f "$DIST/AppIcon.icns" ]; then
  cp "$DIST/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so Gatekeeper lets it run locally.
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || \
  echo "  (codesign skipped — app still runs locally)"

echo "✓ Built: $BUNDLE"
echo "  Launch with:  open \"$BUNDLE\""
