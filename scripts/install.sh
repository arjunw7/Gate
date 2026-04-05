#!/usr/bin/env bash
# scripts/install.sh — Build (or use prebuilt), bundle, and install Boop
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Boop"
BINARY_NAME="Boop"
APP_BUNDLE="$REPO_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
PREBUILT=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --prebuilt) PREBUILT=true ;;
    esac
done

echo "✋ Installing Boop..."

# 0. Kill any running Boop instance to avoid port conflicts
pkill -x Boop 2>/dev/null || true

if [ "$PREBUILT" = true ]; then
    # ── Prebuilt path: unzip Boop.zip if needed ──
    if [ -d "$REPO_DIR/Boop.app" ]; then
        echo "📦 Using prebuilt Boop.app..."
        APP_BUNDLE="$REPO_DIR/Boop.app"
    elif [ -f "$REPO_DIR/Boop.zip" ]; then
        echo "📦 Extracting prebuilt Boop.zip..."
        unzip -qo "$REPO_DIR/Boop.zip" -d "$REPO_DIR"
        APP_BUNDLE="$REPO_DIR/Boop.app"
    else
        echo "❌ No prebuilt Boop.app or Boop.zip found in $REPO_DIR"
        echo "   Download from the GitHub Releases page, or omit --prebuilt to build from source."
        exit 1
    fi
else
    # ── Build from source ──
    # 1. Check Swift CLT
    if ! xcode-select -p &>/dev/null; then
        echo "❌ Xcode Command Line Tools not found."
        echo "   Run: xcode-select --install"
        echo "   Or use --prebuilt with a pre-built binary from GitHub Releases."
        exit 1
    fi

    # 2. Build
    echo "⚙️  Building (release)..."
    cd "$REPO_DIR"
    swift build -c release

    # 3. Bundle
    echo "📦 Creating .app bundle..."
    rm -rf "$APP_BUNDLE"
    rm -rf "$REPO_DIR/Gate.app"          # remove legacy bundle name
    rm -rf "$REPO_DIR/Claude Gate.app"   # remove legacy bundle names if still present
    rm -rf "$REPO_DIR/ClaudeGate.app"    # remove legacy bundle name
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp ".build/release/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

    # 3a. Copy image resources and fonts
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
    <key>LSUIElement</key>              <true/>
    <key>NSPrincipalClass</key>         <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
</dict>
</plist>
PLIST

    # 4. Sign the bundle (ad-hoc, no Apple account required)
    echo "✍️  Signing bundle..."
    find "$APP_BUNDLE" -name '._*' -delete 2>/dev/null || true
    find "$APP_BUNDLE" -name '.DS_Store' -delete 2>/dev/null || true
    xattr -crs "$APP_BUNDLE"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

# 5. Install to /Applications
echo "📥 Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
rm -rf "$INSTALL_DIR/Gate.app"           # remove legacy name if present
rm -rf "$INSTALL_DIR/Claude Gate.app"    # remove legacy name if present
rm -rf "$INSTALL_DIR/ClaudeGate.app"     # remove legacy name
cp -r "$APP_BUNDLE" "$INSTALL_DIR/"

# 5a. Strip Gatekeeper quarantine attribute
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

# 6. Patch ~/.claude/settings.json (initial hook — app will update port on launch)
echo "🔧 Configuring Claude Code hook..."
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{}' > "$CLAUDE_SETTINGS"
fi

python3 - "$CLAUDE_SETTINGS" << 'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

settings.setdefault("hooks", {})
settings["hooks"]["PermissionRequest"] = [
    {
        "matcher": "",
        "hooks": [
            {
                "type": "http",
                "url": "http://localhost:29001/permission"
            }
        ]
    }
]

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("  ✓ Hook registered in", path)
PYEOF

# 7. Launch
echo "🚀 Launching Boop..."
open "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "✅ Boop installed!"
echo "   ✋ icon should appear in your menu bar."
echo "   Open Settings from the menu bar to configure permission mode."
echo "   To register as a login item, toggle 'Launch at login' in Settings."
