import SwiftUI

@main
struct MNotesIOSApp: App {
    @StateObject private var appState = IOSAppState()

    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - iOS App State
@MainActor
class IOSAppState: ObservableObject {
    @Published var currentFileURL: URL?
    @Published var currentTitle: String = "Untitled.md"
    @Published var currentContent: String = "# Welcome to M Notes on iOS\n\n- [x] True WYSIWYG Editing\n- [x] KaTeX & Mermaid\n- [ ] Tap to type\n"
    @Published var isDirty: Bool = false
    @Published var isShowingDocumentPicker: Bool = false
    @Published var wordCount: Int = 0

    func openDocument(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            self.currentFileURL = url
            self.currentTitle = url.lastPathComponent
            self.currentContent = content
            self.isDirty = false
        }
    }

    func saveDocument() {
        guard let url = currentFileURL, isDirty else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        try? currentContent.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }
}
