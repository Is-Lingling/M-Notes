import SwiftUI

@main
struct MarkdownNotesApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.locale, appState.preferences.language.locale)
                .preferredColorScheme(appState.preferences.theme.colorScheme)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.appState = appState
                    appDelegate.applyLanguage(appState.preferences.language)
                }
                .onOpenURL { url in
                    if ["md", "markdown", "mdown", "txt"].contains(url.pathExtension.lowercased()) { appState.openFile(url) }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands(appState: appState)
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
                .environment(\.locale, appState.preferences.language.locale)
                .preferredColorScheme(appState.preferences.theme.colorScheme)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var languageObserver: NSObjectProtocol?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        (appState?.saveCurrentFile() ?? true) ? .terminateNow : .terminateCancel
    }

    func applicationDidResignActive(_ notification: Notification) {
        appState?.setBackgroundActivity(true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState?.setBackgroundActivity(false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        if let icon = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = icon
        } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                  let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.dockTile.display()

        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            for window in NSApplication.shared.windows {
                if window.miniwindowImage == nil {
                    window.miniwindowImage = NSApplication.shared.applicationIconImage
                }
            }
        }

        languageObserver = NotificationCenter.default.addObserver(
            forName: .preferencesDidChange, object: nil, queue: .main
        ) { [weak self] note in
            guard let preferences = note.object as? Preferences else { return }
            Task { @MainActor in self?.applyLanguage(preferences.language) }
        }
    }

    func applyLanguage(_ language: AppLanguage) {
        let chinese = language == .simplifiedChinese
        let titles = chinese
            ? ["File": "文件", "Edit": "编辑", "View": "显示", "Window": "窗口", "Help": "帮助",
               "About M Notes": "关于 M Notes", "Check for Updates…": "检查更新…", "Settings…": "偏好设置…", "Services": "服务",
               "Hide M Notes": "隐藏 M Notes", "Hide Others": "隐藏其他", "Show All": "全部显示", "Quit M Notes": "退出 M Notes",
               "Undo": "撤销", "Redo": "重做", "Cut": "剪切", "Copy": "复制", "Paste": "粘贴", "Select All": "全选",
               "Minimize": "最小化", "Zoom": "缩放", "Bring All to Front": "前置全部窗口"]
            : ["文件": "File", "编辑": "Edit", "显示": "View", "视图": "View", "窗口": "Window", "帮助": "Help",
               "关于 M Notes": "About M Notes", "检查更新…": "Check for Updates…", "偏好设置…": "Settings…", "服务": "Services",
               "隐藏 M Notes": "Hide M Notes", "隐藏其他": "Hide Others", "全部显示": "Show All", "退出 M Notes": "Quit M Notes",
               "撤销": "Undo", "重做": "Redo", "剪切": "Cut", "复制": "Copy", "粘贴": "Paste", "全选": "Select All",
               "最小化": "Minimize", "缩放": "Zoom", "前置全部窗口": "Bring All to Front"]
        localize(NSApp.mainMenu, using: titles)
        DispatchQueue.main.async { [weak self] in self?.localize(NSApp.mainMenu, using: titles) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.localize(NSApp.mainMenu, using: titles)
        }
    }

    private func localize(_ menu: NSMenu?, using titles: [String: String]) {
        for item in menu?.items ?? [] {
            if let translated = titles[item.title] { item.title = translated }
            localize(item.submenu, using: titles)
        }
    }
}
