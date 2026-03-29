#!/usr/bin/env bash
# release.sh — Build, notarize, and publish a ReToken GitHub release
#
# Usage: ./release.sh <version>
#   e.g. ./release.sh 1.1.0
#
# Prerequisites:
#   brew install create-dmg
#   gh auth login
#   Export dir set up with ExportOptions.plist (generated on first use)
#
# Secrets (set these in your shell or a local .env file — never commit them):
#   APPLE_ID          your Apple ID email
#   APPLE_APP_PASSWORD  app-specific password from appleid.apple.com
#   APPLE_TEAM_ID     XW3YJZ5VVY

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCHEME="ReToken"
BUNDLE_ID="com.themrhinos.ReToken"
TEAM_ID="${APPLE_TEAM_ID:-XW3YJZ5VVY}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODEPROJ="$PROJECT_DIR/ReToken.xcodeproj"
BUILD_DIR="$PROJECT_DIR/.build/release"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"

run_xcodebuild() {
    if command -v xcpretty >/dev/null 2>&1; then
        xcodebuild "$@" | xcpretty
    else
        xcodebuild "$@"
    fi
}

# ── Argument check ────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>  (e.g. $0 1.1.0)"
    exit 1
fi
VERSION="$1"
DMG_NAME="${SCHEME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# ── Credential check ──────────────────────────────────────────────────────────
if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "ERROR: Set APPLE_ID and APPLE_APP_PASSWORD environment variables."
    echo "  export APPLE_ID=you@example.com"
    echo "  export APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    exit 1
fi

# ── Generate ExportOptions.plist if missing ───────────────────────────────────
if [[ ! -f "$EXPORT_OPTIONS" ]]; then
    echo "→ Writing ExportOptions.plist"
    cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
fi

# ── Bump version in project ───────────────────────────────────────────────────
echo "→ Setting version $VERSION in Xcode project"
xcrun agvtool new-marketing-version "$VERSION"

# ── Bump build number (increment from git tag count) ─────────────────────────
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
xcrun agvtool new-version -all "$BUILD_NUMBER"

# ── Archive ───────────────────────────────────────────────────────────────────
echo "→ Archiving..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

run_xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "ERROR: Archive not found at $ARCHIVE_PATH — check build output above."
    exit 1
fi
echo "   Archive: $ARCHIVE_PATH"

# ── Export (Developer ID signed) ─────────────────────────────────────────────
echo "→ Exporting with Developer ID..."
run_xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH"

APP_PATH="$EXPORT_PATH/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: Exported app not found at $APP_PATH"
    exit 1
fi
echo "   App: $APP_PATH"

# ── Notarize ─────────────────────────────────────────────────────────────────
echo "→ Notarizing..."
NOTARIZE_ZIP="$BUILD_DIR/${SCHEME}-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

xcrun notarytool submit "$NOTARIZE_ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "→ Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# ── Package DMG ───────────────────────────────────────────────────────────────
echo "→ Building DMG..."

if ! command -v create-dmg &>/dev/null; then
    echo "ERROR: create-dmg not found. Run: brew install create-dmg"
    exit 1
fi

create-dmg \
    --volname "ReToken $VERSION" \
    --window-size 520 300 \
    --icon-size 128 \
    --icon "ReToken.app" 130 150 \
    --hide-extension "ReToken.app" \
    --app-drop-link 390 150 \
    "$DMG_PATH" \
    "$APP_PATH"

echo "   DMG: $DMG_PATH"

# ── Tag & GitHub Release ──────────────────────────────────────────────────────
echo "→ Tagging v$VERSION..."
git add ReToken.xcodeproj/project.pbxproj
git commit -m "chore: bump version to $VERSION" 2>/dev/null || echo "   (nothing to commit)"
git tag "v$VERSION"
git push origin HEAD "v$VERSION"

echo "→ Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
    --title "ReToken $VERSION" \
    --generate-notes

echo ""
echo "✓ ReToken $VERSION released!"
echo "  $(gh release view v$VERSION --json url -q .url)"
