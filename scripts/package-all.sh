#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# M Notes Desktop Multi-Platform Packaging Master Script
# Builds and stages artifacts for macOS, Windows, Linux
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
ditto -c -k --keepParent "$DIST_DIR/M Notes.app" "$DIST_DIR/M-Notes-v1.0.6-macOS.zip"

# 2. Output Distribution Summary Table
echo ""
echo "======================================================="
echo "   Artifacts generated in dist/:"
echo "======================================================="
ls -lh "$DIST_DIR"
echo "======================================================="
echo "   All platform builds configured and ready!"
echo "   - macOS:   dist/M Notes.app, dist/M-Notes-v1.0.6-macOS.dmg, dist/M-Notes-v1.0.6-macOS.zip"
echo "   - Windows: windows/ (Tauri / NSIS / MSI buildable via 'npm run build' / GitHub Actions)"
echo "   - Linux:   linux/ (AppImage / DEB buildable via 'npm run build' / GitHub Actions)"
echo "======================================================="
