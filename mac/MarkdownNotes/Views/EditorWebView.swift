import SwiftUI
import WebKit
import Combine
import UniformTypeIdentifiers

// MARK: - Editor Container (manages layout + focus mode)
struct EditorContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            NotesColors.editorBackground.ignoresSafeArea()

            if appState.isEditorSleeping {
                Text(appState.preferences.language == .english ? "Editor sleeping" : "编辑器已休眠")
                    .foregroundStyle(.secondary)
            } else {
                EditorWebView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            wakeEditor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in
            if NSApp.isActive { wakeEditor() }
        }
    }

    private func wakeEditor() {
        appState.setBackgroundActivity(false)
        appState.isEditorSleeping = false
    }
}

// MARK: - WKWebView Bridge (WYSIWYG Markdown Editor)
struct EditorWebView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        config.setURLSchemeHandler(context.coordinator.resources, forURLScheme: EditorResources.imageScheme)
        config.userContentController.addUserScript(WKUserScript(
            source: "window.localImageScheme = 'markdownnotes-image';",
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))

        // Message handlers for JS → Swift communication
        let handlers: [String] = [
            "contentChanged", "outlineChanged", "wordCount",
            "editorReady", "linkClicked", "imageDropped", "scrollInfo"
        ]
        for handler in handlers {
            config.userContentController.add(context.coordinator, name: handler)
        }

        // Allow local file access
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsLinkPreview = false

        // Transparent background
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor

        context.coordinator.webView = webView
        loadEditorHTML(in: webView)

        // Listen for format commands from menu
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleEditorCommand(_:)),
            name: .editorCommand,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleExportCommand(_:)),
            name: .exportCommand,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFileReloaded(_:)),
            name: .fileContentReloaded,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePreferencesChanged(_:)),
            name: .preferencesDidChange,
            object: nil
        )

        for name in [NSApplication.didResignActiveNotification, NSApplication.didBecomeActiveNotification,
                     NSApplication.didHideNotification, NSApplication.didUnhideNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleActivity(_:)), name: name, object: nil)
        }
        context.coordinator.setForeground(NSApp.isActive)
        return webView
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelBackgroundSleep()
        coordinator.isEditorReady = false
        coordinator.isActive = false
        NotificationCenter.default.removeObserver(coordinator)
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.configuration.userContentController.removeAllUserScripts()
        webView.navigationDelegate = nil
        webView.stopLoading()
        coordinator.webView = nil
        coordinator.pendingContent = ""
        coordinator.pendingDocumentID = nil
        coordinator.resources.documentDirectory = nil
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.resources.documentDirectory = appState.selectedFile?.url.deletingLastPathComponent()
        guard context.coordinator.isEditorReady else { return }
        context.coordinator.syncDocument()

        // Source mode toggle (only when changed)
        if context.coordinator.currentIsSourceMode != appState.isSourceMode {
            context.coordinator.currentIsSourceMode = appState.isSourceMode
            let modeJS = appState.isSourceMode ? "window.editor?.setSourceMode(true)" : "window.editor?.setSourceMode(false)"
            webView.evaluateJavaScript(modeJS, completionHandler: nil)
        }

        // Typewriter mode (only when changed)
        if context.coordinator.currentIsTypewriterMode != appState.isTypewriterMode {
            context.coordinator.currentIsTypewriterMode = appState.isTypewriterMode
            let twJS = appState.isTypewriterMode ? "window.editor?.setTypewriterMode(true)" : "window.editor?.setTypewriterMode(false)"
            webView.evaluateJavaScript(twJS, completionHandler: nil)
        }

        // Theme change / Appearance change
        let effectiveTheme = appState.effectiveTheme(for: colorScheme)
        if context.coordinator.currentAppliedTheme != effectiveTheme {
            context.coordinator.currentAppliedTheme = effectiveTheme
            let themeVal = effectiveTheme.rawValue
            webView.evaluateJavaScript("window.editor?.setTheme('\(themeVal)')", completionHandler: nil)
        }

        if context.coordinator.currentLanguage != appState.preferences.language {
            context.coordinator.currentLanguage = appState.preferences.language
            webView.evaluateJavaScript("window.editor?.setLanguage('\(appState.preferences.language.rawValue)')", completionHandler: nil)
        }

        if context.coordinator.currentPreferences != appState.preferences {
            context.coordinator.currentPreferences = appState.preferences
            context.coordinator.applyEditorPreferences()
        }
    }

    private func loadEditorHTML(in webView: WKWebView) {
        guard let editorURL = Bundle.main.url(forResource: "editor", withExtension: "html", subdirectory: "Editor") else {
            // Fallback: load from bundle root
            if let url = Bundle.main.url(forResource: "editor", withExtension: "html") {
                EditorResources.load(url, in: webView)
            }
            return
        }
        EditorResources.load(editorURL, in: webView)
    }

    // MARK: - Coordinator (Delegate + JS Message Handler)
    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var appState: AppState
        let resources = EditorResources()
        weak var webView: WKWebView?
        var pendingContent: String = ""
        var pendingDocumentID: String?
        var exporter: DocumentExporter?
        var isEditorReady = false
        var isActive = true
        private(set) var isBackgrounded = false
        private var backgroundTimer: Timer?
        private var backgroundGeneration = 0
        var currentAppliedTheme: EditorTheme = .system
        var currentLanguage: AppLanguage = .simplifiedChinese
        var currentPreferences: Preferences
        var currentIsSourceMode: Bool = false
        var currentIsTypewriterMode: Bool = false
        private var cancellables = Set<AnyCancellable>()

        init(appState: AppState) {
            self.appState = appState
            self.currentAppliedTheme = appState.effectiveTheme(for: nil)
            self.currentLanguage = appState.preferences.language
            self.currentPreferences = appState.preferences
            self.currentIsSourceMode = appState.isSourceMode
            self.currentIsTypewriterMode = appState.isTypewriterMode
        }

        // Long-background hibernation releases the WebView after a recoverable snapshot.
        @objc func handleActivity(_ notification: Notification) {
            if let window = notification.object as? NSWindow, window !== webView?.window { return }
            let minimized = webView?.window?.isMiniaturized ?? false
            setForeground(NSApp.isActive && !NSApp.isHidden && !minimized)
        }

        func cancelBackgroundSleep() {
            backgroundGeneration += 1
            backgroundTimer?.invalidate()
            backgroundTimer = nil
        }

        func setForeground(_ foreground: Bool, sleepDelay: TimeInterval = 300) {
            cancelBackgroundSleep()
            isBackgrounded = !foreground
            if isEditorReady {
                webView?.evaluateJavaScript("window.editor?.setBackgrounded(\(!foreground))", completionHandler: nil)
            }
            if !foreground { scheduleBackgroundSleep(after: sleepDelay) }
        }

        private func scheduleBackgroundSleep(after delay: TimeInterval) {
            guard isActive, isBackgrounded else { return }
            backgroundTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in await self?.hibernateEditor() }
            }
            backgroundTimer?.tolerance = min(5, delay / 10)
        }

        func hibernateEditor() async {
            guard isActive, isBackgrounded, !appState.isEditorSleeping else { return }
            guard isEditorReady, exporter == nil, let webView else {
                scheduleBackgroundSleep(after: 60)
                return
            }
            let generation = backgroundGeneration
            do {
                guard let snapshot = try await webView.evaluateJavaScript("window.editor?.captureSession()") as? String,
                      let data = snapshot.data(using: .utf8),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = json["documentID"] as? String,
                      let state = json["state"] as? [String: Any], let content = state["doc"] as? String else {
                    scheduleBackgroundSleep(after: 60) // Composition or an image import is still in flight.
                    return
                }
                guard isActive, isBackgrounded, generation == backgroundGeneration,
                      !appState.isEditorSleeping,
                      id == appState.selectedFile?.url.path, exporter == nil else { return }
                // A minimized secondary window must not suspend another active editor window.
                if NSApp.isActive && NSApp.windows.contains(where: { $0.isVisible && !$0.isMiniaturized && $0 !== webView.window }) {
                    scheduleBackgroundSleep(after: 60)
                    return
                }
                let compressed = try (data as NSData).compressed(using: .lzfse) as Data
                appState.contentDidChange(content)
                appState.sleepingEditorSnapshot = compressed
                appState.isEditorSleeping = true
            } catch {
                // Keep the live editor if capture/compression fails; never discard edits.
                scheduleBackgroundSleep(after: 60)
            }
        }

        private func restoreSleepingSession() {
            guard let compressed = appState.sleepingEditorSnapshot,
                  let data = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
                  let snapshot = String(data: data, encoding: .utf8),
                  let encoded = try? JSONSerialization.data(withJSONObject: [snapshot]) else { return }
            let argument = String(decoding: encoded, as: UTF8.self)
            webView?.evaluateJavaScript("window.editor.restoreSession(\(argument)[0]); window.editor.setSourceMode(\(appState.isSourceMode))") { [weak self] _, error in
                guard let self else { return }
                if error == nil { self.appState.sleepingEditorSnapshot = nil }
            }
        }

        // MARK: JS → Swift Messages
        nonisolated func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                guard isActive else { return }
                switch message.name {
                case "contentChanged":
                    if let data = message.body as? [String: Any],
                       let id = data["documentID"] as? String, id == appState.selectedFile?.url.path,
                       let content = data["content"] as? String {
                        pendingContent = content
                        appState.contentDidChange(content)
                    }
                case "scrollInfo":
                    if var position = message.body as? [String: Any],
                       let id = position.removeValue(forKey: "documentID") as? String {
                        appState.saveReadingPosition(position, documentID: id)
                    }
                case "outlineChanged":
                    if let items = message.body as? [[String: Any]] {
                        appState.outlineItems = items.compactMap { OutlineItem(dict: $0) }
                    }
                case "wordCount":
                    if let info = message.body as? [String: Int] {
                        appState.wordCount = info["words"] ?? 0
                        appState.charCount = info["chars"] ?? 0
                    }
                case "editorReady":
                    isEditorReady = true
                    webView?.evaluateJavaScript("window.editor?.setBackgrounded(\(isBackgrounded))", completionHandler: nil)
                    syncDocument()
                    webView?.evaluateJavaScript("window.editor?.setSourceMode(\(appState.isSourceMode)); window.editor?.setTypewriterMode(\(appState.isTypewriterMode))", completionHandler: nil)
                    // Apply initial theme
                    let effectiveTheme = appState.effectiveTheme(for: nil)
                    currentAppliedTheme = effectiveTheme
                    let themeVal = effectiveTheme.rawValue
                    let language = appState.preferences.language.rawValue
                    webView?.evaluateJavaScript("window.editor?.setTheme('\(themeVal)'); window.editor?.setLanguage('\(language)')", completionHandler: nil)
                    applyEditorPreferences()
                    restoreSleepingSession()
                    webView?.evaluateJavaScript("window.editor?.setBackgrounded(\(isBackgrounded))", completionHandler: nil)
                case "imageDropped":
                    if let data = message.body as? [String: String] {
                        let name = data["name"] ?? "image-\(Int(Date().timeIntervalSince1970)).png"
                        if let dataURL = data["dataURL"], !dataURL.isEmpty {
                            let sourceURL = data["path"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
                            handleImagePaste(dataURL: dataURL, name: name, requestID: data["requestID"], sourceURL: sourceURL)
                        } else if let srcPath = data["path"], !srcPath.isEmpty {
                            handleImageDrop(srcPath: srcPath, requestID: data["requestID"])
                        }
                    }
                case "fileContentReloaded":
                    break // handled by AppState directly
                default:
                    break
                }
            }
        }

        func applyEditorPreferences() {
            guard let webView,
                  let data = try? JSONSerialization.data(withJSONObject: [
                    "fontSize": appState.preferences.editorFontSize,
                    "fontFamily": appState.preferences.editorFontFamily,
                    "lineHeight": appState.preferences.lineHeight,
                    "maxWidth": appState.preferences.maxWidth,
                    "showLineNumbers": appState.preferences.showLineNumbers,
                    "spellCheck": appState.preferences.spellCheck,
                    "smartQuotes": appState.preferences.smartQuotes,
                    "smartDashes": appState.preferences.smartDashes,
                    "bottomPadding": appState.preferences.bottomPadding
                  ]), let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.editor?.setPreferences(\(json))", completionHandler: nil)
        }

        func syncDocument() {
            guard isEditorReady, let file = appState.selectedFile else { return }
            let id = file.url.path
            let directory = file.url.deletingLastPathComponent().path
            let args: [Any]
            let command: String
            if pendingDocumentID != id {
                args = [appState.currentContent, id, appState.readingPosition(for: file.url), appState.isPlainText]
                command = "openDocument"
            } else {
                guard pendingContent != appState.currentContent else { return }
                args = [appState.currentContent]
                command = "setContent"
            }
            pendingDocumentID = id
            pendingContent = appState.currentContent
            guard let encoded = try? JSONSerialization.data(withJSONObject: args),
                  let dirData = try? JSONSerialization.data(withJSONObject: [directory]) else { return }
            let json = String(decoding: encoded, as: UTF8.self)
            let dirJSON = String(decoding: dirData, as: UTF8.self)
            webView?.evaluateJavaScript("window.currentDocDir = \(dirJSON)[0]; window.editor?.\(command)(...\(json))", completionHandler: nil)
        }

        // MARK: Navigation Delegate
        nonisolated func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                decisionHandler(.cancel)
                Task { @MainActor in
                    NSWorkspace.shared.open(url)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        // MARK: Format Commands (from Menu Bar)
        @objc func handleEditorCommand(_ notification: Notification) {
            guard let command = notification.object as? String else { return }
            if command == "image" { chooseImage(); return }
            webView?.evaluateJavaScript("window.editor?.execCommand('\(command)')", completionHandler: nil)
        }

        @objc func handleExportCommand(_ notification: Notification) {
            guard let format = notification.object as? String else { return }
            switch format {
            case "pdf", "pdfPaginated":
                exportPDF(layout: .paginated)
            case "pdfSingle":
                exportPDF(layout: .singlePage)
            case "html":
                exportHTML()
            case "copyHTML":
                copyHTML()
            default:
                break
            }
        }

        // MARK: External file modification handler
        @objc func handleFileReloaded(_ notification: Notification) {
            guard let newContent = notification.object as? String else { return }
            pendingContent = newContent
            let escaped = newContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView?.evaluateJavaScript("window.editor?.setContent(`\(escaped)`)", completionHandler: nil)
        }

        // MARK: Preferences change handler (instant theme & styling sync)
        @objc func handlePreferencesChanged(_ notification: Notification) {
            guard isEditorReady else { return }
            let effectiveTheme = appState.effectiveTheme(for: nil)
            if currentAppliedTheme != effectiveTheme {
                currentAppliedTheme = effectiveTheme
                let themeVal = effectiveTheme.rawValue
                webView?.evaluateJavaScript("window.editor?.setTheme('\(themeVal)')", completionHandler: nil)
            }
            if currentLanguage != appState.preferences.language {
                currentLanguage = appState.preferences.language
                webView?.evaluateJavaScript("window.editor?.setLanguage('\(appState.preferences.language.rawValue)')", completionHandler: nil)
            }
            if currentPreferences != appState.preferences {
                currentPreferences = appState.preferences
                applyEditorPreferences()
            }
        }

        private func chooseImage() {
            guard appState.selectedFile != nil else { return }
            webView?.evaluateJavaScript("reserveImagePosition()") { result, error in
                Task { @MainActor in
                    guard error == nil, let requestID = result as? String else { return }
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image]
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.prompt = "插入图片"
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        let data = try Data(contentsOf: url)
                        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
                        self.handleImagePaste(dataURL: "data:\(mime);base64,\(data.base64EncodedString())", name: url.lastPathComponent, requestID: requestID, sourceURL: url)
                    } catch { self.appState.showError("无法插入图片", error: error) }
                }
            }
        }

        // MARK: Image Drop Handler (drag — path fallback, now unused since FileReader is used)
        private func handleImageDrop(srcPath: String, requestID: String?) {
            guard let fileURL = appState.selectedFile?.url else { return }
            let srcURL = URL(fileURLWithPath: srcPath)
            if appState.preferences.imagePasteMode == .keepOriginal {
                insertImageMarkdown(source: srcURL.absoluteString, name: srcURL.lastPathComponent, requestID: requestID)
                return
            }
            let assetsDir = fileURL.deletingLastPathComponent().appendingPathComponent("assets")
            try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
            let destURL = assetsDir.appendingPathComponent(srcURL.lastPathComponent)
            try? FileManager.default.copyItem(at: srcURL, to: destURL)
            // FIX: Use absolute file:// URL so WKWebView can render the image
            // regardless of the HTML page's baseURL (which is the Editor bundle dir)
            insertImageMarkdown(source: destURL.absoluteString, name: srcURL.lastPathComponent, requestID: requestID)
        }

        // MARK: Image Paste Handler (clipboard / drag via Base64)
        private func handleImagePaste(dataURL: String, name: String, requestID: String?, sourceURL: URL? = nil) {
            guard let fileURL = appState.selectedFile?.url else { return }
            if appState.preferences.imagePasteMode == .base64 {
                insertImageMarkdown(source: dataURL, name: name, requestID: requestID)
                return
            }
            if appState.preferences.imagePasteMode == .keepOriginal, let sourceURL {
                insertImageMarkdown(source: sourceURL.absoluteString, name: name, requestID: requestID)
                return
            }
            // Decode Base64 dataURL: "data:image/png;base64,<data>"
            guard let commaIdx = dataURL.firstIndex(of: ",") else { return }
            let base64String = String(dataURL[dataURL.index(after: commaIdx)...])
            guard let imageData = Data(base64Encoded: base64String) else { return }

            let assetsDir = fileURL.deletingLastPathComponent().appendingPathComponent("assets")
            try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

            // Avoid name collision
            var destName = URL(fileURLWithPath: name).lastPathComponent
            var idx = 1
            while FileManager.default.fileExists(atPath: assetsDir.appendingPathComponent(destName).path) {
                let ext = URL(fileURLWithPath: name).pathExtension
                let base = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
                destName = "\(base)-\(idx).\(ext)"
                idx += 1
            }

            let destURL = assetsDir.appendingPathComponent(destName)
            do { try imageData.write(to: destURL, options: .atomic) }
            catch { appState.showError("无法保存插入的图片", error: error); return }

            // FIX: Use absolute file:// URL so WKWebView can render the image
            // regardless of the HTML page's baseURL (which is the Editor bundle dir)
            insertImageMarkdown(source: destURL.absoluteString, name: destName, requestID: requestID)
        }

        private func insertImageMarkdown(source: String, name: String, requestID: String?) {
            let altText = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let imgMarkdown = "![\(altText)](\(source))"
            if let args = try? JSONSerialization.data(withJSONObject: [imgMarkdown, requestID ?? ""]),
               let json = String(data: args, encoding: .utf8) {
                webView?.evaluateJavaScript("window.editor?.insertAtCursor(...\(json))", completionHandler: nil)
            }
        }

        // MARK: Export
        private func exportPDF(layout: PDFLayout) { exportDocument(asPDF: true, pdfLayout: layout) }
        private func exportHTML() { exportDocument(asPDF: false) }

        private func exportDocument(asPDF: Bool, pdfLayout: PDFLayout = .paginated) {
            guard let webView, let file = appState.selectedFile, exporter == nil else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = asPDF ? [.pdf] : [.html]
            panel.nameFieldStringValue = file.nameWithoutExtension + (asPDF ? ".pdf" : ".html")
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let job = DocumentExporter()
            exporter = job
            Task { @MainActor in
                defer { self.exporter = nil }
                do {
                    let html = try await job.html(from: webView, documentURL: file.url)
                    if asPDF { try await job.savePDF(html: html, to: url, layout: pdfLayout) }
                    else { try html.write(to: url, atomically: true, encoding: .utf8) }
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch { self.appState.showError("导出失败", error: error) }
            }
        }

        private func copyHTML() {
            guard let webView, let file = appState.selectedFile, exporter == nil else { return }
            let job = DocumentExporter()
            exporter = job
            Task { @MainActor in
                defer { self.exporter = nil }
                do {
                    let html = try await job.html(from: webView, documentURL: file.url)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(html, forType: .html)
                    NSPasteboard.general.setString(html, forType: .string)
                } catch { self.appState.showError("复制 HTML 失败", error: error) }
            }
        }
    }
}
