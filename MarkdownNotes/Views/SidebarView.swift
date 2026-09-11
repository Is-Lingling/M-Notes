import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    appState.globalSearchVisible.toggle()
                } label: {
                    if appState.globalSearchVisible {
                        Label("返回最近使用", systemImage: "chevron.left")
                    } else {
                        Label("全文搜索", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if !appState.globalSearchVisible { Text("⌘⇧F").foregroundStyle(.tertiary) }
            }
            .font(.system(size: 12))
            .padding(12)
            Divider()
            if appState.globalSearchVisible {
                GlobalSearchPanel()
            } else {
                List {
                    Section("最近使用") {
                        ForEach(appState.recentFiles, id: \.self) { url in RecentFileRow(url: url) }
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

struct RecentFileRow: View {
    let url: URL
    @EnvironmentObject var appState: AppState
    private var isOpen: Bool { appState.selectedFile?.url == url }
    var body: some View {
        Button { appState.openFile(url) } label: {
            HStack(spacing: 7) {
                Image(systemName: isOpen ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(isOpen ? Color.accentColor : .secondary)
                Text(url.lastPathComponent).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                if isOpen { Text("已打开").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            .font(.system(size: 12))
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(isOpen ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(url.path)
        .accessibilityLabel(url.lastPathComponent + (isOpen ? "，已打开" : ""))
        .contextMenu {
            Button(appState.preferences.language == .english ? "Show in Finder" : "在 Finder 中显示") {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
            Button(appState.preferences.language == .english ? "Remove from Recent" : "从最近使用中移除") {
                appState.removeRecentFile(url)
            }
            Divider()
            Button(role: .destructive) {
                appState.confirmAndDeleteRecentFile(url)
            } label: {
                Label(appState.preferences.language == .english ? "Delete File" : "删除文件", systemImage: "trash")
            }
        }
    }
}
