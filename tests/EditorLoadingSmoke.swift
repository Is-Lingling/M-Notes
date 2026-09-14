import Cocoa
import WebKit

@main
@MainActor
struct EditorLoadingSmoke {
    static var webView: WKWebView!
    static var resources: EditorResources!
    static var fixtureDirectory: URL!

    static func main() throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 2 else { fatalError("Pass the bundled editor.html path") }
        fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        // Image outside the app resource directory, with a Unicode/space filename.
        let imageURL = fixtureDirectory.appendingPathComponent("测试 image.png")
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")!
        try png.write(to: imageURL)
        resources = EditorResources()
        resources.documentDirectory = fixtureDirectory
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(resources, forURLScheme: EditorResources.imageScheme)
        config.userContentController.addUserScript(WKUserScript(
            source: "window.localImageScheme = 'markdownnotes-image';",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 650), configuration: config)
        EditorResources.load(URL(fileURLWithPath: CommandLine.arguments[1]), in: webView)
        Task { @MainActor in
            do {
                try await waitFor("Boolean(window.editor?._view)")
                try await waitFor("typeof window.mermaid === 'undefined'")
                let content = "# Native loading test\n\nVisible body\n\n![image](\(imageURL.absoluteString))\n"
                let data = try JSONSerialization.data(withJSONObject: [content])
                let json = String(decoding: data, as: UTF8.self)
                _ = try await webView.evaluateJavaScript("window.editor.setContent(...\(json))")
                try await waitFor("document.querySelector('.cm-content')?.textContent.includes('Visible body') === true")
                try await waitFor("document.querySelector('.cm-rendered-image')?.naturalWidth > 0")
                _ = try await webView.evaluateJavaScript("window.editor.setSourceMode(true)")
                try await waitFor("document.querySelector('.cm-content')?.textContent.includes('![image]') === true")
                _ = try await webView.evaluateJavaScript("window.editor.setSourceMode(false); window.editor.setContent('# Second file\\n\\nSecond body')")
                try await waitFor("document.querySelector('.cm-content')?.textContent.includes('Second body') === true")
                try await waitFor("document.querySelector('.cm-content')?.getBoundingClientRect().height > 0")
                try await waitFor("typeof window.mermaid === 'undefined'")
                _ = try await webView.evaluateJavaScript("window.editor.setContent('# Diagram\\n\\n```mermaid\\ngraph TD\\nA-->B\\n```\\n'); window.editor.gotoLine(1)")
                try await waitFor("document.querySelector('.cm-mermaid-widget svg') !== null")
                print("PASS: on-demand Mermaid; native editor loads, body displays, local image loads, source mode and file switch work")
                try? FileManager.default.removeItem(at: fixtureDirectory)
                exit(0)
            } catch {
                fputs("FAIL: \(error)\n", stderr)
                try? FileManager.default.removeItem(at: fixtureDirectory)
                exit(1)
            }
        }
        NSApplication.shared.run()
    }

    static func waitFor(_ expression: String) async throws {
        for _ in 0..<100 {
            if (try? await webView.evaluateJavaScript(expression)) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "EditorLoadingSmoke", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Timed out: \(expression)"])
    }
}
