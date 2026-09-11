import SwiftUI

// MARK: - Outline Column View (中间大纲专属栏)
struct OutlineColumnView: View {
    @EnvironmentObject var appState: AppState
    @State private var filterText = ""
    @State private var hoveredItemId: String? = nil

    var filteredItems: [OutlineItem] {
        if filterText.isEmpty {
            return appState.outlineItems
        } else {
            return appState.outlineItems.filter {
                $0.text.localizedCaseInsensitiveContains(filterText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("大纲")
                    .font(.headline)
                    .lineLimit(1)

                if !appState.outlineItems.isEmpty {
                    Text("\(appState.outlineItems.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color(NSColor.tertiaryLabelColor).opacity(0.18))
                        .clipShape(Capsule())
                }

                Spacer()

                // Collapse outline column
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.outlinePanelVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("隐藏大纲栏 (⌘⌥O)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Filter box (only when headings > 4)
            if appState.outlineItems.count > 4 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("筛选大纲…", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !filterText.isEmpty {
                        Button { filterText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()
            }

            // Outline Content
            if appState.selectedFile == nil {
                noDocumentState
            } else if appState.outlineItems.isEmpty {
                emptyOutlineState
            } else if filteredItems.isEmpty {
                noMatchState
            } else {
                outlineListView
            }

            Spacer(minLength: 0)

            // Bottom stats bar
            if appState.selectedFile != nil && !appState.outlineItems.isEmpty {
                Divider()
                HStack {
                    Text(appState.preferences.language == .english
                         ? "\(appState.outlineItems.count) sections"
                         : "\(appState.outlineItems.count) 个章节")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if appState.wordCount > 0 {
                        Text(appState.preferences.language == .english
                             ? "\(appState.wordCount) words"
                             : "\(appState.wordCount) 词")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    // MARK: List View
    var outlineListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredItems) { item in
                        OutlineRow(item: item, isHovered: hoveredItemId == item.id)
                            .id(item.id)
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? item.id : nil
                            }
                            .onTapGesture {
                                jumpToHeading(item)
                            }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
            }
        }
    }

    private func jumpToHeading(_ item: OutlineItem) {
        NotificationCenter.default.post(
            name: .editorCommand,
            object: "scrollToHeading:\(item.id)"
        )
        // Also ensure editor is scrolled to line
        NotificationCenter.default.post(
            name: .editorCommand,
            object: "gotoLine:\(item.lineNumber + 1)"
        )
    }

    // MARK: Placeholder states
    var noDocumentState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("未选择文档")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("在左侧侧边栏中选择或新建文档")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyOutlineState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("暂无大纲")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("在正文中使用 # 标记（如 # 标题）\n即可自动生成大纲目录")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var noMatchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
            Text("未找到相关章节")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Outline Row
struct OutlineRow: View {
    let item: OutlineItem
    let isHovered: Bool

    var indentWidth: CGFloat {
        CGFloat(max(0, item.level - 1)) * 12
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Indentation
            if indentWidth > 0 {
                Spacer().frame(width: indentWidth)
            }

            // Bullet or level badge
            levelIndicator

            // Heading title
            Text(item.text)
                .font(fontForLevel(item.level))
                .foregroundStyle(item.level <= 2 ? Color.primary : Color.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Line number hint on hover
            if isHovered {
                Text("L\(item.lineNumber + 1)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, item.level == 1 ? 5 : 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedControlColor).opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    var levelIndicator: some View {
        switch item.level {
        case 1:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(NotesColors.accent)
                .frame(width: 3.5, height: 13)
        case 2:
            Circle()
                .fill(Color.secondary.opacity(0.8))
                .frame(width: 4, height: 4)
        case 3:
            Circle()
                .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1)
                .frame(width: 4, height: 4)
        default:
            Circle()
                .fill(Color(NSColor.tertiaryLabelColor).opacity(0.5))
                .frame(width: 3, height: 3)
        }
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 13, weight: .semibold)
        case 2:
            return .system(size: 12.5, weight: .medium)
        case 3:
            return .system(size: 12, weight: .regular)
        default:
            return .system(size: 11.5, weight: .regular)
        }
    }
}
