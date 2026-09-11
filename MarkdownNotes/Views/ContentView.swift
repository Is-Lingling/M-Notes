import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("outlineColumnWidth") private var outlineColumnWidth: Double = 230
    @State private var isDraggingOutline = false

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Column 1: Workspace & File Tree Sidebar
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
            } detail: {
                HStack(spacing: 0) {
                    // Column 2: Middle Outline Column (collapsible, toggleable, resizable)
                    if appState.outlinePanelVisible {
                        OutlineColumnView()
                            .frame(width: max(160, min(outlineColumnWidth, 480)))
                            .transition(.move(edge: .leading).combined(with: .opacity))

                        // Draggable Divider Handle
                        Rectangle()
                            .fill(NotesColors.separator)
                            .frame(width: 1)
                            .overlay(
                                Color.clear
                                    .frame(width: 9)
                                    .contentShape(Rectangle())
                                    .onHover { inside in
                                        if inside {
                                            NSCursor.resizeLeftRight.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { val in
                                                isDraggingOutline = true
                                                let newWidth = outlineColumnWidth + val.translation.width
                                                outlineColumnWidth = max(160, min(newWidth, 480))
                                            }
                                            .onEnded { _ in
                                                isDraggingOutline = false
                                            }
                                    )
                            )
                    }

                    // Column 3: Main Editor Area
                    EditorDetailView()
                }
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                EditorToolbar()
            }


        }
        .background(NotesColors.windowBackground)
        .onChange(of: appState.sidebarVisible) { _, visible in
            columnVisibility = visible ? .all : .detailOnly
        }
    }
}

// MARK: - Editor Detail View
struct EditorDetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Find & Replace Bar
            if appState.findReplaceVisible {
                FindReplaceBar()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Editor
            if appState.selectedFile != nil {
                EditorContainerView()
            } else {
                EmptyEditorView()
            }

            // Status Bar
            StatusBarView()
        }
        .animation(.easeInOut(duration: 0.2), value: appState.findReplaceVisible)
    }
}

// MARK: - Empty State
struct EmptyEditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("没有打开的文件")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("从侧边栏选择文件，或新建一个 Markdown 文档")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    if let node = appState.createNewFile(in: appState.selectedFolder) {
                        appState.openFile(node.url)
                        appState.selectedFile = node
                    }
                } label: {
                    Label("新建文档", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(NotesColors.accent)

                Button {
                    appState.openWelcomeGuide()
                } label: {
                    Label("打开使用说明", systemImage: "book")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotesColors.editorBackground)
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            if let file = appState.selectedFile {
                Label(file.name, systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if appState.isDirty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if appState.wordCount > 0 {
                Text(appState.preferences.language == .english
                     ? "\(appState.wordCount) words · \(appState.charCount) characters"
                     : "\(appState.wordCount) 词 · \(appState.charCount) 字")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if appState.isSourceMode {
                Label("源码", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(NotesColors.statusBarBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Color System
enum NotesColors {
    static let windowBackground = Color(NSColor.windowBackgroundColor)
    static let sidebarBackground = Color(NSColor.controlBackgroundColor)
    static let editorBackground = Color(NSColor.textBackgroundColor)
    static let statusBarBackground = Color(NSColor.windowBackgroundColor).opacity(0.95)
    static let accent = Color(red: 1.0, green: 0.84, blue: 0.0) // Notes yellow
    static let listSelection = Color(NSColor.selectedContentBackgroundColor)
    static let separator = Color(NSColor.separatorColor)
    static let primaryText = Color(NSColor.labelColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
}
