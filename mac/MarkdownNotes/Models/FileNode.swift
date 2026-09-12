import Foundation
import Combine

// MARK: - File System Node
class FileNode: ObservableObject, Identifiable, Hashable {
    let url: URL
    @Published var children: [FileNode] = []
    @Published var isLoaded: Bool = false

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var nameWithoutExtension: String { url.deletingPathExtension().lastPathComponent }

    var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    var isMarkdown: Bool {
        ["md", "markdown", "mdown", "txt"].contains(url.pathExtension.lowercased())
    }

    var modifiedDate: Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
    var createdDate: Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    var fileSize: Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    var modifiedDateString: String {
        guard let date = modifiedDate else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"
            fmt.locale = Locale(identifier: "zh_CN")
            return fmt.string(from: date)
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    init(url: URL) {
        self.url = url
    }

    // MARK: - Children Loading (always refresh from disk)
    @discardableResult
    func loadChildren() -> [FileNode] {
        guard isDirectory else { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey,
                                         .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let filtered = contents.filter { childURL in
            let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDir || ["md", "markdown", "mdown", "txt"]
                .contains(childURL.pathExtension.lowercased())
        }
        .sorted { a, b in
            let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aIsDir != bIsDir { return aIsDir }
            return a.lastPathComponent.localizedCompare(b.lastPathComponent) == .orderedAscending
        }

        let newChildren = filtered.map { childURL -> FileNode in
            // Reuse existing child node if possible
            if let existing = children.first(where: { $0.url == childURL }) {
                return existing
            }
            return FileNode(url: childURL)
        }

        DispatchQueue.main.async {
            self.children = newChildren
            self.isLoaded = true
        }
        return newChildren
    }

    // MARK: - Direct disk read (bypasses children cache — fixes display bug)
    /// Read all markdown files from disk synchronously — used by NoteListView
    func markdownFilesFromDisk() -> [FileNode] {
        guard isDirectory else { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [FileNode] = []
        for childURL in contents {
            let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                // Recurse into subdirectory
                result.append(contentsOf: FileNode(url: childURL).markdownFilesFromDisk())
            } else if ["md", "markdown", "mdown", "txt"].contains(childURL.pathExtension.lowercased()) {
                result.append(FileNode(url: childURL))
            }
        }
        return result
    }

    // All markdown files from children (cached)
    var allMarkdownFiles: [FileNode] {
        var result: [FileNode] = []
        for child in children {
            if child.isDirectory {
                result.append(contentsOf: child.allMarkdownFiles)
            } else if child.isMarkdown {
                result.append(child)
            }
        }
        return result
    }

    // MARK: - Hashable
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

// MARK: - Outline Item
struct OutlineItem: Identifiable, Equatable {
    let id: String
    let level: Int
    let text: String
    let lineNumber: Int

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let level = dict["level"] as? Int,
              let text = dict["text"] as? String,
              let line = dict["line"] as? Int else { return nil }
        self.id = id
        self.level = level
        self.text = text
        self.lineNumber = line
    }
}

// MARK: - File System Manager
class FileSystemManager {
    func read(url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
    func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func move(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }
    func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
