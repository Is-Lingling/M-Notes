import AppKit
import WebKit
import PDFKit

@main @MainActor
struct ExportSmoke {
    static var view: WKWebView!
    static func main() {
        _ = NSApplication.shared
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        EditorResources.load(URL(fileURLWithPath: CommandLine.arguments[1]), in: view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { fputs("FAIL: export timed out\n", stderr); exit(2) }
        Task { @MainActor in
            do {
                for _ in 0..<100 {
                    if (try? await view.evaluateJavaScript("Boolean(window.editor?._view)")) as? Bool == true { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: fixture) }
                let image = NSImage(size: NSSize(width: 240, height: 140))
                image.lockFocus()
                NSColor.systemRed.setFill()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: 240, height: 140)).fill()
                NSColor.systemBlue.setFill()
                NSBezierPath(ovalIn: NSRect(x: 80, y: 30, width: 80, height: 80)).fill()
                image.unlockFocus()
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not create fixture image") }
                try png.write(to: fixture.appendingPathComponent("image with space.png"))
                let content = "# PDF 标题\n\n```python\ndef greet():\n    return True\n```\n\n数学公式 $x^2$\n\n![embedded](image%20with%20space.png)\n\n![missing](missing.png)\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```mermaid\ngraph LR\nA-->B\n```\n\n" + (1...180).map { "第 \($0) 行：测试分页与正文导出。\n" }.joined()
                let args = String(decoding: try JSONSerialization.data(withJSONObject: [content]), as: UTF8.self)
                _ = try await view.evaluateJavaScript("window.editor.setContent(...\(args))")
                fputs("Editor ready; rendering HTML\n", stderr)
                let service = DocumentExporter(resourceDirectory: URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent())
                let html = try await service.html(from: view, documentURL: fixture.appendingPathComponent("test.md"))
                guard html.contains("PDF 标题"), html.contains("hljs"), html.contains("katex"),
                      html.contains("data:image/png;base64,"), html.contains("图片无法加载"), html.contains("<svg"),
                      html.contains("data:font/woff2;base64,") else { fatalError("Missing rendered content") }
                fputs("HTML ready; printing PDF\n", stderr)
                let outputDir = URL(fileURLWithPath: "/tmp/pdfs", isDirectory: true)
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
                let paginatedURL = outputDir.appendingPathComponent("mnotes-export-paginated.pdf")
                let singleURL = outputDir.appendingPathComponent("mnotes-export-single.pdf")
                try await service.savePDF(html: html, to: paginatedURL, layout: .paginated)
                try await service.savePDF(html: html, to: singleURL, layout: .singlePage)
                guard let paginated = PDFDocument(url: paginatedURL), paginated.pageCount >= 2,
                      paginated.string?.contains("180") == true else { fatalError("Paginated PDF incomplete") }
                guard let single = PDFDocument(url: singleURL), single.pageCount == 1,
                      single.string?.contains("180") == true else { fatalError("Single-page PDF incomplete") }
                guard containsRedImage(in: paginated), containsRedImage(in: single) else { fatalError("Embedded image missing from PDF pixels") }
                try html.write(to: outputDir.appendingPathComponent("mnotes-export-smoke.html"), atomically: true, encoding: .utf8)
                print("PASS: images rendered; single-page PDF has 1 page; paginated PDF has \(paginated.pageCount) pages")
                exit(0)
            } catch { print("FAIL: \(error)"); exit(1) }
        }
        NSApplication.shared.run()
    }

    static func containsRedImage(in document: PDFDocument) -> Bool {
        for index in 0..<min(document.pageCount, 2) {
            guard let page = document.page(at: index) else { continue }
            let thumbnail = page.thumbnail(of: NSSize(width: 1000, height: 1400), for: .mediaBox)
            guard let data = thumbnail.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data) else { continue }
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 3) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 3) {
                    guard let source = bitmap.colorAt(x: x, y: y) else { continue }
                    let color = source.usingColorSpace(.sRGB) ?? source
                    if color.redComponent > 0.6 && color.redComponent > color.greenComponent * 1.5 && color.redComponent > color.blueComponent * 1.5 { return true }
                }
            }
        }
        return false
    }
}
