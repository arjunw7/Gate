#!/usr/bin/env bash
# scripts/uninstall.sh — Remove Boop
set -e

APP="/Applications/Boop.app"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "🗑️  Uninstalling Boop..."

# Kill running instance
pkill -x Boop 2>/dev/null || true

# Remove app
if [ -d "$APP" ]; then
    rm -rf "$APP"
    echo "  ✓ Removed $APP"
fi

# Remove hook from settings.json
if [ -f "$CLAUDE_SETTINGS" ]; then
    python3 - "$CLAUDE_SETTINGS" << 'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
pr_hooks = hooks.get("PermissionRequest", [])

# Remove any hook pointing to localhost:29001
cleaned = [
    entry for entry in pr_hooks
    if not any(
        h.get("url", "").startswith("http://localhost:29001")
        for h in entry.get("hooks", [])
    )
]

if cleaned:
    settings["hooks"]["PermissionRequest"] = cleaned
else:
    hooks.pop("PermissionRequest", None)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("  ✓ Hook removed from", path)
PYEOF
fi

# Remove config dir (optional — ask first)
CONFIG_DIR="$HOME/.boop"
if [ -d "$CONFIG_DIR" ]; then
    read -p "  Remove config and permissions at $CONFIG_DIR? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo "  ✓ Config removed"
    fi
fi

echo ""
echo "✅ Boop uninstalled."
