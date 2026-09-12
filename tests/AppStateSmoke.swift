import AppKit

@main @MainActor
struct AppStateSmoke {
    static func main() throws {
        let suite = "MNotesTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent("missing.md")
        defaults.set([missing.path], forKey: "recentFiles")
        let state = AppState(restoreSession: false, defaults: defaults)
        precondition(state.preferences.theme == .system, "Fresh installs should follow the system appearance")
        precondition(state.recentFiles == [missing], "Keep missing recent records until user confirms removal")
        let txt = directory.appendingPathComponent("测试.txt"), md = directory.appendingPathComponent("second.md")
        try "# literal **text** 中文".write(to: txt, atomically: true, encoding: .utf16)
        try "# second".write(to: md, atomically: true, encoding: .utf8)
        precondition(state.openFile(txt)); precondition(state.isPlainText && state.isSourceMode)
        state.contentDidChange("Updated 中文文本")
        precondition(state.openFile(md))
        let savedText = try String(contentsOf: txt, encoding: .utf16)
        precondition(savedText == "Updated 中文文本")
        precondition(!state.isPlainText && !state.isSourceMode)
        state.saveReadingPosition(["scrollTop": 123.5, "topPosition": 10, "anchor": 12], documentID: txt.path)
        state.preferences.language = .english
        let restored = AppState(restoreSession: false, defaults: defaults)
        precondition(restored.readingPosition(for: txt)["scrollTop"] as? Double == 123.5)
        precondition(restored.preferences.language == .english, "Language preference should persist")
        restored.removeRecentFile(missing)
        precondition(!restored.recentFiles.contains(missing))

        // 1. Re-opening existing files does NOT change their order
        let orderBefore = restored.uncategorizedFiles
        precondition(restored.openFile(txt))
        precondition(restored.uncategorizedFiles == orderBefore, "Opening existing file should not reorder recent files")

        // 2. Default save location preference
        let customSaveDir = directory.appendingPathComponent("CustomFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: customSaveDir, withIntermediateDirectories: true)
        restored.preferences.defaultSaveLocation = customSaveDir.path
        precondition(restored.defaultDirectory() == customSaveDir)
        let createdNote = restored.createNewFile()
        precondition(createdNote != nil)
        precondition(createdNote!.url.deletingLastPathComponent().path == customSaveDir.path, "New note should be created in defaultSaveLocation")

        // 3. Category management & drag/move
        restored.createCategory(name: "Work Notes")
        precondition(restored.recentCategories.count == 1)
        let categoryId = restored.recentCategories[0].id
        precondition(restored.recentCategories[0].name == "Work Notes")

        restored.moveFileToCategory(fileURL: txt, targetCategoryId: categoryId)
        precondition(restored.recentCategories[0].fileURLs.contains(txt))
        precondition(!restored.uncategorizedFiles.contains(txt))
        precondition(restored.recentFiles.contains(txt), "recentFiles should remain flat union")

        // Move file back to uncategorized
        restored.moveFileToCategory(fileURL: txt, targetCategoryId: nil)
        precondition(restored.uncategorizedFiles.contains(txt))
        precondition(!restored.recentCategories[0].fileURLs.contains(txt))

        // Delete category
        restored.deleteCategory(id: categoryId)
        precondition(restored.recentCategories.isEmpty)

        // 4. File rename
        precondition(restored.openFile(md))
        let expectedRenamedURL = directory.appendingPathComponent("renamed_doc.md")
        restored.renameFile(md, newName: "renamed_doc")
        precondition(FileManager.default.fileExists(atPath: expectedRenamedURL.path), "Renamed file should exist on disk")
        precondition(!FileManager.default.fileExists(atPath: md.path), "Original file should no longer exist")
        precondition(restored.selectedFile?.url == expectedRenamedURL, "Selected file should be updated")
        precondition(restored.recentFiles.contains(expectedRenamedURL), "Recent files should contain renamed URL")
        precondition(!restored.recentFiles.contains(md), "Recent files should not contain old URL")

        print("PASS: system theme default, TXT encoding, dirty-save, source mode, recents, reading position, language persistence, order preservation, default save location, category management and file renaming")
    }
}
