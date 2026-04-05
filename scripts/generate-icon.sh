#!/usr/bin/env bash
# Generate Boop app icon as .icns
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONSET="/tmp/Boop.iconset"
OUTPUT="$SCRIPT_DIR/../Sources/Boop/Resources/AppIcon.icns"

# Generate PNGs via Swift
swift "$SCRIPT_DIR/generate-icon.swift"

# Fix pixel dimensions (Retina macs render at 2x)
cd "$ICONSET"
for f in *.png; do
    # Extract expected size from filename
    case "$f" in
        icon_16x16.png)     px=16 ;;
        icon_16x16@2x.png)  px=32 ;;
        icon_32x32.png)     px=32 ;;
        icon_32x32@2x.png)  px=64 ;;
        icon_128x128.png)   px=128 ;;
        icon_128x128@2x.png) px=256 ;;
        icon_256x256.png)   px=256 ;;
        icon_256x256@2x.png) px=512 ;;
        icon_512x512.png)   px=512 ;;
        icon_512x512@2x.png) px=1024 ;;
    esac
    sips -z $px $px "$f" --out "$f" > /dev/null 2>&1
    sips -s dpiWidth 72 -s dpiHeight 72 "$f" --out "$f" > /dev/null 2>&1
done

# Convert to .icns
iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "✅ Generated $OUTPUT"
rm -rf "$ICONSET"
