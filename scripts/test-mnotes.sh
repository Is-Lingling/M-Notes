#!/bin/bash
set -euo pipefail
repository_dir="$(cd "$(dirname "$0")/.." && pwd)"
fixture_dir="$(mktemp -d /tmp/mnotes-tests.XXXXXX)"
trap 'rm -rf "$fixture_dir"' EXIT
cd "$repository_dir"
npm test --prefix editor-bundle
scripts/test-editor-loading.sh
swiftc -swift-version 5 MarkdownNotes/App/AppState.swift MarkdownNotes/Models/FileNode.swift \
  MarkdownNotes/Services/FSEventWatcher.swift MarkdownNotes/Services/UpdateChecker.swift tests/AppStateSmoke.swift -o "$fixture_dir/state-test"
"$fixture_dir/state-test"
swiftc -swift-version 5 MarkdownNotes/Services/UpdateChecker.swift tests/UpdateCheckerSmoke.swift -o "$fixture_dir/update-checker-test"
"$fixture_dir/update-checker-test"
swiftc -swift-version 5 MarkdownNotes/Services/EditorResources.swift MarkdownNotes/Services/DocumentExporter.swift \
  tests/ExportSmoke.swift -o "$fixture_dir/export-test"
"$fixture_dir/export-test" "$repository_dir/MarkdownNotes/Editor/editor.html"

lifecycle_sources=()
for source in MarkdownNotes/App/*.swift MarkdownNotes/Views/*.swift MarkdownNotes/Services/*.swift MarkdownNotes/Models/*.swift; do
  [[ "$source" == */MarkdownNotesApp.swift ]] || lifecycle_sources+=("$source")
done
swiftc -swift-version 5 "${lifecycle_sources[@]}" tests/EditorLifecycleSmoke.swift -o "$fixture_dir/lifecycle-test"
"$fixture_dir/lifecycle-test" "$repository_dir/MarkdownNotes/Editor/editor.html"
