#!/bin/bash
set -euo pipefail
repository_dir="$(cd "$(dirname "$0")/.." && pwd)"
fixture_dir="$(mktemp -d /tmp/markdownnotes-loading.XXXXXX)"
trap 'rm -rf "$fixture_dir"' EXIT
swiftc -swift-version 5 \
  "$repository_dir/MarkdownNotes/Services/EditorResources.swift" \
  "$repository_dir/tests/EditorLoadingSmoke.swift" \
  -o "$fixture_dir/smoke"
# Test source resources and the external location that previously produced a blank editor.
"$fixture_dir/smoke" "$repository_dir/MarkdownNotes/Editor/editor.html"
cp -R "$repository_dir/MarkdownNotes/Editor" "$fixture_dir/Editor"
"$fixture_dir/smoke" "$fixture_dir/Editor/editor.html"
