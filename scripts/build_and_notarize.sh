#!/usr/bin/env bash
#
# Build, sign, notarize, and staple the Outline.md macOS app for
# distribution outside the App Store.
#
# Prerequisites:
#   1. Apple Developer ID Application certificate installed in Keychain
#   2. An app-specific password stored in Keychain (see below)
#   3. Xcode command-line tools installed
#
# Required environment variables (or edit the defaults below):
#   APPLE_TEAM_ID       - Your 10-character Apple Team ID
#   APPLE_ID            - Your Apple ID email
#   APPLE_APP_PASSWORD  - App-specific password (or keychain profile name)
#
# Usage:
#   export APPLE_TEAM_ID="XXXXXXXXXX"
#   export APPLE_ID="you@example.com"
#   export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#   ./scripts/build_and_notarize.sh
#
# Alternatively, store credentials once with:
#   xcrun notarytool store-credentials "notary-profile" \
#       --apple-id "you@example.com" \
#       --team-id "XXXXXXXXXX" \
#       --password "xxxx-xxxx-xxxx-xxxx"
# Then set:
#   export NOTARY_PROFILE="notary-profile"
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Outline.md"
BUNDLE_ID="md.outline.app"
BUILD_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$PROJECT_DIR/build/$APP_NAME.dmg"
ZIP_PATH="$PROJECT_DIR/build/$APP_NAME.zip"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validate environment
# ---------------------------------------------------------------------------
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    [[ -z "${APPLE_TEAM_ID:-}" ]]      && error "Set APPLE_TEAM_ID or NOTARY_PROFILE"
    [[ -z "${APPLE_ID:-}" ]]            && error "Set APPLE_ID or NOTARY_PROFILE"
    [[ -z "${APPLE_APP_PASSWORD:-}" ]]  && error "Set APPLE_APP_PASSWORD or NOTARY_PROFILE"
fi

# ---------------------------------------------------------------------------
# Step 1 — Flutter release build
# ---------------------------------------------------------------------------
log "Building Flutter macOS release..."
cd "$PROJECT_DIR"
flutter build macos --release

[[ -d "$APP_PATH" ]] || error "Build output not found at $APP_PATH"

# ---------------------------------------------------------------------------
# Step 2 — Re-sign with Developer ID + Hardened Runtime
# ---------------------------------------------------------------------------
log "Signing app bundle with Developer ID..."

SIGN_IDENTITY="Developer ID Application"
if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
    SIGN_IDENTITY="Developer ID Application: ($APPLE_TEAM_ID)"
fi

codesign --deep --force --options runtime \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$PROJECT_DIR/macos/Runner/Release.entitlements" \
    "$APP_PATH"

log "Verifying signature..."
codesign --verify --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH" || warn "spctl check failed — may pass after notarization"

# ---------------------------------------------------------------------------
# Step 3 — Create a ZIP for notarization submission
# ---------------------------------------------------------------------------
log "Creating ZIP archive for notarization..."
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"

# ---------------------------------------------------------------------------
# Step 4 — Submit to Apple notary service
# ---------------------------------------------------------------------------
log "Submitting to Apple notary service (this may take several minutes)..."

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
fi

# ---------------------------------------------------------------------------
# Step 5 — Staple the notarization ticket
# ---------------------------------------------------------------------------
log "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

log "Verifying stapled app..."
spctl --assess --type execute --verbose=2 "$APP_PATH"

# ---------------------------------------------------------------------------
# Step 6 — Create distributable DMG
# ---------------------------------------------------------------------------
log "Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

log "Notarizing DMG..."
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
fi

xcrun stapler staple "$DMG_PATH"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Build complete!"
log "  App: $APP_PATH"
log "  DMG: $DMG_PATH"
log ""
log "The DMG is signed, notarized, and stapled — ready for distribution."
