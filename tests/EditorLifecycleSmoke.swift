import AppKit
import SwiftUI
import WebKit

@main @MainActor
struct EditorLifecycleSmoke {
    static func views(in view: NSView) -> [WKWebView] {
        (view as? WKWebView).map { [$0] } ?? view.subviews.flatMap { views(in: $0) }
    }
    static func wait(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(domain: "Lifecycle", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for lifecycle transition"])
    }
    static func main() throws {
        _ = NSApplication.shared
        let suite = "MNotesLifecycle-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("note.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        let state = AppState(restoreSession: false, defaults: defaults)
        state.preferences.autoSave = false
        precondition(state.openFile(file))
        let editorURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: AnyView(EditorContainerView().environmentObject(state)))
        window.contentView = hosting
        window.orderFront(nil)
        Task { @MainActor in
            do {
                try await wait { views(in: hosting).count == 1 }
                let original = views(in: hosting)[0]
                let coordinator = original.navigationDelegate as! EditorWebView.Coordinator
                coordinator.setForeground(true)
                EditorResources.load(editorURL, in: original)
                try await wait { coordinator.isEditorReady }
                for index in 0..<4 {
                    state.preferences.language = index.isMultiple(of: 2) ? .english : .simplifiedChinese
                    try await Task.sleep(nanoseconds: 100_000_000)
                    precondition(views(in: hosting).first === original, "Language recreated the WebView")
                }
                _ = try await original.evaluateJavaScript("window.editor.insertAtCursor('edit'); window.editor._view.dispatch({selection:{anchor:2}})")
                // Returning before the idle deadline cancels hibernation.
                coordinator.setForeground(false, sleepDelay: 0.05)
                coordinator.setForeground(true)
                try await Task.sleep(nanoseconds: 150_000_000)
                precondition(!state.isEditorSleeping)
                // An in-flight export must remain live.
                coordinator.exporter = DocumentExporter()
                coordinator.setForeground(false, sleepDelay: 60)
                await coordinator.hibernateEditor()
                precondition(!state.isEditorSleeping)
                coordinator.exporter = nil
                await coordinator.hibernateEditor()
                try await wait { state.isEditorSleeping && views(in: hosting).isEmpty }
                precondition(state.sleepingEditorSnapshot != nil && state.currentContent == "edit\noriginal" && state.isDirty)
                precondition(!coordinator.isActive && coordinator.webView == nil && original.navigationDelegate == nil)
                // The snapshot restores into a genuinely new WebView.
                state.isEditorSleeping = false
                try await wait { views(in: hosting).count == 1 }
                let restored = views(in: hosting)[0]
                precondition(restored !== original)
                let next = restored.navigationDelegate as! EditorWebView.Coordinator
                next.setForeground(true)
                EditorResources.load(editorURL, in: restored)
                try await wait { next.isEditorReady && state.sleepingEditorSnapshot == nil }
                let ok = try await restored.evaluateJavaScript("window.editor.getContent() === 'edit\\noriginal' && window.editor._view.state.selection.main.head === 2 && CM.commands.undoDepth(window.editor._view.state) === 1") as? Bool
                precondition(ok == true, "Content, cursor, or undo history lost during hibernation")
                hosting.rootView = AnyView(EmptyView())
                try await wait { !next.isActive }
                window.close()
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: directory)
                print("PASS: language reuses WebView; foreground cancels sleep; exports block sleep; hibernation releases editor and restores dirty content/cursor/undo")
                exit(0)
            } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
        NSApplication.shared.run()
    }
}
