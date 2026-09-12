import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    appState.globalSearchVisible.toggle()
                } label: {
                    if appState.globalSearchVisible {
                        Label(appState.preferences.language == .english ? "Back to Recents" : "返回最近使用", systemImage: "chevron.left")
                    } else {
                        Label(appState.preferences.language == .english ? "Search" : "全文搜索", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                if !appState.globalSearchVisible {
                    // New Folder button (at the top of collapsible sidebar)
                    Button {
                        appState.promptCreateCategory()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(appState.preferences.language == .english ? "New Folder" : "新建文件夹")
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if appState.globalSearchVisible {
                GlobalSearchPanel()
            } else {
                List {
                    Section {
                        // Categories / Folders
                        ForEach(appState.recentCategories) { category in
                            RecentCategoryRow(category: category)
                        }

                        // Uncategorized Files
                        ForEach(appState.uncategorizedFiles, id: \.self) { url in
                            RecentFileRow(url: url, inCategoryId: nil)
                        }
                    } header: {
                        HStack {
                            Text(appState.preferences.language == .english ? "Recent Files" : "最近使用")
                            Spacer()
                        }
                        .contextMenu {
                            Button(appState.preferences.language == .english ? "New Folder…" : "新建文件夹…") {
                                appState.promptCreateCategory()
                            }
                            Button(appState.preferences.language == .english ? "New Document" : "新建文档") {
                                if let node = appState.createNewFile() {
                                    appState.openFile(node.url)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            SettingsLink {
                Label("偏好设置", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(NotesColors.sidebarBackground)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                          ["md", "markdown", "mdown", "txt"].contains(url.pathExtension.lowercased()) else { return }
                    Task { @MainActor in appState.openFile(url) }
                }
            }
            return true
        }
    }
}

// MARK: - Category Row
struct RecentCategoryRow: View {
    let category: RecentCategory
    @EnvironmentObject var appState: AppState
    @State private var isTargeted = false

    private var isExpanded: Binding<Bool> {
        Binding(
            get: {
                appState.recentCategories.first(where: { $0.id == category.id })?.isExpanded ?? true
            },
            set: { val in
                if let idx = appState.recentCategories.firstIndex(where: { $0.id == category.id }) {
                    appState.recentCategories[idx].isExpanded = val
                    appState.saveRecentFilesAndCategories()
                }
            }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            if category.fileURLs.isEmpty {
                Text(appState.preferences.language == .english ? "Empty Folder (Drag files here)" : "空文件夹（可拖拽文件至此）")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
                    .padding(.leading, 12)
            } else {
                ForEach(category.fileURLs, id: \.self) { url in
                    RecentFileRow(url: url, inCategoryId: category.id)
                        .padding(.leading, 6)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isTargeted ? "folder.fill" : "folder")
                    .foregroundStyle(Color.accentColor)
                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(category.fileURLs.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(NSColor.tertiaryLabelColor).opacity(0.15), in: Capsule())
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(isTargeted ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers, targetCategoryId: category.id)
        }
        .contextMenu {
            Button(appState.preferences.language == .english ? "New Document in Folder" : "在文件夹中新建文档") {
                if let node = appState.createNewFile() {
                    appState.openFile(node.url)
                    appState.moveFileToCategory(fileURL: node.url, targetCategoryId: category.id)
                }
            }
            Button(appState.preferences.language == .english ? "Rename Folder…" : "重命名文件夹…") {
                appState.promptRenameCategory(id: category.id)
            }
            Divider()
            Button(appState.preferences.language == .english ? "New Folder…" : "新建文件夹…") {
                appState.promptCreateCategory()
            }
            Button(role: .destructive) {
                appState.confirmAndDeleteCategory(id: category.id)
            } label: {
                Label(appState.preferences.language == .english ? "Delete Folder" : "删除文件夹", systemImage: "trash")
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetCategoryId: UUID) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                      ["md", "markdown", "mdown", "txt"].contains(url.pathExtension.lowercased()) else { return }
                Task { @MainActor in
                    appState.openFile(url)
                    appState.moveFileToCategory(fileURL: url, targetCategoryId: targetCategoryId)
                }
            }
        }
        return true
    }
}

// MARK: - File Row
struct RecentFileRow: View {
    let url: URL
    var inCategoryId: UUID? = nil
    @EnvironmentObject var appState: AppState
    @State private var isTargeted = false

    private var isOpen: Bool { appState.selectedFile?.url == url }

    var body: some View {
        Button { appState.openFile(url) } label: {
            HStack(spacing: 7) {
                Image(systemName: isOpen ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(isOpen ? Color.accentColor : .secondary)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fontWeight(isOpen ? .medium : .regular)
                Spacer(minLength: 0)
                // "显示已打开文字可以去掉" - text removed
            }
            .font(.system(size: 12))
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(
                isTargeted ? Color.accentColor.opacity(0.25) :
                (isOpen ? Color.accentColor.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(url.path)
        .accessibilityLabel(url.lastPathComponent)
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data, let droppedURL = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        if inCategoryId != nil {
                            appState.moveFileToCategory(fileURL: droppedURL, targetCategoryId: inCategoryId)
                        }
                        appState.reorderFile(dragged: droppedURL, target: url)
                    }
                }
            }
            return true
        }
        .contextMenu {
            Button(appState.preferences.language == .english ? "Open" : "打开") {
                appState.openFile(url)
            }
            Button(appState.preferences.language == .english ? "Rename…" : "重命名…") {
                appState.promptRenameFile(url)
            }

            if !appState.recentCategories.isEmpty || inCategoryId != nil {
                Menu(appState.preferences.language == .english ? "Move to Folder" : "移动到文件夹") {
                    if inCategoryId != nil {
                        Button(appState.preferences.language == .english ? "Uncategorized" : "未分类（移出文件夹）") {
                            appState.moveFileToCategory(fileURL: url, targetCategoryId: nil)
                        }
                        Divider()
                    }
                    ForEach(appState.recentCategories) { cat in
                        if cat.id != inCategoryId {
                            Button(cat.name) {
                                appState.moveFileToCategory(fileURL: url, targetCategoryId: cat.id)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(appState.preferences.language == .english ? "Show in Finder" : "在 Finder 中显示") {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
            Button(appState.preferences.language == .english ? "Remove from Recent" : "从最近使用中移除") {
                appState.removeRecentFile(url)
            }

            Divider()

            Button(appState.preferences.language == .english ? "New Folder…" : "新建文件夹…") {
                appState.promptCreateCategory()
            }

            Button(role: .destructive) {
                appState.confirmAndDeleteRecentFile(url)
            } label: {
                Label(appState.preferences.language == .english ? "Delete File" : "删除文件", systemImage: "trash")
            }
        }
    }
}
