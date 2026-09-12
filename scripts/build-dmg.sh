#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# M Notes DMG Builder (for macOS)
# Generates a compressed, drag-and-drop installer DMG.
# ─────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
APP_NAME="M Notes"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="M-Notes-v1.0.0-macOS.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="M Notes"

echo "==> Preparing to build $DMG_NAME..."

# 1. Ensure dist directory exists
mkdir -p "$DIST_DIR"

# 2. Check if App bundle exists, if not build it
if [ ! -d "$APP_BUNDLE" ]; then
    echo "==> $APP_BUNDLE not found. Building Release app with xcodebuild..."
    XCODE_PROJ="$REPO_DIR/mac/MarkdownNotes.xcodeproj"
    [ -d "$XCODE_PROJ" ] || XCODE_PROJ="$REPO_DIR/MarkdownNotes.xcodeproj"
    BUILD_TEMP="$(mktemp -d /tmp/mnotes-dmg-build.XXXXXX)"
    trap 'rm -rf "$BUILD_TEMP"' EXIT
    xcodebuild -project "$XCODE_PROJ" -scheme MarkdownNotes -configuration Release -derivedDataPath "$BUILD_TEMP" build
    ditto "$BUILD_TEMP/Build/Products/Release/$APP_NAME.app" "$APP_BUNDLE"
fi

# 3. Create staging directory for the DMG contents
STAGING_DIR="$(mktemp -d /tmp/mnotes-dmg-staging.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> Staging app bundle and /Applications symlink..."
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"

# Create symlink to /Applications for standard drag-and-drop installation
ln -s /Applications "$STAGING_DIR/Applications"

# Include documentation or quick install guide if available
cat << 'EOF' > "$STAGING_DIR/安装说明 (How to Install).txt"
M Notes for macOS 安装指南
====================================
将 "M Notes" 图标拖入 "Applications"（应用程序）文件夹即可完成安装。

Drag "M Notes" into the "Applications" folder to install.
====================================
EOF

# 4. Remove any existing DMG output
rm -f "$DMG_PATH"

# 5. Create compressed read-only DMG with UDZO format
echo "==> Creating compressed disk image with hdiutil..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# 6. Verify and output results
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(ls -lh "$DMG_PATH" | awk '{print $5}')
    DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    echo "==> DMG successfully created!"
    echo "    Output file: $DMG_PATH"
    echo "    File size:   $DMG_SIZE"
    echo "    SHA256:      $DMG_SHA256"
else
    echo "Error: Failed to generate $DMG_PATH" >&2
    exit 1
fi
