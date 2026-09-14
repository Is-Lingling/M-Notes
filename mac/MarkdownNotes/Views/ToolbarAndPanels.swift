import SwiftUI

// MARK: - Editor Toolbar (macOS Native Adaptive Style)
struct EditorToolbar: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
        // ── Left: Outline Column Toggle & New Document & Open File ──
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.outlinePanelVisible.toggle()
                }
            } label: {
                Image(systemName: "list.bullet.indent")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appState.outlinePanelVisible ? NotesColors.accent : .primary)
            }
            .help(appState.outlinePanelVisible ? "隐藏大纲栏 (⌘⌥O)" : "显示大纲栏 (⌘⌥O)")
            .keyboardShortcut("o", modifiers: [.command, .option])

            Button {
                if let newNode = appState.createNewFile(in: appState.selectedFolder) {
                    appState.openFile(newNode.url)
                    appState.selectedFile = newNode
                }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help(appState.preferences.language == .english ? "New Document (⌘N)" : "新建文档 (⌘N)")
            .keyboardShortcut("n", modifiers: [.command])

            Button {
                appState.openFileWithPanel()
            } label: {
                Image(systemName: "folder")
            }
            .help(appState.preferences.language == .english ? "Open File (⌘O)" : "打开文件 (⌘O)")
        }

        // ── Center: Document Title + In-place Inline Renaming + Dirty indicator ──
        ToolbarItem(placement: .principal) {
            DocumentTitleView()
        }

        // ── Right: Adaptive Action Group (ViewThatFits) ──
        ToolbarItemGroup(placement: .primaryAction) {
            ViewThatFits(in: .horizontal) {
                // 1. Full layout (wide windows)
                FullToolbarActions()
                // 2. Compact layout (medium/narrow windows)
                CompactToolbarActions()
            }
        }
    }
}

// MARK: - Full Width Actions
struct FullToolbarActions: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Text formatting group
            NativeFormatGroup()

            // Insert menu (+)
            NativeInsertMenu()

            Divider().frame(height: 16)

            // Mode toggle (Source / Preview)
            Button {
                appState.isSourceMode.toggle()
            } label: {
                Image(systemName: appState.isSourceMode ? "doc.richtext" : "chevron.left.forwardslash.chevron.right")
            }
            .help(appState.isSourceMode ? "切换到所见即所得模式 (⌘/)" : "切换到源码模式 (⌘/)")
            .disabled(appState.isPlainText)

            // Export Menu
            NativeExportMenu()
        }
    }
}

// MARK: - Compact Actions (for narrow windows)
struct CompactToolbarActions: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            // Quick format menu
            Menu {
                Section("常用格式") {
                    Button("加粗 (⌘B)") { NotificationCenter.default.post(name: .editorCommand, object: "bold") }
                    Button("斜体 (⌘I)") { NotificationCenter.default.post(name: .editorCommand, object: "italic") }
                    Button("删除线") { NotificationCenter.default.post(name: .editorCommand, object: "strikethrough") }
                    Button("行内代码") { NotificationCenter.default.post(name: .editorCommand, object: "inlineCode") }
                }
                Section("标题") {
                    Button("正文 (⌘⌥0)") { NotificationCenter.default.post(name: .editorCommand, object: "p") }
                    ForEach(1...6, id: \.self) { l in
                        Button("标题 \(l) (⌘⌥\(l))") { NotificationCenter.default.post(name: .editorCommand, object: "h\(l)") }
                    }
                }
            } label: {
                Image(systemName: "textformat")
            }
            .help("文本格式")

            // Insert menu (+)
            NativeInsertMenu()

            // Mode toggle
            Button {
                appState.isSourceMode.toggle()
            } label: {
                Image(systemName: appState.isSourceMode ? "doc.richtext" : "chevron.left.forwardslash.chevron.right")
            }
            .help(appState.isSourceMode ? "切换到所见即所得模式 (⌘/)" : "切换到源码模式 (⌘/)")
            .disabled(appState.isPlainText)

            // Export Menu
            NativeExportMenu()
        }
    }
}

