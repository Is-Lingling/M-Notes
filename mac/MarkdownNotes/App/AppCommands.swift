import SwiftUI
import AppKit

struct AppCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        // MARK: App Info & Updates
        CommandGroup(after: .appInfo) {
            Button(t("检查更新…", "Check for Updates…")) {
                appState.checkForUpdates(manual: true)
            }
        }

        // MARK: File Menu
        CommandGroup(replacing: .newItem) {
            let (newKey, newMods) = sc("newFile", "n", ["command"])
            Button(t("新建", "New")) {
                if let node = appState.createNewFile(in: appState.selectedFolder) {
                    appState.openFile(node.url)
                }
            }
            .keyboardShortcut(newKey, modifiers: newMods)

            let (folderKey, folderMods) = sc("newFolder", "n", ["command", "shift"])
            Button(t("新建文件夹…", "New Folder…")) {
                appState.promptCreateCategory()
            }
            .keyboardShortcut(folderKey, modifiers: folderMods)

            Divider()

            let (openKey, openMods) = sc("openFile", "o", ["command"])
            Button(t("打开文件…", "Open File…")) {
                appState.openFileWithPanel()
            }
            .keyboardShortcut(openKey, modifiers: openMods)

        }

        CommandGroup(replacing: .saveItem) {
            let (saveKey, saveMods) = sc("save", "s", ["command"])
            Button(t("保存", "Save")) {
                appState.saveCurrentFile()
            }
            .keyboardShortcut(saveKey, modifiers: saveMods)

            let (saveAsKey, saveAsMods) = sc("saveAs", "s", ["command", "shift"])
            Button(t("另存为…", "Save As…")) {
                saveAsPanel()
            }
            .keyboardShortcut(saveAsKey, modifiers: saveAsMods)
        }

        // MARK: Edit Menu Additions
        CommandGroup(after: .pasteboard) {
            Divider()
            let (findKey, findMods) = sc("find", "f", ["command"])
            Button(t("查找…", "Find…")) {
                appState.findReplaceVisible.toggle()
            }
            .keyboardShortcut(findKey, modifiers: findMods)

            let (searchAllKey, searchAllMods) = sc("searchAll", "f", ["command", "shift"])
            Button(t("全文搜索…", "Search All Files…")) {
                appState.sidebarVisible = true
                appState.globalSearchVisible = true
            }
            .keyboardShortcut(searchAllKey, modifiers: searchAllMods)

            let (replaceKey, replaceMods) = sc("replace", "h", ["command"])
            Button(t("替换…", "Replace…")) {
                appState.findReplaceVisible = true
                appState.showReplaceInFindBar = true
            }
            .keyboardShortcut(replaceKey, modifiers: replaceMods)
        }

        // MARK: View Menu
        CommandGroup(after: .toolbar) {
            let (sideKey, sideMods) = sc("toggleSidebar", "\\", ["command"])
            Button(appState.sidebarVisible ? t("隐藏侧边栏", "Hide Sidebar") : t("显示侧边栏", "Show Sidebar")) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.sidebarVisible.toggle()
                }
            }
            .keyboardShortcut(sideKey, modifiers: sideMods)

            let (outlineKey, outlineMods) = sc("toggleOutline", "o", ["command", "option"])
            Button(appState.outlinePanelVisible ? t("隐藏大纲", "Hide Outline") : t("显示大纲", "Show Outline")) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.outlinePanelVisible.toggle()
                }
            }
            .keyboardShortcut(outlineKey, modifiers: outlineMods)

            Divider()

            let (sourceKey, sourceMods) = sc("toggleSourceMode", "/", ["command"])
            Button(appState.isSourceMode ? t("退出源码模式", "Exit Source Mode") : t("源码模式", "Source Mode")) {
                appState.isSourceMode.toggle()
            }
            .keyboardShortcut(sourceKey, modifiers: sourceMods)
            .disabled(appState.isPlainText)

            Divider()

            let (twKey, twMods) = sc("toggleTypewriter", "t", ["command", "shift"])
            Button(appState.isTypewriterMode ? t("关闭打字机模式", "Turn Off Typewriter Mode") : t("打字机模式", "Typewriter Mode")) {
                appState.isTypewriterMode.toggle()
            }
            .keyboardShortcut(twKey, modifiers: twMods)
        }

        // MARK: Format Menu
        CommandMenu(t("格式", "Format")) {
            let (bKey, bMods) = sc("bold", "b", ["command"])
            Button(t("加粗", "Bold")) { NotificationCenter.default.post(name: .editorCommand, object: "bold") }
                .keyboardShortcut(bKey, modifiers: bMods)

            let (iKey, iMods) = sc("italic", "i", ["command"])
            Button(t("斜体", "Italic")) { NotificationCenter.default.post(name: .editorCommand, object: "italic") }
                .keyboardShortcut(iKey, modifiers: iMods)

            let (dKey, dMods) = sc("strikethrough", "d", ["command", "shift"])
            Button(t("删除线", "Strikethrough")) { NotificationCenter.default.post(name: .editorCommand, object: "strikethrough") }
                .keyboardShortcut(dKey, modifiers: dMods)

            let (codeKey, codeMods) = sc("inlineCode", "`", ["command"])
            Button(t("行内代码", "Inline Code")) { NotificationCenter.default.post(name: .editorCommand, object: "inlineCode") }
                .keyboardShortcut(codeKey, modifiers: codeMods)

            Divider()

            let (h1Key, h1Mods) = sc("heading1", "1", ["command", "option"])
            Button(t("标题 1", "Heading 1")) { NotificationCenter.default.post(name: .editorCommand, object: "h1") }
                .keyboardShortcut(h1Key, modifiers: h1Mods)

            let (h2Key, h2Mods) = sc("heading2", "2", ["command", "option"])
            Button(t("标题 2", "Heading 2")) { NotificationCenter.default.post(name: .editorCommand, object: "h2") }
                .keyboardShortcut(h2Key, modifiers: h2Mods)

            let (h3Key, h3Mods) = sc("heading3", "3", ["command", "option"])
            Button(t("标题 3", "Heading 3")) { NotificationCenter.default.post(name: .editorCommand, object: "h3") }
                .keyboardShortcut(h3Key, modifiers: h3Mods)

            Divider()

            let (ulKey, ulMods) = sc("unorderedList", "u", ["command", "option"])
            Button(t("无序列表", "Unordered List")) { NotificationCenter.default.post(name: .editorCommand, object: "ul") }
                .keyboardShortcut(ulKey, modifiers: ulMods)

            let (olKey, olMods) = sc("orderedList", "o", ["command", "option"])
            Button(t("有序列表", "Ordered List")) { NotificationCenter.default.post(name: .editorCommand, object: "ol") }
                .keyboardShortcut(olKey, modifiers: olMods)

            let (taskKey, taskMods) = sc("taskList", "t", ["command", "option"])
            Button(t("任务列表", "Task List")) { NotificationCenter.default.post(name: .editorCommand, object: "task") }
                .keyboardShortcut(taskKey, modifiers: taskMods)

            Divider()

            let (tblKey, tblMods) = sc("insertTable", "t", ["command", "control"])
            Button(t("插入表格", "Insert Table")) { NotificationCenter.default.post(name: .editorCommand, object: "table") }
                .keyboardShortcut(tblKey, modifiers: tblMods)

            let (cbKey, cbMods) = sc("insertCodeBlock", "k", ["command", "option"])
            Button(t("插入代码块", "Insert Code Block")) { NotificationCenter.default.post(name: .editorCommand, object: "codeBlock") }
                .keyboardShortcut(cbKey, modifiers: cbMods)

            let (mathKey, mathMods) = sc("insertMath", "m", ["command", "option"])
            Button(t("插入数学公式", "Insert Equation")) { NotificationCenter.default.post(name: .editorCommand, object: "math") }
                .keyboardShortcut(mathKey, modifiers: mathMods)
        }

        // MARK: Export Menu
        CommandMenu(t("导出", "Export")) {
            Button(t("打印为单页 PDF…", "Print as Single-page PDF…")) {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfSingle")
            }
            let (pdfKey, pdfMods) = sc("exportPDF", "e", ["command", "shift"])
            Button(t("打印为分页 PDF…", "Print as Paginated PDF…")) {
                NotificationCenter.default.post(name: .exportCommand, object: "pdfPaginated")
            }
            .keyboardShortcut(pdfKey, modifiers: pdfMods)

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

    private func sc(_ id: String, _ key: String, _ mods: [String]) -> (KeyEquivalent, EventModifiers) {
        let def = appState.shortcut(for: id, defaultKey: key, defaultModifiers: mods)
        return (def.keyEquivalent, def.eventModifiers)
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
        panel.directoryURL = appState.defaultDirectory()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .plainText]
        panel.nameFieldStringValue = appState.selectedFile?.name ?? "Untitled.md"
        if panel.runModal() == .OK, let url = panel.url {
            appState.saveAs(url)
        }
    }
}
