import SwiftUI

// MARK: - NoteListView (fixed display bug + improved UI)
struct NoteListView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder: SortOrder = .modified
    @State private var searchText = ""
    @State private var diskFiles: [FileNode] = []  // ← fix: read directly from disk

    var filteredFiles: [FileNode] {
        let filtered = searchText.isEmpty ? diskFiles :
            diskFiles.filter {
                $0.nameWithoutExtension.localizedCaseInsensitiveContains(searchText) ||
                appState.globalSearchPreview($0.url, query: searchText)
            }
        return filtered.sorted(by: sortOrder.comparator)
    }

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            searchBar
            Divider()

            if diskFiles.isEmpty && appState.selectedFolder != nil {
                emptyState
            } else if filteredFiles.isEmpty && !searchText.isEmpty {
                noResultsState
            } else {
                fileList
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.25))
        // ↓ fix: load files directly from disk when folder changes
        .onChange(of: appState.selectedFolder) { _, folder in
            loadFilesFromDisk(folder: folder)
        }
        // Reload when file system changes (from FSWatcher)
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            if let changedURL = notif.object as? URL,
               changedURL == appState.selectedFolder?.url {
                loadFilesFromDisk(folder: appState.selectedFolder)
            } else {
                loadFilesFromDisk(folder: appState.selectedFolder)
            }
        }
        .onAppear {
            loadFilesFromDisk(folder: appState.selectedFolder)
        }
    }

    // MARK: Sub-views

    var listHeader: some View {
        HStack(spacing: 8) {
            Text(appState.selectedFolder?.name ?? "文档")
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.displayName)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("排序方式")
            .menuStyle(.borderlessButton)

            Button {
                createNewNote()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("新建文档 (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.caption)
            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onChange(of: searchText) { _, q in
                    appState.globalSearchQuery = q
                }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredFiles) { node in
                    NoteListItem(
                        node: node,
                        isSelected: appState.selectedFile?.url == node.url,
                        searchHighlight: searchText
                    )
                    .onTapGesture { selectFile(node) }
                    .contextMenu { fileContextMenu(node: node) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("此文件夹为空")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Button("新建文档") { createNewNote() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("未找到匹配文档")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Text("\"\(searchText)\"")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    func fileContextMenu(node: FileNode) -> some View {
        Button("打开") { selectFile(node) }
        Button("在 Finder 中显示") {
            NSWorkspace.shared.selectFile(node.url.path, inFileViewerRootedAtPath: "")
        }
        Divider()
        Button("复制文件路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        }
        Divider()
        Button("移到废纸篓", role: .destructive) {
            appState.deleteFile(node)
            loadFilesFromDisk(folder: appState.selectedFolder)
        }
    }

    // MARK: - Actions

    private func selectFile(_ node: FileNode) {
        appState.openFile(node.url)
        appState.selectedFile = node
    }

    private func createNewNote() {
        if let node = appState.createNewFile(in: appState.selectedFolder) {
            appState.openFile(node.url)
            appState.selectedFile = node
            loadFilesFromDisk(folder: appState.selectedFolder)
        }
    }

    /// Core fix: read directly from disk, not from children cache
    private func loadFilesFromDisk(folder: FileNode?) {
        guard let folder else {
            diskFiles = []
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let files = folder.markdownFilesFromDisk()
            DispatchQueue.main.async {
                diskFiles = files
                // Also refresh children cache for sidebar
                folder.loadChildren()
            }
        }
    }
}

// MARK: - Note List Item
struct NoteListItem: View {
    let node: FileNode
    let isSelected: Bool
    let searchHighlight: String
    @State private var previewText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(node.nameWithoutExtension)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(node.modifiedDateString)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected
                        ? Color.white.opacity(0.7)
                        : Color(NSColor.tertiaryLabelColor))
            }

            if !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected
                        ? Color.white.opacity(0.8)
                        : Color(NSColor.secondaryLabelColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground)
        .contentShape(Rectangle())
        .onAppear { loadPreview() }
        .onChange(of: node.url) { _, _ in loadPreview() }
    }

    @ViewBuilder
    var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        } else {
            Color.clear
        }
    }

    private func loadPreview() {
        let url = node.url
        DispatchQueue.global(qos: .utility).async {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let lines = content.components(separatedBy: "\n")
            let bodyLines = lines.filter { line in
                !line.hasPrefix("#") && !line.hasPrefix("---") &&
                !line.hasPrefix("```") && !line.trimmingCharacters(in: .whitespaces).isEmpty
            }
            var preview = bodyLines.prefix(2).joined(separator: " ")
            // Strip simple markdown
            preview = preview
                .replacingOccurrences(of: "\\*{1,3}([^*]+)\\*{1,3}", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "!?\\[[^\\]]*\\]\\([^)]*\\)", with: "", options: .regularExpression)
            preview = String(preview.prefix(140))

            DispatchQueue.main.async { previewText = preview }
        }
    }
}

// MARK: - Sort Order
enum SortOrder: CaseIterable {
    case modified, created, name, size

    var displayName: String {
        switch self {
        case .modified: "修改时间"
        case .created: "创建时间"
        case .name: "名称"
        case .size: "文件大小"
        }
    }

    var comparator: (FileNode, FileNode) -> Bool {
        switch self {
        case .modified:
            return { a, b in
                (a.modifiedDate ?? .distantPast) > (b.modifiedDate ?? .distantPast)
            }
        case .created:
            return { a, b in
                (a.createdDate ?? .distantPast) > (b.createdDate ?? .distantPast)
            }
        case .name:
            return { a, b in
                a.url.lastPathComponent.localizedCompare(b.url.lastPathComponent) == .orderedAscending
            }
        case .size:
            return { a, b in (a.fileSize ?? 0) > (b.fileSize ?? 0) }
        }
    }
}
