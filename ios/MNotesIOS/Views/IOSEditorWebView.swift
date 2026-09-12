import SwiftUI
import WebKit

struct IOSEditorWebView: UIViewRepresentable {
    @EnvironmentObject var appState: IOSAppState
    @Environment(\.colorScheme) var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let handlers = ["contentChanged", "editorReady", "wordCount"]
        for handler in handlers {
            config.userContentController.add(context.coordinator, name: handler)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.webView = webView

        // Load shared editor HTML
        if let editorURL = Bundle.main.url(forResource: "editor", withExtension: "html", subdirectory: "Editor") ??
           Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleCommand(_:)),
            name: NSNotification.Name("IOSEditorCommand"),
            object: nil
        )

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let themeName = colorScheme == .dark ? "liquid-glass-dark" : "liquid-glass-light"
        webView.evaluateJavaScript("window.editor?.setTheme('\(themeName)')", completionHandler: nil)
    }

    @MainActor
    class Coordinator: NSObject, WKScriptMessageHandler {
        var appState: IOSAppState
        weak var webView: WKWebView?
        var isReady = false

        init(appState: IOSAppState) {
            self.appState = appState
        }

        nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                switch message.name {
                case "editorReady":
                    isReady = true
                    if let data = try? JSONSerialization.data(withJSONObject: [appState.currentContent]),
                       let json = String(data: data, encoding: .utf8) {
                        webView?.evaluateJavaScript("window.editor?.setContent(...\(json))", completionHandler: nil)
                    }
                case "contentChanged":
                    if let dict = message.body as? [String: Any],
                       let content = dict["content"] as? String {
                        appState.currentContent = content
                        appState.isDirty = true
                    }
                case "wordCount":
                    if let dict = message.body as? [String: Int] {
                        appState.wordCount = dict["words"] ?? 0
                    }
                default:
                    break
                }
            }
        }

        @objc func handleCommand(_ notification: Notification) {
            guard let command = notification.object as? String else { return }
            webView?.evaluateJavaScript("window.editor?.execCommand('\(command)')", completionHandler: nil)
        }
    }
}
