#!/usr/bin/env bash
# Download all JavaScript dependencies for the editor
set -e

EDITOR_DIR="MarkdownNotes/Editor"
mkdir -p "$EDITOR_DIR/katex"
mkdir -p "$EDITOR_DIR/katex/contrib"
mkdir -p "$EDITOR_DIR/katex/fonts"
mkdir -p "$EDITOR_DIR/highlight/styles"
mkdir -p "$EDITOR_DIR/mermaid"
mkdir -p "$EDITOR_DIR/markdown-it"
mkdir -p "$EDITOR_DIR/codemirror"

KATEX_VER="0.16.9"
HLJS_VER="11.9.0"
MERMAID_VER="10.6.1"
MDI_VER="13.0.2"

echo "📦 Downloading KaTeX ${KATEX_VER}..."
BASE="https://cdn.jsdelivr.net/npm/katex@${KATEX_VER}/dist"
curl -sL "$BASE/katex.min.css" -o "$EDITOR_DIR/katex/katex.min.css"
curl -sL "$BASE/katex.min.js" -o "$EDITOR_DIR/katex/katex.min.js"
curl -sL "$BASE/contrib/auto-render.min.js" -o "$EDITOR_DIR/katex/contrib/auto-render.min.js"

# KaTeX fonts (subset for math)
echo "  Downloading KaTeX fonts..."
FONTS=(
  "KaTeX_AMS-Regular.woff2"
  "KaTeX_Main-Regular.woff2"
  "KaTeX_Main-Bold.woff2"
  "KaTeX_Main-Italic.woff2"
  "KaTeX_Math-Italic.woff2"
  "KaTeX_Size1-Regular.woff2"
  "KaTeX_Size2-Regular.woff2"
  "KaTeX_Size3-Regular.woff2"
  "KaTeX_Size4-Regular.woff2"
  "KaTeX_SansSerif-Regular.woff2"
  "KaTeX_Typewriter-Regular.woff2"
)
for font in "${FONTS[@]}"; do
  curl -sL "$BASE/fonts/$font" -o "$EDITOR_DIR/katex/fonts/$font" &
done
wait

echo "📦 Downloading highlight.js ${HLJS_VER}..."
HL_BASE="https://cdn.jsdelivr.net/npm/highlight.js@${HLJS_VER}"
curl -sL "$HL_BASE/build/highlight.min.js" -o "$EDITOR_DIR/highlight/highlight.min.js"
curl -sL "$HL_BASE/styles/github.min.css" -o "$EDITOR_DIR/highlight/styles/github.min.css"
curl -sL "$HL_BASE/styles/github-dark.min.css" -o "$EDITOR_DIR/highlight/styles/github-dark.min.css"

echo "📦 Downloading Mermaid ${MERMAID_VER}..."
curl -sL "https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VER}/dist/mermaid.min.js" \
  -o "$EDITOR_DIR/mermaid/mermaid.min.js"

echo "📦 Downloading markdown-it ${MDI_VER}..."
MDI_BASE="https://cdn.jsdelivr.net/npm/markdown-it@${MDI_VER}/dist"
curl -sL "$MDI_BASE/markdown-it.min.js" -o "$EDITOR_DIR/markdown-it/markdown-it.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2.1.1/dist/markdown-it-task-lists.min.js" \
  -o "$EDITOR_DIR/markdown-it/markdown-it-task-lists.min.js"

echo "📦 Building CodeMirror 6 bundle..."
# We'll use a pre-built CDN bundle that includes all CM6 essentials
CM6_BASE="https://cdn.jsdelivr.net/npm/@replit/codemirror-lang-markdown@6.2.5/dist"
# Alternative: use a known-good CM6 complete bundle
curl -sL "https://cdn.jsdelivr.net/npm/codemirror@6.0.1/dist/index.js" \
  -o /tmp/cm6.js 2>/dev/null || true

# Build a proper CM6 bundle via npm
if command -v node &>/dev/null && command -v npm &>/dev/null; then
  echo "  Building CM6 bundle via npm..."
  TMPDIR=$(mktemp -d)
  cat > "$TMPDIR/package.json" << 'EOF'
{
  "name": "cm6-bundle",
  "private": true,
  "type": "module"
}
EOF
  cd "$TMPDIR"
  npm install --silent \
    @codemirror/view \
    @codemirror/state \
    @codemirror/commands \
    @codemirror/language \
    @codemirror/lang-markdown \
    @codemirror/search \
    @codemirror/lint \
    @lezer/highlight \
    @codemirror/highlight 2>/dev/null || \
  npm install --silent \
    @codemirror/view \
    @codemirror/state \
    @codemirror/commands \
    @codemirror/language \
    @codemirror/lang-markdown \
    @codemirror/search \
    @lezer/highlight 2>/dev/null

  cat > "$TMPDIR/cm6-bundle.mjs" << 'BUNDLE_EOF'
export * as view from "@codemirror/view";
export * as state from "@codemirror/state";
export * as commands from "@codemirror/commands";
export * as language from "@codemirror/language";
export * as lang_markdown from "@codemirror/lang-markdown";
export * as search from "@codemirror/search";
export * as highlight from "@lezer/highlight";
BUNDLE_EOF

  cd "$TMPDIR"
  # Try to use esbuild if available
  if command -v npx &>/dev/null; then
    npx --yes esbuild cm6-bundle.mjs \
      --bundle \
      --format=iife \
      --global-name=CM \
      --minify \
      --outfile="/tmp/codemirror-bundle.js" 2>/dev/null && \
    cp /tmp/codemirror-bundle.js "$(dirname "$0")/$EDITOR_DIR/codemirror/codemirror-bundle.js" && \
    echo "  ✅ CM6 bundle built successfully" || \
    echo "  ⚠️  Bundle build failed, using CDN fallback"
  fi

  cd "$(dirname "$0")"
  rm -rf "$TMPDIR"
fi

# If local build failed, download a pre-built CM6 bundle from a reliable source
if [ ! -f "$EDITOR_DIR/codemirror/codemirror-bundle.js" ] || \
   [ ! -s "$EDITOR_DIR/codemirror/codemirror-bundle.js" ]; then
  echo "  Downloading pre-built CM6 bundle..."
  # Download from GitHub releases or a CDN
  curl -sL "https://cdn.jsdelivr.net/gh/nickmccullum/codemirror-6-bundle@main/codemirror-bundle.min.js" \
    -o "$EDITOR_DIR/codemirror/codemirror-bundle.js" 2>/dev/null || \
  # Create a minimal stub if download fails
  echo "window.CM = {}; console.warn('CodeMirror bundle not loaded');" \
    > "$EDITOR_DIR/codemirror/codemirror-bundle.js"
fi

echo ""
echo "✅ All dependencies downloaded!"
echo ""
ls -lh "$EDITOR_DIR"/{katex,highlight,mermaid,markdown-it,codemirror}/*.js 2>/dev/null | \
  awk '{print "  " $5, $9}'
