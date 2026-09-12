import AppKit
import WebKit
import UniformTypeIdentifiers
import PDFKit

enum PDFLayout {
    case singlePage
    case paginated
}

/// Produces portable HTML and PDF from the same fully rendered document.
@MainActor
final class DocumentExporter: NSObject, WKNavigationDelegate {
    private var printView: WKWebView?
    private var loaded: CheckedContinuation<Void, Error>?
    private let resourceDirectory: URL?

    init(resourceDirectory: URL? = Bundle.main.resourceURL?.appendingPathComponent("Editor")) {
        self.resourceDirectory = resourceDirectory
        super.init()
    }

    func html(from editor: WKWebView, documentURL: URL) async throws -> String {
        guard let result = try await editor.callAsyncJavaScript("return await window.editor.getExportDocument()", arguments: [:], in: nil, contentWorld: .page) as? [String: Any],
              var html = result["html"] as? String else { throw CocoaError(.fileReadCorruptFile) }
        let missingImageText = (result["language"] as? String) == "en" ? "Image unavailable" : "图片无法加载"
        for image in result["images"] as? [[String: String]] ?? [] {
            guard let token = image["token"], let source = image["src"] else { continue }
            if source.hasPrefix("data:") { html = html.replacingOccurrences(of: token, with: source); continue }
            guard let url = resolvedImageURL(source, relativeTo: documentURL) else { continue }
            let data: Data?
            let mime: String
            if url.isFileURL {
                data = try? Data(contentsOf: url)
                mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
            } else if ["http", "https"].contains(url.scheme ?? "") {
                var request = URLRequest(url: url); request.timeoutInterval = 15
                let result = try? await URLSession.shared.data(for: request)
                data = result?.0
                mime = result?.1.mimeType ?? "image/png"
            } else { data = nil; mime = "" }
            if let data, mime.hasPrefix("image/") {
                html = html.replacingOccurrences(of: token, with: "data:\(mime);base64,\(data.base64EncodedString())")
            } else {
                // Missing images remain explicit in the export, not broken browser icons.
                let pattern = "<img[^>]*src=\"" + NSRegularExpression.escapedPattern(for: token) + "\"[^>]*>"
                html = html.replacingOccurrences(of: pattern, with: "<span class=\"missing-image\">\(missingImageText)</span>", options: .regularExpression)
            }
        }
        if let root = resourceDirectory {
            var mathCSS = (try? String(contentsOf: root.appendingPathComponent("katex/katex.min.css"), encoding: .utf8)) ?? ""
            let fontRegex = try NSRegularExpression(pattern: "url\\(([^)]+)\\)")
            for match in fontRegex.matches(in: mathCSS, range: NSRange(mathCSS.startIndex..., in: mathCSS)).reversed() {
                guard let range = Range(match.range(at: 1), in: mathCSS), let entire = Range(match.range, in: mathCSS) else { continue }
                let path = String(mathCSS[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let fontURL = root.appendingPathComponent("katex").appendingPathComponent(path)
                if let data = try? Data(contentsOf: fontURL) {
                    mathCSS.replaceSubrange(entire, with: "url(data:font/\(fontURL.pathExtension);base64,\(data.base64EncodedString()))")
                }
            }
            let highlightCSS = (try? String(contentsOf: root.appendingPathComponent("highlight/styles/github.min.css"), encoding: .utf8)) ?? ""
            html = html.replacingOccurrences(of: "</head>", with: "<style>\(mathCSS)\n\(highlightCSS)</style></head>")
        }
        return html
    }

    private func resolvedImageURL(_ source: String, relativeTo documentURL: URL) -> URL? {
        if source.hasPrefix("file://"), let fileURL = URL(string: source) { return fileURL.standardizedFileURL }
        let decoded = source.removingPercentEncoding ?? source
        if decoded.hasPrefix("/") { return URL(fileURLWithPath: decoded).standardizedFileURL }
        if let remote = URL(string: decoded), ["http", "https"].contains(remote.scheme ?? "") { return remote }
        let cleanPath = decoded.split(separator: "#", maxSplits: 1).first.map(String.init) ?? decoded
        return documentURL.deletingLastPathComponent()
            .appendingPathComponent(cleanPath)
            .standardizedFileURL
    }

    func savePDF(html: String, to url: URL, layout: PDFLayout = .paginated) async throws {
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 523.28, height: 769.89))
        printView = view
        view.navigationDelegate = self
        defer { printView = nil }
        try await withCheckedThrowingContinuation { continuation in
            loaded = continuation
            view.loadHTMLString(html, baseURL: nil)
        }
        // Wait for actual image/font readiness, not an arbitrary delay.
        _ = try await view.callAsyncJavaScript("""
            await Promise.all(Array.from(document.images).map(img => img.decode().catch(() => {})));
            await document.fonts.ready;
            return true;
            """, arguments: [:], in: nil, contentWorld: .page)
        if layout == .singlePage {
            guard let height = try await view.callAsyncJavaScript("""
                const style = document.createElement('style');
                style.textContent = 'html,body{margin:0!important;padding:0!important;max-width:none!important}body{padding:36px!important;box-sizing:border-box!important}img,svg{max-width:100%!important;height:auto!important}';
                document.head.appendChild(style);
                await Promise.all(Array.from(document.images).map(img => img.decode().catch(() => {})));
                await document.fonts.ready;
                return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, 1);
                """, arguments: [:], in: nil, contentWorld: .page) as? Double else { throw CocoaError(.fileReadCorruptFile) }
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: 523.28, height: ceil(height))
            let data = try await view.pdf(configuration: config)
            try data.write(to: url, options: .atomic)
            return
        }

