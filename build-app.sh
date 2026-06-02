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

# Version stamped into the bundle's Info.plist. The release pipeline passes the
# tag it is about to publish (APP_VERSION=0.1.11); a local build falls back to
# `git describe` so the About box still shows something meaningful.
if [ -z "${APP_VERSION:-}" ]; then
  # `|| true` keeps a tagless checkout (e.g. CI's shallow clone) from tripping
  # `set -e`/`pipefail` when git describe exits non-zero.
  APP_VERSION="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  APP_VERSION="${APP_VERSION#v}"
  APP_VERSION="${APP_VERSION:-0.0.0-dev}"
fi

echo "▶ Building universal release binary (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64

BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$BINARY"

echo "▶ Assembling app bundle…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/$BINARY"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

# Stamp the real version (the template ships a placeholder).
echo "Stamping version ${APP_VERSION}"
PLIST="$BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$PLIST"

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
