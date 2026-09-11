import Foundation
import WebKit
import UniformTypeIdentifiers

/// Editor resources belong to the app, which may be outside the user's home directory.
/// Note images use a separate, image-only route so loading the editor doesn't require
/// granting its file origin access to the whole filesystem.
@MainActor
final class EditorResources: NSObject, WKURLSchemeHandler {
    static let imageScheme = "markdownnotes-image"
    var documentDirectory: URL?

    static func load(_ editorURL: URL, in webView: WKWebView) {
        webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            guard let requestURL = urlSchemeTask.request.url,
                  requestURL.scheme == Self.imageScheme,
                  requestURL.host == "local" else {
                throw URLError(.badURL)
            }
            let fileURL = URL(fileURLWithPath: requestURL.path).resolvingSymlinksInPath()
            let roots = [FileManager.default.homeDirectoryForCurrentUser, documentDirectory].compactMap { $0 }
            let isAllowed = roots.contains { root in
                let path = root.resolvingSymlinksInPath().path
                return fileURL.path.hasPrefix(path.hasSuffix("/") ? path : path + "/")
            }
            guard isAllowed,
                  let type = UTType(filenameExtension: fileURL.pathExtension),
                  type.conforms(to: .image),
                  let mimeType = type.preferredMIMEType else {
                throw URLError(.noPermissionsToReadFile)
            }
            let data = try Data(contentsOf: fileURL)
            urlSchemeTask.didReceive(URLResponse(url: requestURL, mimeType: mimeType,
                                                expectedContentLength: data.count, textEncodingName: nil))
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Requests finish synchronously; no pending task to cancel.
    }
}