// MARK: - Native Format Group
struct NativeFormatGroup: View {
    var body: some View {
        HStack(spacing: 2) {
            ToolbarIconButton(icon: "bold", command: "bold", tooltip: "加粗 ⌘B")
            ToolbarIconButton(icon: "italic", command: "italic", tooltip: "斜体 ⌘I")
            ToolbarIconButton(icon: "strikethrough", command: "strikethrough", tooltip: "删除线")
            ToolbarIconButton(icon: "chevron.left.slash.chevron.right", command: "inlineCode", tooltip: "行内代码")
            HeadingMenuButton()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .fixedSize()
    }
}

// MARK: - Native Insert Menu
struct NativeInsertMenu: View {
    var body: some View {
        Menu {
            Section("列表") {
                FormatMenuItem(label: "无序列表", icon: "list.bullet", command: "ul")
                FormatMenuItem(label: "有序列表", icon: "list.number", command: "ol")
                FormatMenuItem(label: "任务列表", icon: "checklist", command: "task")
            }
            Section("块元素") {
                FormatMenuItem(label: "引用块", icon: "text.quote", command: "quote")
                FormatMenuItem(label: "代码块", icon: "terminal", command: "codeBlock")
                FormatMenuItem(label: "数学公式", icon: "function", command: "math")
                FormatMenuItem(label: "分割线", icon: "minus", command: "hr")
            }
            Section("丰富内容") {
                FormatMenuItem(label: "表格", icon: "tablecells", command: "table")
                FormatMenuItem(label: "链接", icon: "link", command: "link")
                FormatMenuItem(label: "图片", icon: "photo", command: "image")
                FormatMenuItem(label: "Mermaid 图表", icon: "flowchart", command: "mermaid")
            }
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.borderlessButton)
        .help("插入元素")
    }
}

// MARK: - Native Export Menu
struct NativeExportMenu: View {
    var body: some View {
        Menu {
            Button {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfSingle")
            } label: {
                Label("打印为单页 PDF", systemImage: "doc.text.image")
            }
            Button {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfPaginated")
            } label: {
                Label("打印为分页 PDF", systemImage: "doc.on.doc")
            }
            Button {
                NotificationCenter.default.post(name: .exportCommand, object: "html")
            } label: {
                Label("导出为 HTML", systemImage: "globe")
            }
            Divider()
            Button {
                NotificationCenter.default.post(name: .exportCommand, object: "copyHTML")
            } label: {
                Label("复制为 HTML", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .help("导出")
    }
}

// MARK: - Reusable Components

struct ToolbarIconButton: View {
    let icon: String
    let command: String
    let tooltip: String
    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .editorCommand, object: command)
        } label: {
            Image(systemName: icon)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .foregroundStyle(.primary)
        .background(isHovered ? Color(NSColor.selectedControlColor).opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { isHovered = $0 }
    }
}

struct HeadingMenuButton: View {
    var body: some View {
        Menu {
            Button("正文 (⌘⌥0)") {
                NotificationCenter.default.post(name: .editorCommand, object: "p")
            }
            Divider()
            ForEach(1...6, id: \.self) { level in
                Button("标题 \(level)  (⌘⌥\(level))") {
                    NotificationCenter.default.post(name: .editorCommand, object: "h\(level)")
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text("H")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

            }
            .frame(width: 30, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("标题样式")
    }
}

struct FormatMenuItem: View {
    let label: String
    let icon: String
    let command: String

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .editorCommand, object: command)
        } label: {
            Label(label, systemImage: icon)
        }
    }
}

// MARK: - Find & Replace Bar
struct FindReplaceBar: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var findFocused: Bool
    @FocusState private var replaceFocused: Bool
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var isCloseHovered = false

    var body: some View {
        VStack(spacing: 8) {
            // Find Row
            HStack(spacing: 6) {
                // Expand / Collapse Replace Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.showReplaceInFindBar.toggle()
                    }
                } label: {
                    Image(systemName: appState.showReplaceInFindBar ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(appState.preferences.language == .english ? "Toggle Replace (⌘H)" : "切换替换面板 (⌘H)")

                // Search Input Box
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField(appState.preferences.language == .english ? "Find" : "查找", text: $appState.findText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .focused($findFocused)
                        .onSubmit { findNext() }
                        .onChange(of: appState.findText) { _, _ in updateSearch() }

                    if !appState.findText.isEmpty {
                        Button {
                            appState.findText = ""
                            updateSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Aa & .* pill toggles
                    HStack(spacing: 2) {
                        Button {
                            caseSensitive.toggle()
                            updateSearch()
                        } label: {
                            Text("Aa")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(caseSensitive ? NotesColors.accent : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(caseSensitive ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(appState.preferences.language == .english ? "Match Case" : "区分大小写")

                        Button {
                            useRegex.toggle()
                            updateSearch()
                        } label: {
                            Text(".*")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(useRegex ? NotesColors.accent : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(useRegex ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(appState.preferences.language == .english ? "Regular Expression" : "正则表达式")
                    }
                    .padding(1)
                    .background(Color(NSColor.separatorColor).opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.8))

                // Navigation (Previous / Next)
                HStack(spacing: 2) {
                    Button(action: findPrev) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(appState.preferences.language == .english ? "Previous Match (⇧⏎)" : "上一个匹配项 (⇧⏎)")

                    Button(action: findNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(appState.preferences.language == .english ? "Next Match (⏎)" : "下一个匹配项 (⏎)")
                }

                // Close Button
                Button(action: closeFindBar) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(isCloseHovered ? Color.primary.opacity(0.08) : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovered = $0 }
                .help(appState.preferences.language == .english ? "Close (Esc)" : "关闭 (Esc)")
            }

            // Replace Row
            if appState.showReplaceInFindBar {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 18, height: 18)

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField(appState.preferences.language == .english ? "Replace" : "替换", text: $appState.replaceText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .focused($replaceFocused)
                            .onSubmit { replace() }

                        if !appState.replaceText.isEmpty {
                            Button {
                                appState.replaceText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.8))

                    Button(appState.preferences.language == .english ? "Replace" : "替换", action: replace)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button(appState.preferences.language == .english ? "All" : "全部", action: replaceAll)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(9)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            findFocused = true
            updateSearch()
        }
        .background {
            Button("") { closeFindBar() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        }
    }

    private func updateSearch() {
        if appState.findText.isEmpty {
            NotificationCenter.default.post(name: .editorCommand, object: "find:")
        } else {
            NotificationCenter.default.post(name: .editorCommand,
                                            object: "findWithOptions:\(appState.findText):\(caseSensitive):\(useRegex)")
        }
    }

    private func findNext() {
        NotificationCenter.default.post(name: .editorCommand, object: "findNext")
    }

    private func findPrev() {
        NotificationCenter.default.post(name: .editorCommand, object: "findPrev")
    }

    private func replace() {
        NotificationCenter.default.post(name: .editorCommand,
                                        object: "replace:\(appState.findText):\(appState.replaceText)")
    }

    private func replaceAll() {
        NotificationCenter.default.post(name: .editorCommand,
                                        object: "replaceAll:\(appState.findText):\(appState.replaceText)")
    }

    private func closeFindBar() {
        appState.findReplaceVisible = false
        NotificationCenter.default.post(name: .editorCommand, object: "find:")
    }
}

// MARK: - Document Title View (with In-place Inline Renaming)
struct DocumentTitleView: View {
    @EnvironmentObject var appState: AppState
    @State private var isEditing: Bool = false
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var isEnglish: Bool {
        appState.preferences.language == .english
    }

    var body: some View {
        HStack(spacing: 6) {
            if let file = appState.selectedFile {
                if isEditing {
                    TextField("", text: $text)
                        .font(.system(size: 13, weight: .semibold))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .frame(minWidth: 80, maxWidth: 220)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused && isEditing {
                                commitRename()
                            }
                        }
                } else {
                    Text(file.nameWithoutExtension)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 180)

                    if appState.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .help(isEnglish ? "Unsaved changes (⌘S)" : "未保存修改 (⌘S)")
                    }
                }
            } else {
                Text("M Notes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, isEditing ? 8 : 10)
        .frame(minWidth: 72, maxWidth: isEditing ? 240 : 210, minHeight: 26, maxHeight: 26)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isEditing ? Color(NSColor.textBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isEditing ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture(count: 2) {
            startEditing()
        }
        .help(helpText)
    }

    private var helpText: String {
        if isEditing {
            return isEnglish ? "Press Enter to save, Esc to cancel" : "按回车键保存，Esc 取消"
        }
        if let file = appState.selectedFile {
            return file.name + (isEnglish ? " (Double-click to rename)" : " (双击直接修改文件名)")
        }
        return "M Notes"
    }

    private func startEditing() {
        guard let file = appState.selectedFile else { return }
        text = file.nameWithoutExtension
        isEditing = true
        DispatchQueue.main.async {
            isFocused = true
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        isEditing = false
        guard let file = appState.selectedFile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != file.nameWithoutExtension {
            appState.renameFile(file.url, newName: trimmed)
        }
    }

    private func cancelRename() {
        isEditing = false
        if let file = appState.selectedFile {
            text = file.nameWithoutExtension
        }
    }
}

// MARK: - Outline Panel
struct OutlinePanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("大纲")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appState.outlinePanelVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(appState.outlineItems) { item in
                        OutlineItemRow(item: item)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OutlineItemRow: View {
    let item: OutlineItem
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .editorCommand,
                                            object: "scrollToHeading:\(item.id)")
        } label: {
            HStack(spacing: 0) {
                // Indent
                Color.clear.frame(width: CGFloat(max(0, item.level - 1)) * 14 + 12)

                // Level indicator dot for H2+
                if item.level > 1 {
                    Circle()
                        .fill(Color(NSColor.tertiaryLabelColor))
                        .frame(width: 3, height: 3)
                        .padding(.trailing, 5)
                }

                Text(item.text)
                    .font(.system(size: 12 + max(0.0, CGFloat(4 - item.level))))
                    .fontWeight(item.level == 1 ? .semibold : .regular)
                    .foregroundStyle(item.level <= 2 ? Color.primary : Color.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color(NSColor.selectedControlColor).opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedPreferencesTab) {
            generalTab
                .tabItem { Label(appState.preferences.language == .english ? "General" : "通用", systemImage: "gear") }
                .tag("general")

            editorTab
                .tabItem { Label(appState.preferences.language == .english ? "Editor" : "编辑器", systemImage: "pencil") }
                .tag("editor")

            shortcutsTab
                .tabItem { Label(appState.preferences.language == .english ? "Shortcuts" : "快捷键", systemImage: "keyboard") }
                .tag("shortcuts")

            themeTab
                .tabItem { Label(appState.preferences.language == .english ? "Theme" : "主题", systemImage: "paintpalette") }
                .tag("theme")

            advancedTab
                .tabItem { Label(appState.preferences.language == .english ? "Advanced" : "高级", systemImage: "gearshape") }
                .tag("advanced")

            aboutTab
                .tabItem { Label(appState.preferences.language == .english ? "About" : "关于", systemImage: "info.circle") }
                .tag("about")
        }
        .frame(width: 580, height: 520)
        .padding()
        .sheet(isPresented: $appState.updateChecker.isShowingReleaseNotes) {
            if let release = appState.updateChecker.selectedReleaseForNotes {
                ReleaseNotesSheet(release: release)
                    .environmentObject(appState)
            }
        }
    }

    var generalTab: some View {
        Form {
            Section("语言") {
                LabeledContent("软件语言") {
                    Picker("", selection: $appState.preferences.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            Section("默认保存路径") {
                LabeledContent("保存目录") {
                    HStack(spacing: 8) {
                        Text(appState.preferences.defaultSaveLocation.isEmpty
                             ? (appState.preferences.language == .english ? "Default (Documents)" : "默认（文稿）")
                             : appState.preferences.defaultSaveLocation)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.system(size: 12))
                            .foregroundStyle(appState.preferences.defaultSaveLocation.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: 180, alignment: .leading)
                            .help(appState.preferences.defaultSaveLocation.isEmpty
                                  ? (appState.preferences.language == .english ? "Documents directory" : "系统“文稿”目录")
                                  : appState.preferences.defaultSaveLocation)

                        Button(appState.preferences.language == .english ? "Choose…" : "选取…") {
                            chooseDefaultSaveLocation()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if !appState.preferences.defaultSaveLocation.isEmpty {
                            Button {
                                appState.preferences.defaultSaveLocation = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help(appState.preferences.language == .english ? "Reset to Default" : "恢复默认")
                        }
                    }
                }
            }

            Section {
                Text(appState.preferences.language == .english
                     ? "New documents will be saved to this folder by default."
                     : "新建文档将默认保存在此文件夹中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    var editorTab: some View {
        Form {
            Section("字体与排版") {
                LabeledContent("字号") {
                    HStack {
                        Slider(value: $appState.preferences.editorFontSize, in: 12...28, step: 1)
                        Text("\(Int(appState.preferences.editorFontSize)) px")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }.frame(width: 260)
                }
                LabeledContent("行高") {
                    HStack {
                        Slider(value: $appState.preferences.lineHeight, in: 1.2...2.5, step: 0.1)
                        Text(String(format: "%.1f", appState.preferences.lineHeight))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }.frame(width: 260)
                }
                LabeledContent("最大宽度") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(appState.preferences.maxWidth) },
                            set: { appState.preferences.maxWidth = Int($0) }
                        ), in: 520...1200, step: 20)
                        Text("\(appState.preferences.maxWidth) px")
                            .monospacedDigit()
                            .frame(width: 58, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }.frame(width: 260)
                }
            }

            Section(appState.preferences.language == .english ? "Layout & Scrolling" : "排版与滚动") {
                LabeledContent(appState.preferences.language == .english ? "Bottom Blank Area" : "页面末尾空白区") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(appState.preferences.bottomPadding) },
                            set: { appState.preferences.bottomPadding = Int($0) }
                        ), in: 0...60, step: 5)
                        Text("\(appState.preferences.bottomPadding)%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }.frame(width: 260)
                }
                Text(appState.preferences.language == .english
                     ? "Maintains a blank area at the bottom for comfortable editing (excluded when printing)."
                     : "尽量保证页面末尾空白区，无需每次滚动页面调整编辑位置（打印时不保留）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("编辑行为") {
                settingsToggle("自动保存", value: $appState.preferences.autoSave)
                settingsToggle("智能引号", value: $appState.preferences.smartQuotes)
                settingsToggle("显示行号", value: $appState.preferences.showLineNumbers)
                settingsToggle("拼写检查", value: $appState.preferences.spellCheck)
            }
        }
        .formStyle(.grouped)
    }

    var shortcutsTab: some View {
        ShortcutsPreferencesTab()
    }

    var themeTab: some View {
        Form {
            Section(appState.preferences.language == .english ? "Appearance & Theme" : "外观模式与主题") {
                LabeledContent(appState.preferences.language == .english ? "Theme Mode" : "主题模式") {
                    Picker("", selection: $appState.preferences.theme) {
                        ForEach(EditorTheme.allCases, id: \.self) { theme in
                            Text(LocalizedStringKey(theme.displayName)).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                if appState.preferences.theme == .system {
                    LabeledContent(appState.preferences.language == .english ? "System Light Theme" : "跟随系统的浅色主题") {
                        Picker("", selection: $appState.preferences.systemLightTheme) {
                            ForEach(EditorTheme.lightThemes, id: \.self) { theme in
                                Text(LocalizedStringKey(theme.displayName)).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    LabeledContent(appState.preferences.language == .english ? "System Dark Theme" : "跟随系统的深色主题") {
                        Picker("", selection: $appState.preferences.systemDarkTheme) {
                            ForEach(EditorTheme.darkThemes, id: \.self) { theme in
                                Text(LocalizedStringKey(theme.displayName)).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    Text(appState.preferences.language == .english
                         ? "When system appearance is light or dark, M Notes will automatically switch to the matched theme."
                         : "当 macOS 系统切换为浅色或深色模式时，M Notes 将自动无缝切换至对应的浅色/深色主题。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(appState.preferences.language == .english ? "Custom Theme" : "自定义主题") {
                Text(appState.preferences.language == .english
                     ? "Put custom CSS files into Editor/themes/ directory and restart the app."
                     : "将自定义 CSS 文件放入应用的 Editor/themes/ 目录，重启后生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(appState.preferences.language == .english ? "Open Themes Folder" : "打开主题目录") {
                    openThemesFolder()
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    var advancedTab: some View {
        Form {
            Section("图片") {
                LabeledContent("拖放图片处理") {
                    Picker("", selection: $appState.preferences.imagePasteMode) {
                        Text("复制到 assets/ 目录").tag(ImagePasteMode.copyToAssets)
                        Text("保持原始路径").tag(ImagePasteMode.keepOriginal)
                        Text("嵌入 Base64（不推荐）").tag(ImagePasteMode.base64)
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            Section("文件监视") {
                settingsToggle("自动检测外部修改", value: $appState.preferences.watchFileChanges)
                    .help("当文件被其他程序修改时自动刷新")
            }
        }
        .formStyle(.grouped)
    }

    private func settingsToggle(_ title: LocalizedStringKey, value: Binding<Bool>) -> some View {
        LabeledContent(title) {
            Toggle("", isOn: value)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func chooseDefaultSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let isEnglish = appState.preferences.language == .english
        panel.prompt = isEnglish ? "Select" : "选取"
        panel.message = isEnglish ? "Choose default save folder" : "选择新建文档的默认保存路径"
        if panel.runModal() == .OK, let url = panel.url {
            appState.preferences.defaultSaveLocation = url.path
        }
    }

    private func openThemesFolder() {
        guard let bundleURL = Bundle.main.resourceURL else { return }
        let themesURL = bundleURL.appendingPathComponent("Editor/themes")
        try? FileManager.default.createDirectory(at: themesURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(themesURL)
    }

    var aboutTab: some View {
        AboutPreferencesTab()
    }
}

// MARK: - About Preferences Tab
struct AboutPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var updateChecker = UpdateChecker.shared

    var isEnglish: Bool {
        appState.preferences.language == .english
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // App Branding Header
                VStack(spacing: 8) {
                    if let icon = NSApplication.shared.applicationIconImage ?? NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 68, height: 68)
                            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                    } else {
                        Image(systemName: "note.text")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                    }

                    Text("M Notes")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text(isEnglish ? "Modern WYSIWYG Markdown & Plain Text Editor" : "现代化 macOS 所见即所得 Markdown 与纯文本编辑器")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Text(isEnglish ? "Version" : "版本")
                            .foregroundStyle(.secondary)
                        Text(updateChecker.currentVersionDisplay)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5), in: Capsule())
                }
                .padding(.top, 4)

                Divider()

                // Update Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(isEnglish ? "Software Update" : "软件更新", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        Spacer()
                        if updateChecker.state == .checking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    // Status Details
                    switch updateChecker.state {
                    case .idle:
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                            Text(isEnglish ? "Check GitHub for the latest releases and improvement notes." : "从 GitHub 检测最新版本与更新说明。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(isEnglish ? "Check for Updates" : "检查更新") {
                                updateChecker.checkForUpdates(manual: true)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    case .checking:
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text(isEnglish ? "Connecting to GitHub to check for updates…" : "正在连接 GitHub 检查新版本…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    case .upToDate(let release):
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isEnglish ? "M Notes is up to date" : "当前已是最新版本")
                                        .font(.headline)
                                    Text(isEnglish ? "Latest release: \(release.tagName)" : "最新版本：\(release.tagName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(isEnglish ? "Check Again" : "重新检查") {
                                    updateChecker.checkForUpdates(manual: true)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Divider()
                                HStack {
                                    Text(isEnglish ? "Release Notes for \(release.tagName):" : "当前版本改进说明：")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        updateChecker.showReleaseNotes(for: release)
                                    } label: {
                                        Label(isEnglish ? "View Release Notes" : "查看改进说明", systemImage: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    case .updateAvailable(let release):
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(isEnglish ? "New Version Available!" : "发现新版本！")
                                            .font(.headline)
                                        Text(release.tagName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                    if !release.formattedDate.isEmpty {
                                        Text(isEnglish ? "Released: \(release.formattedDate)" : "发布时间：\(release.formattedDate)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }

                            if let asset = release.downloadAsset {
                                HStack(spacing: 4) {
                                    Image(systemName: "shippingbox")
                                        .foregroundStyle(.secondary)
                                    Text(asset.name)
                                        .font(.caption)
                                        .monospaced()
                                    Text("(\(asset.formattedSize))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 10) {
                                Button {
                                    updateChecker.showReleaseNotes(for: release)
                                } label: {
                                    Label(isEnglish ? "View Release Notes" : "查看改进说明", systemImage: "doc.text.magnifyingglass")
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button {
                                    updateChecker.openDownloadPage(for: release)
                                } label: {
                                    Label(isEnglish ? "Download Update" : "立即下载更新", systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(14)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )

                    case .failed(let error):
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isEnglish ? "Update Check Failed" : "检查更新失败")
                                    .font(.headline)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(isEnglish ? "Retry" : "重试") {
                                updateChecker.checkForUpdates(manual: true)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Auto check toggle
                    Toggle(isEnglish ? "Automatically check for updates on startup" : "启动时自动检查更新", isOn: $appState.preferences.autoCheckForUpdates)
                        .font(.callout)

                    if let lastChecked = updateChecker.lastCheckedDate {
                        Text(isEnglish
                             ? "Last checked: \(lastChecked.formatted(date: .abbreviated, time: .shortened))"
                             : "上次检查时间：\(lastChecked.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 4)

                Divider()

                // Links & Copyright Footer
                HStack(spacing: 16) {
                    Link(destination: URL(string: UpdateChecker.repoURLString)!) {
                        Label("GitHub", systemImage: "link")
                            .font(.caption)
                    }

                    Link(destination: URL(string: "\(UpdateChecker.repoURLString)/releases")!) {
                        Label(isEnglish ? "All Releases" : "所有版本历史", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                    }

                    Spacer()

                    Text("© 2026 M Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Release Notes Sheet
struct ReleaseNotesSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let release: GitHubRelease

    var isEnglish: Bool {
        appState.preferences.language == .english
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(release.displayTitle)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(release.tagName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)

                        if !release.formattedDate.isEmpty {
                            Text(isEnglish ? "Published: \(release.formattedDate)" : "发布于：\(release.formattedDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(LocalizedStringKey(body))
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(isEnglish ? "No release notes provided for this version." : "该版本暂无详细改进说明。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Footer actions
            HStack {
                if let asset = release.downloadAsset {
                    Label("\(asset.name) (\(asset.formattedSize))", systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(isEnglish ? "View on GitHub" : "在 GitHub 打开") {
                    if let url = URL(string: release.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    UpdateChecker.shared.openDownloadPage(for: release)
                } label: {
                    Label(isEnglish ? "Download Update" : "下载更新包", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(isEnglish ? "Done" : "完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 580, height: 480)
    }
}

// MARK: - Shortcuts Preferences Tab
struct ShortcutItemConfig: Identifiable {
    let id: String
    let categoryZh: String
    let categoryEn: String
    let nameZh: String
    let nameEn: String
    let defaultKey: String
    let defaultModifiers: [String]
}

let allShortcutConfigs: [ShortcutItemConfig] = [
    // File
    ShortcutItemConfig(id: "newFile", categoryZh: "文件", categoryEn: "File", nameZh: "新建文档", nameEn: "New Document", defaultKey: "n", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "newFolder", categoryZh: "文件", categoryEn: "File", nameZh: "新建文件夹", nameEn: "New Folder", defaultKey: "n", defaultModifiers: ["command", "shift"]),
    ShortcutItemConfig(id: "openFile", categoryZh: "文件", categoryEn: "File", nameZh: "打开文件", nameEn: "Open File", defaultKey: "o", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "save", categoryZh: "文件", categoryEn: "File", nameZh: "保存", nameEn: "Save", defaultKey: "s", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "saveAs", categoryZh: "文件", categoryEn: "File", nameZh: "另存为", nameEn: "Save As", defaultKey: "s", defaultModifiers: ["command", "shift"]),

    // Edit & Search
    ShortcutItemConfig(id: "find", categoryZh: "编辑与搜索", categoryEn: "Edit & Search", nameZh: "查找", nameEn: "Find", defaultKey: "f", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "searchAll", categoryZh: "编辑与搜索", categoryEn: "Edit & Search", nameZh: "全文搜索", nameEn: "Search All Files", defaultKey: "f", defaultModifiers: ["command", "shift"]),
    ShortcutItemConfig(id: "replace", categoryZh: "编辑与搜索", categoryEn: "Edit & Search", nameZh: "替换", nameEn: "Replace", defaultKey: "h", defaultModifiers: ["command"]),

    // View
    ShortcutItemConfig(id: "toggleSidebar", categoryZh: "视图", categoryEn: "View", nameZh: "显示/隐藏侧边栏", nameEn: "Toggle Sidebar", defaultKey: "\\", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "toggleOutline", categoryZh: "视图", categoryEn: "View", nameZh: "显示/隐藏大纲栏", nameEn: "Toggle Outline", defaultKey: "o", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "toggleSourceMode", categoryZh: "视图", categoryEn: "View", nameZh: "切换源码模式", nameEn: "Toggle Source Mode", defaultKey: "/", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "toggleTypewriter", categoryZh: "视图", categoryEn: "View", nameZh: "切换打字机模式", nameEn: "Toggle Typewriter Mode", defaultKey: "t", defaultModifiers: ["command", "shift"]),

    // Format
    ShortcutItemConfig(id: "bold", categoryZh: "格式", categoryEn: "Format", nameZh: "加粗", nameEn: "Bold", defaultKey: "b", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "italic", categoryZh: "格式", categoryEn: "Format", nameZh: "斜体", nameEn: "Italic", defaultKey: "i", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "strikethrough", categoryZh: "格式", categoryEn: "Format", nameZh: "删除线", nameEn: "Strikethrough", defaultKey: "d", defaultModifiers: ["command", "shift"]),
    ShortcutItemConfig(id: "inlineCode", categoryZh: "格式", categoryEn: "Format", nameZh: "行内代码", nameEn: "Inline Code", defaultKey: "`", defaultModifiers: ["command"]),
    ShortcutItemConfig(id: "heading1", categoryZh: "格式", categoryEn: "Format", nameZh: "标题 1", nameEn: "Heading 1", defaultKey: "1", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "heading2", categoryZh: "格式", categoryEn: "Format", nameZh: "标题 2", nameEn: "Heading 2", defaultKey: "2", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "heading3", categoryZh: "格式", categoryEn: "Format", nameZh: "标题 3", nameEn: "Heading 3", defaultKey: "3", defaultModifiers: ["command", "option"]),

    // Insert & Export
    ShortcutItemConfig(id: "unorderedList", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "无序列表", nameEn: "Unordered List", defaultKey: "u", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "orderedList", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "有序列表", nameEn: "Ordered List", defaultKey: "o", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "taskList", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "任务列表", nameEn: "Task List", defaultKey: "t", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "insertTable", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "插入表格", nameEn: "Insert Table", defaultKey: "t", defaultModifiers: ["command", "control"]),
    ShortcutItemConfig(id: "insertCodeBlock", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "插入代码块", nameEn: "Insert Code Block", defaultKey: "k", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "insertMath", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "插入数学公式", nameEn: "Insert Equation", defaultKey: "m", defaultModifiers: ["command", "option"]),
    ShortcutItemConfig(id: "exportPDF", categoryZh: "插入与导出", categoryEn: "Insert & Export", nameZh: "打印为分页 PDF", nameEn: "Print as Paginated PDF", defaultKey: "e", defaultModifiers: ["command", "shift"])
]

struct ShortcutsPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var recordingId: String? = nil
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var eventMonitor: Any? = nil

    var isEnglish: Bool { appState.preferences.language == .english }

    var categories: [String] {
        isEnglish ? ["All", "File", "Edit & Search", "View", "Format", "Insert & Export"]
                  : ["全部", "文件", "编辑与搜索", "视图", "格式", "插入与导出"]
    }

    var filteredShortcuts: [ShortcutItemConfig] {
        allShortcutConfigs.filter { item in
            // Category filter
            if selectedCategory != "All" && selectedCategory != "全部" {
                if isEnglish {
                    if item.categoryEn != selectedCategory { return false }
                } else {
                    if item.categoryZh != selectedCategory { return false }
                }
            }
            // Search filter
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let name = isEnglish ? item.nameEn.lowercased() : item.nameZh.lowercased()
                let def = appState.shortcut(for: item.id, defaultKey: item.defaultKey, defaultModifiers: item.defaultModifiers)
                let display = def.displayString.lowercased()
                return name.contains(query) || display.contains(query)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Search & Category Filter
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    TextField(isEnglish ? "Search shortcuts…" : "搜索快捷键…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.8))

                Picker("", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Shortcuts List
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(filteredShortcuts) { item in
                        let isCustom = appState.preferences.customShortcuts[item.id] != nil
                        let currentDef = appState.shortcut(for: item.id, defaultKey: item.defaultKey, defaultModifiers: item.defaultModifiers)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isEnglish ? item.nameEn : item.nameZh)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(isEnglish ? item.categoryEn : item.categoryZh)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if isCustom {
                                Button {
                                    appState.resetShortcut(id: item.id)
                                } label: {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .help(isEnglish ? "Reset to Default" : "恢复默认")
                            }

                            ShortcutKeycapButton(
                                displayString: currentDef.displayString,
                                isRecording: recordingId == item.id,
                                isCustomized: isCustom,
                                isEnglish: isEnglish,
                                onTap: {
                                    if recordingId == item.id {
                                        stopRecording()
                                    } else {
                                        startRecording(for: item.id)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Text(recordingId != nil
                     ? (isEnglish ? "Recording… Press key combination, Esc to cancel, Delete to reset."
                                  : "录制中… 请在键盘上按下新组合键，按 Esc 取消，按 Delete 恢复默认。")
                     : (isEnglish ? "Click a shortcut badge to record new keys."
                                  : "点击任意快捷键卡片即可直接按下新快捷键录制。"))
                    .font(.system(size: 11))
                    .foregroundStyle(recordingId != nil ? NotesColors.accent : .secondary)

                Spacer()

                if !appState.preferences.customShortcuts.isEmpty {
                    Button(isEnglish ? "Reset All to Defaults" : "恢复全部默认") {
                        appState.resetAllShortcuts()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 2)
        }
        .padding(12)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording(for id: String) {
        stopRecording()
        recordingId = id
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            // Delete / Backspace resets
            if event.keyCode == 51 {
                appState.resetShortcut(id: id)
                stopRecording()
                return nil
            }

            var mods: [String] = []
            if event.modifierFlags.contains(.control) { mods.append("control") }
            if event.modifierFlags.contains(.option) { mods.append("option") }
            if event.modifierFlags.contains(.shift) { mods.append("shift") }
            if event.modifierFlags.contains(.command) { mods.append("command") }

            let hasModifier = mods.contains("command") || mods.contains("option") || mods.contains("control")
            if hasModifier, let chars = event.charactersIgnoringModifiers, let firstChar = chars.first {
                let key = String(firstChar).lowercased()
                appState.setShortcut(id: id, key: key, modifiers: mods)
                stopRecording()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let em = eventMonitor {
            NSEvent.removeMonitor(em)
            eventMonitor = nil
        }
        recordingId = nil
    }
}

struct ShortcutKeycapButton: View {
    let displayString: String
    let isRecording: Bool
    let isCustomized: Bool
    let isEnglish: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isRecording {
                    ProgressView()
                        .controlSize(.mini)
                    Text(isEnglish ? "Press keys…" : "按下按键…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotesColors.accent)
                } else {
                    Text(displayString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isCustomized ? NotesColors.accent : .primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? NotesColors.accent.opacity(0.12) : Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? NotesColors.accent : Color(NSColor.separatorColor).opacity(0.6), lineWidth: isRecording ? 1.5 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
