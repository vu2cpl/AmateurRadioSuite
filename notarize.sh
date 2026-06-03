#!/usr/bin/env bash
#
# notarize.sh — produce a NOTARIZED, stapled "Amateur Radio Suite.app" plus
# distributable .zip and .dmg, ready to attach to a GitHub Release.
#
# build-app.sh only ad-hoc-signs (fine for local dev, but Gatekeeper blocks it
# on other Macs). This script builds the same universal bundle, then RE-SIGNS it
# with Manoj's Developer ID + hardened runtime + secure timestamp, submits it to
# Apple's notary service, staples the ticket, and packages a .zip and a .dmg
# whose names match the Release workflow (AmateurRadioSuite-<version>.{zip,dmg}).
#
# CREDENTIALS — two interchangeable modes (auto-detected):
#
#   1. Keychain profile (local dev). Store once:
#        xcrun notarytool store-credentials ARS-NOTARY \
#          --apple-id <apple-id> --team-id CHVNJ85C9F --password <app-specific-pw>
#      then just run ./notarize.sh.
#      Notarization is per-Apple-account, not per-app, so ANY profile already on
#      this Mac works — reuse one with:  NOTARY_PROFILE=DXC-NOTARY ./notarize.sh
#
#   2. Raw env (e.g. CI). Export APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID;
#      the Developer ID cert must already be in a keychain. (Releases are cut
#      locally via mode 1 — this fallback is here if a CI runner is ever added.)
#
# Usage:
#   ./notarize.sh [VERSION]        # e.g. 0.1.15
#     VERSION  optional — falls back to build-app.sh's own `git describe`.
#
# Overridable via env: DEV_ID, NOTARY_PROFILE, APP_NAME
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="${APP_NAME:-Amateur Radio Suite}"
APP="dist/${APP_NAME}.app"
DEV_ID="${DEV_ID:-Developer ID Application: Manoj Ramawarrier (CHVNJ85C9F)}"

# notarytool submit, picking whichever credential mode is configured.
submit() {  # $1 = file to submit
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" --wait
  else
    cat >&2 <<'MSG'
ERROR: no notary credentials found.
  Local: store a keychain profile and pass NOTARY_PROFILE (or default ARS-NOTARY):
      xcrun notarytool store-credentials ARS-NOTARY \
        --apple-id <apple-id> --team-id CHVNJ85C9F --password <app-specific-pw>
  CI:    export APPLE_ID + APPLE_APP_PASSWORD + APPLE_TEAM_ID.
MSG
    exit 1
  fi
}

# Default the local keychain profile only when no raw-env creds are present, so
# a freshly-stored ARS-NOTARY "just works" without setting NOTARY_PROFILE.
if [ -z "${NOTARY_PROFILE:-}" ] && [ -z "${APPLE_ID:-}" ]; then
  NOTARY_PROFILE="ARS-NOTARY"
fi

echo "==> Building universal bundle via build-app.sh"
APP_VERSION="${1:-${APP_VERSION:-}}" ./build-app.sh

# Read back the version build-app.sh actually stamped (covers the describe path).
VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "==> Version: $VER"

echo "==> Re-signing with Developer ID (hardened runtime + secure timestamp)"
xattr -cr "$APP"
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer ID|Timestamp=|flags=.*runtime" || true

# --- Notarize the .app ------------------------------------------------------
NOTARY_ZIP="dist/_notary-submit.zip"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
echo "==> Submitting .app to Apple notary service (waits for result)"
submit "$NOTARY_ZIP"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$NOTARY_ZIP"

# --- Package distributables (names match release.yml) -----------------------
ZIP="dist/AmateurRadioSuite-${VER}.zip"
DMG="dist/AmateurRadioSuite-${VER}.dmg"
rm -f "$ZIP" "$DMG"

# .zip — re-zip the now-stapled app so the ticket travels with it.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# .dmg — built from the stapled app, then signed + notarized + stapled itself.
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG"
echo "==> Signing + notarizing DMG"
codesign --force --timestamp --sign "$DEV_ID" "$DMG"
submit "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper assessment (what a user's Mac does)"
spctl -a -vvv -t exec "$APP" || true

cat <<EOF

✓ Notarized + stapled, ready to release:
    $ZIP
    $DMG

  Verify on a fresh Mac:  spctl -a -vvv -t exec "$APP"
    → accepted  source=Notarized Developer ID
EOF
