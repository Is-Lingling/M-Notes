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
        print("PASS: system theme default, TXT encoding, dirty-save, source mode, recents, reading position and language persistence")
    }
}
