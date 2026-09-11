import SwiftUI
import AppKit

struct AppCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        // MARK: File Menu
        CommandGroup(replacing: .newItem) {
            Button(t("新建", "New")) {
                if let node = appState.createNewFile(in: appState.selectedFolder) {
                    appState.openFile(node.url)
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button(t("打开文件…", "Open File…")) {
                appState.openFileWithPanel()
            }
            .keyboardShortcut("o", modifiers: .command)

        }

        CommandGroup(replacing: .saveItem) {
            Button(t("保存", "Save")) {
                appState.saveCurrentFile()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button(t("另存为…", "Save As…")) {
                saveAsPanel()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        // MARK: Edit Menu Additions
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(t("查找…", "Find…")) {
                appState.findReplaceVisible.toggle()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button(t("全文搜索…", "Search All Files…")) {
                appState.sidebarVisible = true
                appState.globalSearchVisible = true
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button(t("替换…", "Replace…")) {
                appState.findReplaceVisible = true
            }
            .keyboardShortcut("h", modifiers: .command)
        }

        // MARK: View Menu
        CommandGroup(after: .toolbar) {
            Button(appState.sidebarVisible ? t("隐藏侧边栏", "Hide Sidebar") : t("显示侧边栏", "Show Sidebar")) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.sidebarVisible.toggle()
                }
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button(appState.outlinePanelVisible ? t("隐藏大纲", "Hide Outline") : t("显示大纲", "Show Outline")) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.outlinePanelVisible.toggle()
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .option])

            Divider()

            Button(appState.isSourceMode ? t("退出源码模式", "Exit Source Mode") : t("源码模式", "Source Mode")) {
                appState.isSourceMode.toggle()
            }
            .keyboardShortcut("/", modifiers: .command)
            .disabled(appState.isPlainText)

            Divider()

            Button(appState.isFocusMode ? t("退出专注模式", "Exit Focus Mode") : t("专注模式", "Focus Mode")) {
                appState.isFocusMode.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .control])

            Button(appState.isTypewriterMode ? t("关闭打字机模式", "Turn Off Typewriter Mode") : t("打字机模式", "Typewriter Mode")) {
                appState.isTypewriterMode.toggle()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // MARK: Format Menu
        CommandMenu(t("格式", "Format")) {
            Button(t("加粗", "Bold")) { NotificationCenter.default.post(name: .editorCommand, object: "bold") }
                .keyboardShortcut("b", modifiers: .command)
            Button(t("斜体", "Italic")) { NotificationCenter.default.post(name: .editorCommand, object: "italic") }
                .keyboardShortcut("i", modifiers: .command)
            Button(t("删除线", "Strikethrough")) { NotificationCenter.default.post(name: .editorCommand, object: "strikethrough") }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(t("行内代码", "Inline Code")) { NotificationCenter.default.post(name: .editorCommand, object: "inlineCode") }
                .keyboardShortcut("`", modifiers: .command)
            Divider()
            Button(t("标题 1", "Heading 1")) { NotificationCenter.default.post(name: .editorCommand, object: "h1") }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button(t("标题 2", "Heading 2")) { NotificationCenter.default.post(name: .editorCommand, object: "h2") }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button(t("标题 3", "Heading 3")) { NotificationCenter.default.post(name: .editorCommand, object: "h3") }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Divider()
            Button(t("无序列表", "Unordered List")) { NotificationCenter.default.post(name: .editorCommand, object: "ul") }
                .keyboardShortcut("u", modifiers: [.command, .option])
            Button(t("有序列表", "Ordered List")) { NotificationCenter.default.post(name: .editorCommand, object: "ol") }
                .keyboardShortcut("o", modifiers: [.command, .option])
            Button(t("任务列表", "Task List")) { NotificationCenter.default.post(name: .editorCommand, object: "task") }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Divider()
            Button(t("插入表格", "Insert Table")) { NotificationCenter.default.post(name: .editorCommand, object: "table") }
                .keyboardShortcut("t", modifiers: [.command, .control])
            Button(t("插入代码块", "Insert Code Block")) { NotificationCenter.default.post(name: .editorCommand, object: "codeBlock") }
                .keyboardShortcut("k", modifiers: [.command, .option])
            Button(t("插入数学公式", "Insert Equation")) { NotificationCenter.default.post(name: .editorCommand, object: "math") }
                .keyboardShortcut("m", modifiers: [.command, .option])
        }

        // MARK: Export Menu
        CommandMenu(t("导出", "Export")) {
            Button(t("打印为单页 PDF…", "Print as Single-page PDF…")) {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfSingle")
            }
            Button(t("打印为分页 PDF…", "Print as Paginated PDF…")) {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfPaginated")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button(t("导出为 HTML…", "Export as HTML…")) {
                NotificationCenter.default.post(name: .exportCommand, object: "html")
            }

            Button(t("复制为 HTML", "Copy as HTML")) {
                NotificationCenter.default.post(name: .exportCommand, object: "copyHTML")
            }
        }

        CommandGroup(replacing: .help) {
            Button(t("欢迎使用与功能示例", "Guide and Examples")) {
                appState.openWelcomeGuide()
            }
            Divider()
            Link(t("Markdown 语法参考", "Markdown Syntax Reference"), destination: URL(string: "https://typora.io/")!)
        }
    }

    private func t(_ chinese: String, _ english: String) -> String {
        appState.preferences.language == .english ? english : chinese
    }

    // MARK: - Panel Helpers

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.openFolder(url)
        }
    }

    private func saveAsPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .plainText]
        panel.nameFieldStringValue = appState.selectedFile?.name ?? "Untitled.md"
        if panel.runModal() == .OK, let url = panel.url {
            appState.saveAs(url)
        }
    }
}
