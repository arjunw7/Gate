#!/usr/bin/env bash
# scripts/build-release.sh — Build, sign, notarize, and zip Boop.app for distribution
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Boop"
# Build in /tmp to avoid iCloud Drive xattr interference
BUILD_DIR="/tmp/boop-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
OUTPUT_ZIP="$REPO_DIR/Boop.zip"
ENTITLEMENTS="$REPO_DIR/Boop.entitlements"

# ── Configuration ──────────────────────────────────────────────────────
# Set these env vars or pass them as arguments:
#   DEVELOPER_ID_APP   — signing identity, e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID           — your Apple ID email for notarization
#   APPLE_TEAM_ID      — your 10-char team ID
#   APP_PASSWORD        — app-specific password (store in keychain, see below)
#
# To store your app-specific password in the keychain (recommended):
#   xcrun notarytool store-credentials "boop-notarize" \
#     --apple-id "you@example.com" \
#     --team-id "YOURTEAMID" \
#     --password "xxxx-xxxx-xxxx-xxxx"
#
# Then set: KEYCHAIN_PROFILE="boop-notarize"
# ───────────────────────────────────────────────────────────────────────

DEVELOPER_ID_APP="${DEVELOPER_ID_APP:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-boop-notarize}"

# Auto-detect Developer ID if not set
if [ -z "$DEVELOPER_ID_APP" ]; then
    DEVELOPER_ID_APP=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
    if [ -n "$DEVELOPER_ID_APP" ]; then
        echo "🔑 Auto-detected signing identity: $DEVELOPER_ID_APP"
    fi
fi

SIGNING_MODE="adhoc"
if [ -n "$DEVELOPER_ID_APP" ]; then
    SIGNING_MODE="developerid"
fi

echo "🏗  Building Boop universal binary..."
echo "   Signing mode: $SIGNING_MODE"

cd "$REPO_DIR"

# Build for both architectures
echo "   Building arm64..."
swift build -c release --arch arm64

echo "   Building x86_64..."
swift build -c release --arch x86_64

# Create universal binary with lipo
echo "   Creating universal binary..."
ARM_BIN=".build/arm64-apple-macosx/release/$APP_NAME"
X86_BIN=".build/x86_64-apple-macosx/release/$APP_NAME"
UNIVERSAL_BIN=".build/release/$APP_NAME-universal"

mkdir -p .build/release
lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$X86_BIN"
echo "   Architectures: $(lipo -archs "$UNIVERSAL_BIN")"

# Create .app bundle
echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$UNIVERSAL_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy resources
cp "Sources/Boop/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
cp "Sources/Boop/Resources/Comfortaa-Medium.ttf" "$APP_BUNDLE/Contents/Resources/Comfortaa-Medium.ttf" 2>/dev/null || true

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>       <string>Boop</string>
    <key>CFBundleIdentifier</key>       <string>com.loop.boop</string>
    <key>CFBundleName</key>             <string>Boop</string>
    <key>CFBundleDisplayName</key>      <string>Boop</string>
    <key>CFBundleVersion</key>          <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSPrincipalClass</key>         <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
</dict>
</plist>
PLIST

# Clean metadata (must be thorough to avoid "resource fork" signing errors)
find "$APP_BUNDLE" -name '._*' -delete 2>/dev/null || true
find "$APP_BUNDLE" -name '.DS_Store' -delete 2>/dev/null || true
# Remove all extended attributes recursively, including resource forks
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
find "$APP_BUNDLE" -exec xattr -c {} \; 2>/dev/null || true

# Sign
echo "✍️  Signing bundle..."
if [ "$SIGNING_MODE" = "developerid" ]; then
    # Clear xattrs again right before signing
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true

    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$DEVELOPER_ID_APP" \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    # Clear xattrs between signing steps
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true

    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$DEVELOPER_ID_APP" \
        "$APP_BUNDLE"

    echo "   Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    spctl --assess --type execute --verbose "$APP_BUNDLE" || echo "   ⚠️  spctl check failed (expected before notarization)"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "   ⚠️  Ad-hoc signed (no Developer ID found). Users will see Gatekeeper warnings."
fi

# Zip for distribution
echo "📦 Creating Boop.zip..."
rm -f "$OUTPUT_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$OUTPUT_ZIP"

ZIP_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1 | xargs)

# Notarize (only with Developer ID)
if [ "$SIGNING_MODE" = "developerid" ]; then
    echo ""
    echo "🚀 Submitting for notarization..."
    echo "   (This may take a few minutes)"

    if xcrun notarytool submit "$OUTPUT_ZIP" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait; then

        echo "✅ Notarization successful!"

        # Staple the ticket to the app
        echo "📌 Stapling notarization ticket..."
        xcrun stapler staple "$APP_BUNDLE"

        # Re-zip with stapled ticket
        echo "📦 Re-zipping with stapled ticket..."
        rm -f "$OUTPUT_ZIP"
        ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$OUTPUT_ZIP"
        ZIP_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1 | xargs)
    else
        echo ""
        echo "⚠️  Notarization failed. Common fixes:"
        echo "   1. Store credentials:  xcrun notarytool store-credentials \"boop-notarize\""
        echo "   2. Check Apple ID has accepted latest agreements at developer.apple.com"
        echo "   The zip is still Developer ID signed and usable (users right-click > Open)."
    fi
fi

echo ""
echo "✅ Release build complete!"
echo "   $OUTPUT_ZIP ($ZIP_SIZE)"
if [ "$SIGNING_MODE" = "developerid" ]; then
    echo "   Signed with: $DEVELOPER_ID_APP"
    echo "   Upload this file to GitHub Releases."
else
    echo "   ⚠️  Not notarized. To sign properly, set DEVELOPER_ID_APP env var."
fi
