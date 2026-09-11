import SwiftUI

// MARK: - Editor Toolbar (macOS Native Adaptive Style)
struct EditorToolbar: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
        // ── Left: Outline Column Toggle & New Document ──
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

        // ── Center: Document Title + Dirty indicator ──
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                if let file = appState.selectedFile {
                    Text(file.nameWithoutExtension)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 160)
                        .help(file.name)

                    if appState.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .help("未保存修改 (⌘S)")
                    }
                } else {
                    Text("M Notes")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 72, maxWidth: 198, minHeight: 26, maxHeight: 26)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
            .clipped()
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

            // Focus Mode
            Button {
                appState.isFocusMode.toggle()
            } label: {
                Image(systemName: appState.isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .help(appState.isFocusMode ? "退出专注模式" : "专注模式 (⌘⌃F)")

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
    @State private var caseSensitive = false
    @State private var useRegex = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Find field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 11))

                    TextField("查找", text: $appState.findText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($findFocused)
                        .onSubmit { findNext() }
                        .onChange(of: appState.findText) { _, q in
                            NotificationCenter.default.post(name: .editorCommand, object: "find:\(q)")
                        }

                    // Options
                    Toggle(isOn: $caseSensitive) {
                        Text("Aa").font(.system(size: 11, weight: .medium))
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.borderless)
                    .help("区分大小写")

                    Toggle(isOn: $useRegex) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.borderless)
                    .help("正则表达式")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
                .frame(maxWidth: 280)

                HStack(spacing: 2) {
                    Button(action: findPrev) {
                        Image(systemName: "chevron.up").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("上一个 (⇧⏎)")

                    Button(action: findNext) {
                        Image(systemName: "chevron.down").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("下一个 (⏎)")
                }

                Divider().frame(height: 18)

                // Replace field
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 11))
                    TextField("替换", text: $appState.replaceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { replace() }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
                .frame(maxWidth: 200)

                Button("替换", action: replace)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("全部", action: replaceAll)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button {
                    appState.findReplaceVisible = false
                    appState.findText = ""
                } label: {
                    Image(systemName: "xmark").font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)

            Divider()
        }
        .background(Material.bar)
        .onAppear { findFocused = true }
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
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gear") }

            editorTab
                .tabItem { Label("编辑器", systemImage: "pencil") }

            themeTab
                .tabItem { Label("主题", systemImage: "paintpalette") }

            advancedTab
                .tabItem { Label("高级", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 360)
        .padding()
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
            Section {
                Text("语言切换会立即应用，并在下次启动时保留。")
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

            Section("编辑行为") {
                settingsToggle("自动保存", value: $appState.preferences.autoSave)
                settingsToggle("智能引号", value: $appState.preferences.smartQuotes)
                settingsToggle("显示行号", value: $appState.preferences.showLineNumbers)
                settingsToggle("拼写检查", value: $appState.preferences.spellCheck)
            }
        }
        .formStyle(.grouped)
    }

    var themeTab: some View {
        Form {
            Section("内置主题") {
                LabeledContent("主题") {
                    Picker("", selection: $appState.preferences.theme) {
                        ForEach(EditorTheme.allCases, id: \.self) { theme in
                            Text(LocalizedStringKey(theme.displayName)).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            Section("自定义主题") {
                Text("将自定义 CSS 文件放入应用的 Editor/themes/ 目录，重启后生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("打开主题目录") {
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

    private func openThemesFolder() {
        guard let bundleURL = Bundle.main.resourceURL else { return }
        let themesURL = bundleURL.appendingPathComponent("Editor/themes")
        try? FileManager.default.createDirectory(at: themesURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(themesURL)
    }
}