        // Render vector PDF slices at line-safe boundaries. This avoids depending on
        // macOS printer services, which can stall even when no print panel is shown.
        guard let pages = try await view.callAsyncJavaScript("""
            const style = document.createElement('style');
            style.textContent = 'body{margin:0;padding:0;max-width:none;font-size:11pt}pre{font-size:9pt}img,svg{max-height:700px;max-width:100%;height:auto}';
            document.head.appendChild(style);
            await document.fonts.ready;
            const protectedRects = [];
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while(walker.nextNode()) {
                if (!walker.currentNode.textContent.trim()) continue;
                const range = document.createRange(); range.selectNodeContents(walker.currentNode);
                for(const r of range.getClientRects()) if(r.height > 0) protectedRects.push([r.top + scrollY, r.bottom + scrollY]);
            }
            for(const el of document.querySelectorAll('img,svg,tr,.katex-display,h1,h2,h3,h4,h5,h6')) {
                const r = el.getBoundingClientRect();
                if(r.height < 760) protectedRects.push([r.top + scrollY, r.bottom + scrollY]);
            }
            const height = document.documentElement.scrollHeight, result = [];
            let from = 0;
            while(from < height) {
                let to = Math.min(from + 769.89, height);
                for(let pass=0;pass<50;pass++) {
                    const crossing = protectedRects.filter(r => r[0] < to && r[1] > to && r[1]-r[0] < 769.89);
                    if(!crossing.length) break;
                    const adjusted = Math.min(...crossing.map(r => r[0])) - 1;
                    if(adjusted <= from + 1) break;
                    to = adjusted;
                }
                result.push({from, height:to-from}); from = to;
            }
            return result;
            """, arguments: [:], in: nil, contentWorld: .page) as? [[String: Double]] else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw CocoaError(.fileWriteUnknown) }
        for page in pages {
            guard let from = page["from"], let height = page["height"] else { continue }
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: from, width: 523.28, height: height)
            let data = try await view.pdf(configuration: config)
            guard let source = CGPDFDocument(CGDataProvider(data: data as CFData)!), let firstPage = source.page(at: 1) else { throw CocoaError(.fileReadCorruptFile) }
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 36, y: 841.89 - 36 - height)
            context.drawPDFPage(firstPage)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        try (output as Data).write(to: url, options: .atomic)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?.resume(); loaded = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loaded?.resume(throwing: error); loaded = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loaded?.resume(throwing: error); loaded = nil }
}
