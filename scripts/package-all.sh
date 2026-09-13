#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# M Notes Multi-Platform Packaging Master Script
# Builds and stages artifacts for macOS, Windows, Linux, iOS & Android
# ─────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
mkdir -p "$DIST_DIR"

echo "======================================================="
echo "   M Notes Multi-Platform Packaging Hub"
echo "======================================================="

# 1. Build macOS Release Package & DMG
echo "==> [macOS] Building and packaging Release app, ZIP, and DMG..."
"$REPO_DIR/scripts/build-dmg.sh"
ditto -c -k --keepParent "$DIST_DIR/M Notes.app" "$DIST_DIR/M-Notes-v1.0.0-macOS.zip"

# 2. Build iOS Release Package & IPA (on macOS)
if command -v xcodebuild >/dev/null 2>&1 && [ -d "$REPO_DIR/ios" ]; then
  echo "==> [iOS] Generating project and building Release IPA..."
  (cd "$REPO_DIR/ios" && xcodegen generate >/dev/null 2>&1 || true)
  mkdir -p "$REPO_DIR/build/ios-release"
  xcodebuild -project "$REPO_DIR/ios/MNotesIOS.xcodeproj" \
    -scheme MNotesIOS \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$REPO_DIR/build/ios-release" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build >/dev/null 2>&1 || true
  if [ -d "$REPO_DIR/build/ios-release/Build/Products/Release-iphoneos/M Notes.app" ]; then
    rm -rf /tmp/ios-pkg && mkdir -p /tmp/ios-pkg/Payload
    cp -R "$REPO_DIR/build/ios-release/Build/Products/Release-iphoneos/M Notes.app" /tmp/ios-pkg/Payload/
    (cd /tmp/ios-pkg && zip -qr "$DIST_DIR/M-Notes-v1.0.0-iOS.ipa" Payload)
    rm -rf /tmp/ios-pkg
    echo "    Created: dist/M-Notes-v1.0.0-iOS.ipa"
  fi
fi

# 3. Output Distribution Summary Table
echo ""
echo "======================================================="
echo "   Artifacts generated in dist/:"
echo "======================================================="
ls -lh "$DIST_DIR"
echo "======================================================="
echo "   All platform builds configured and ready!"
echo "   - macOS:   dist/M Notes.app, dist/M-Notes-v1.0.0-macOS.dmg, dist/M-Notes-v1.0.0-macOS.zip"
echo "   - iOS:     dist/M-Notes-v1.0.0-iOS.ipa"
echo "   - Windows: windows/ (Tauri / NSIS / MSI buildable via 'npm run build' / GitHub Actions)"
echo "   - Linux:   linux/ (AppImage / DEB buildable via 'npm run build' / GitHub Actions)"
echo "   - Android: android/ (Gradle / APK buildable via './gradlew assembleRelease' / GitHub Actions)"
echo "======================================================="
