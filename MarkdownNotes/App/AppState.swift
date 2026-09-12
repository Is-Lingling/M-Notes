import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Recent Files Category
struct RecentCategory: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var filePaths: [String] = []
    var isExpanded: Bool = true

    var fileURLs: [URL] {
        get { filePaths.map { URL(fileURLWithPath: $0) } }
        set { filePaths = newValue.map(\.path) }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    // MARK: Navigation
    @Published var selectedFolder: FileNode?
    @Published var selectedFile: FileNode?
    @Published var sidebarVisible: Bool = true
    @Published var listPanelVisible: Bool = true
    @Published var outlinePanelVisible: Bool = false

    // MARK: Editor State
    @Published var currentContent: String = ""
    @Published var isSourceMode: Bool = false
    @Published var isFocusMode: Bool = false
    @Published var isTypewriterMode: Bool = false
    @Published var wordCount: Int = 0
    @Published var charCount: Int = 0
    @Published var outlineItems: [OutlineItem] = []
    @Published var isDirty: Bool = false

    // MARK: Search
    @Published var findReplaceVisible: Bool = false
    @Published var showReplaceInFindBar: Bool = false
    @Published var findText: String = ""
    @Published var replaceText: String = ""
    @Published var globalSearchVisible = false
    @Published var isSearching = false
    @Published var globalSearchQuery: String = ""
    @Published var globalSearchResults: [GlobalSearchResult] = []

    // MARK: File System
    @Published var rootFolders: [FileNode] = []
    @Published var recentFiles: [URL] = []
    @Published var recentCategories: [RecentCategory] = []
    @Published var uncategorizedFiles: [URL] = []
    @Published var updateChecker = UpdateChecker.shared
    @Published var selectedPreferencesTab: String = "general"

    // MARK: Preferences
    @Published var preferences = Preferences() {
        didSet {
            savePreferences()
            defaults.set([preferences.language.rawValue], forKey: "AppleLanguages")
            if oldValue.watchFileChanges != preferences.watchFileChanges {
                if preferences.watchFileChanges, let file = selectedFile {
                    startWatching(url: file.url.deletingLastPathComponent())
                } else if !preferences.watchFileChanges {
                    fsWatcher?.stop()
                    fsWatcher = nil
                }
            }
            NotificationCenter.default.post(name: .preferencesDidChange, object: preferences)
        }
    }

    // MARK: File Watcher
    private var fsWatcher: FSEventWatcher?
    private var saveTimer: Timer?
    private var searchDebounceTimer: Timer?

    private let defaults: UserDefaults
    init(restoreSession: Bool = true, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPreferences()
        defaults.set([preferences.language.rawValue], forKey: "AppleLanguages")
        loadRecentFiles()
        // The sidebar now tracks documents, not folders.

        guard restoreSession else { return }
        // 启动时自动打开最近编辑的文档或使用说明
        DispatchQueue.main.async {
            guard self.selectedFile == nil else { return }
            if let firstRecent = self.recentFiles.first, FileManager.default.fileExists(atPath: firstRecent.path) {
                self.openFile(firstRecent)
            } else {
                self.openWelcomeGuide()
            }
        }

        if preferences.autoCheckForUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.updateChecker.checkForUpdates(manual: false)
            }
        }
    }

    // MARK: - Update & Preferences Navigation
    func checkForUpdates(manual: Bool = true) {
        openPreferences(tab: "about")
        updateChecker.checkForUpdates(manual: manual)
    }

    func openPreferences(tab: String = "general") {
        selectedPreferencesTab = tab
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Welcome Guide
    func openWelcomeGuide() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let appDir = appSupport.appendingPathComponent("MarkdownNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let isEnglish = preferences.language == .english
        let guideURL = appDir.appendingPathComponent(isEnglish ? "M Notes Guide.md" : "M Notes 使用说明.md")
        let content = isEnglish ? AppState.sampleGuideContentEnglish : AppState.sampleGuideContent
        try? content.write(to: guideURL, atomically: true, encoding: .utf8)
        openFile(guideURL)
    }

    static let sampleGuideContent: String = #"""
# 欢迎使用 M Notes

> **优雅、高效、原生的 macOS 所见即所得 Markdown 与纯文本编辑器**
>
> 专为沉浸式写作、技术笔记、学术文档与知识沉淀打造。支持即时渲染、无占位语法折叠、Mermaid 图表、KaTeX 复杂公式、交互式表格与任务清单，并提供独立离线 HTML 及矢量 A4 分页 PDF 导出。

---

## 目录 (Table of Contents)

- [1. 快速上手](#1-快速上手)
- [2. 所见即所得与语法无感折叠](#2-所见即所得与语法无感折叠)
- [3. 文本样式与排版](#3-文本样式与排版)
- [4. 多媒体与图片](#4-多媒体与图片)
- [5. 交互式任务清单](#5-交互式任务清单)
- [6. 交互式表格 (Live Tables)](#6-交互式表格-live-tables)
- [7. 语法高亮代码块](#7-语法高亮代码块)
- [8. 数学公式 (KaTeX)](#8-数学公式-katex)
- [9. Mermaid 丰富图表](#9-mermaid-丰富图表)
- [10. 智能导航与全局搜索](#10-智能导航与全局搜索)
- [11. 导出与发布](#11-导出与发布)
- [12. 偏好设置与个性化](#12-偏好设置与个性化)
- [13. 快捷键速查表](#13-快捷键速查表)
- [14. 开源与贡献指南](#14-开源与贡献指南)

---

## 1. 快速上手

M Notes 将纯文本编辑的极速与排版渲染的直观融为一体：

- **新建笔记**：按快捷键 `⌘N` 即刻开启全新创作。
- **打开文件**：按 `⌘O` 支持快速打开 `.md`、`.markdown`、`.mdown` 以及 `.txt` 纯文本文件。
- **保存与另存为**：按 `⌘S` 快速保存；`⌘⇧S` 另存为新文件。
- **源码与实时预览切换**：按快捷键 `⌘/`，随时在极简源码模式与富文本即时预览模式之间无缝切换。
- **断点记忆**：左侧“最近使用”记录您在每个文档中的阅读与编辑位置，再次打开时毫秒级自动还原。

---

## 2. 所见即所得与语法无感折叠

M Notes 采用类似 Typora 的 **Seamless WYSIWYG**（无缝即时预览）架构。

### 标题（Heading）折叠演示

当光标不在标题行时，前缀的 `#` 符号会自动隐藏，并且**彻底不占用任何水平空间**，文本紧靠边距；当您点击该行或用光标移动进入时，`#` 符号立即展开并占用实际位置，方便精确修改标题级别：

# 一级标题 (Header 1)
## 二级标题 (Header 2)
### 三级标题 (Header 3)
#### 四级标题 (Header 4)
##### 五级标题 (Header 5)
###### 六级标题 (Header 6)

> 💡 **操作体验提示**：尝试用键盘方向键 `↑` / `↓` 穿过上面的标题行，观察 `#` 标记在光标移入时平滑展开、移出时紧凑收起的动态效果！

---

## 3. 文本样式与排版

M Notes 全面支持 CommonMark 与 GitHub Flavored Markdown (GFM) 规范，所有行内格式符号（如 `**`、`*`、`~~`、`` ` ``）同样遵循“非光标行零占位隐藏、光标行完整展示”的规则：

- **粗体强调**：选中文字按 `⌘B`，或书写 `**粗体文本**`。
- *斜体强调*：选中文字按 `⌘I`，或书写 `*斜体文本*`。
- ***粗斜体结合***：使用 `***粗斜体文本***` 同时应用强调。
- ~~删除线效果~~：使用 `~~删除线文本~~` 标记废弃或变更内容。
- `行内代码`：使用单反引号 `` `code` `` 标记变量、方法或命令行参数。
- [超链接导航](https://github.com)：使用 `[显示文本](URL)` 插入链接。光标离开时仅显示带下划线的链接文本，光标进入时展示完整语法。

### 引用与多层嵌套引用

使用 `>` 引导引用段落，左侧呈现典雅的主题强调色竖线，支持嵌套多层：

> 优雅是唯一不会褪色的美。
>
> — 奥黛丽·赫本
>
>> 支持在引用中嵌套更深层次的探讨或批注。
>> 引用内部同样完整支持 **粗体**、*斜体* 以及数学公式 $E = mc^2$。

---

## 4. 多媒体与图片

M Notes 为本地与网络图片提供了完备的交互支持：

![M Notes Banner](data:image/svg+xml;utf8,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27800%27%20height%3D%27180%27%20viewBox%3D%270%200%20800%20180%27%3E%3Cdefs%3E%3ClinearGradient%20id%3D%27g%27%20x1%3D%270%25%27%20y1%3D%270%25%27%20x2%3D%27100%25%27%20y2%3D%27100%25%27%3E%3Cstop%20offset%3D%270%25%27%20stop-color%3D%27%233B82F6%27%2F%3E%3Cstop%20offset%3D%2750%25%27%20stop-color%3D%27%236366F1%27%2F%3E%3Cstop%20offset%3D%27100%25%27%20stop-color%3D%27%238B5CF6%27%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%27100%25%27%20height%3D%27100%25%27%20rx%3D%2716%27%20fill%3D%27url%28%23g%29%27%2F%3E%3Ctext%20x%3D%2750%25%27%20y%3D%2745%25%27%20dominant-baseline%3D%27middle%27%20text-anchor%3D%27middle%27%20font-family%3D%27system-ui%2C%20-apple-system%2C%20sans-serif%27%20font-size%3D%2732%27%20font-weight%3D%27800%27%20fill%3D%27white%27%3EM%20Notes%20for%20macOS%3C%2Ftext%3E%3Ctext%20x%3D%2750%25%27%20y%3D%2770%25%27%20dominant-baseline%3D%27middle%27%20text-anchor%3D%27middle%27%20font-family%3D%27system-ui%2C%20-apple-system%2C%20sans-serif%27%20font-size%3D%2716%27%20fill%3D%27%23EEF2FF%27%3E%E6%89%80%E8%A7%81%E5%8D%B3%E6%89%80%E5%BE%97%20Markdown%20%E2%80%A2%20Mermaid%20%E5%9B%BE%E8%A1%A8%20%E2%80%A2%20KaTeX%20%E6%95%B0%E5%AD%A6%E5%85%AC%E5%BC%8F%20%E2%80%A2%20A4%20%E7%9F%A2%E9%87%8F%E5%AF%BC%E5%87%BA%3C%2Ftext%3E%3C%2Fsvg%3E)

- **直接拖拽置入**：从桌面或访达将图片文件直接拖放到编辑区，即可自动在光标位置生成图片语法。
- **访达选择插入**：点击顶栏格式工具栏的 `+` 菜单并选择“插入图片”，呼出系统文件选取器。
- **图片路径快速编辑**：鼠标单击已渲染的图片，图片下方会立即浮出路径输入框，修改后按 `Enter` 保存或按 `Esc` 关闭。
- **网络与相对路径**：支持相对路径（`assets/diagram.png`）、本地绝对路径以及 HTTP/HTTPS 网络图片链接。

---

## 5. 交互式任务清单

专为待办管理、项目管理与日常清单量身设计。在编辑区直接点击左侧复选框，即可同步更新底层 Markdown：

- [x] 下载并体验 M Notes 客户端
- [x] 体验 Typora 风格标题无感隐藏功能
- [ ] 撰写一篇属于自己的技术博客
- [ ] 使用 Mermaid 绘制一个系统架构流程图
- [ ] 导出为高清 A4 矢量 PDF 打印分享

---

## 6. 交互式表格 (Live Tables)

无需手动对齐复杂的管道符 `|`，M Notes 提供媲美专业电子表格的 Live Table 交互体验：

| 快捷操作 | 按键映射 | 功能说明 | 支持状态 |
| :--- | :---: | :--- | :---: |
| **向下增行** | `⌘⌥↓` | 在当前光标所在行下方插入一个空数据行 | ✅ 原生支持 |
| **删除当前行** | `⌘⌥⌫` | 移除当前光标行（表头行受安全保护无法误删） | ✅ 原生支持 |
| **向右增列** | `⌘⌥→` | 在当前所在列右侧追加新的一列 | ✅ 原生支持 |
| **删除当前列** | `⌘⌥⇧⌫` | 移除当前所在列（单列表格无法移除） | ✅ 原生支持 |
| **单元格流转** | `Tab` / `⇧Tab` | 向后或向前跳转单元格；在表格末单元格按 Tab 自动追加新行 | ✅ 原生支持 |
| **整表选中删除** | 单击表格工具条空白 | 整体选中表格，按 `Backspace` 即可一键删除整表，支持 `⌘Z` 撤销 | ✅ 原生支持 |

---

## 7. 语法高亮代码块

支持数十种主流编程语言语法高亮，配备现代化代码顶栏、语言徽章与一键复制：

```swift
import SwiftUI
import WebKit

/// M Notes 原生与 WebKit 通信桥梁
@MainActor
final class EditorBridge: ObservableObject {
    @Published var documentTitle: String = "Untitled"
    
    func onContentUpdated(_ newMarkdown: String) {
        print("Markdown updated, characters: \(newMarkdown.count)")
    }
}
```

```rust
// 体验极速并发与内存安全
fn calculate_fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0;
            let mut b = 1;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}
```

```python
# 数据分析与机器学习代码片段
import numpy as np

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    dot_product = np.dot(a, b)
    norm_product = np.linalg.norm(a) * np.linalg.norm(b)
    return float(dot_product / (norm_product + 1e-8))
```

> 💡 **代码块操作小技巧**：将鼠标悬停在代码块顶部，点击右上角「复制」按钮即可将纯代码拷入剪贴板；点击顶栏空白处可一键选中整个代码块。

---

## 8. 数学公式 (KaTeX)

M Notes 内置完整的 KaTeX 数学排版引擎，支持丰富的 LaTeX 语法，秒级渲染高质量公式。

### 行内数学公式

在正文中随时嵌入行内公式：例如著名的质能方程 $E = mc^2$，欧拉恒等式 $e^{i\pi} + 1 = 0$，以及极限定义 $\lim_{x \to 0} \frac{\sin x}{x} = 1$。

### 块级数学公式

使用对齐的 `$$` 标记包裹独立公式块：

$$
f(x) = \frac{1}{\sigma \sqrt{2\pi}} \exp\left( -\frac{(x - \mu)^2}{2\sigma^2} \right)
$$

麦克斯韦方程组微分形式：

$$
\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \cdot \mathbf{B} &= 0 \\
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned}
$$

线性代数矩阵运算：

$$
\mathbf{A} = \begin{pmatrix}
a_{11} & a_{12} & \dots & a_{1n} \\
a_{21} & a_{22} & \dots & a_{2n} \\
\vdots & \vdots & \ddots & \vdots \\
a_{m1} & a_{m2} & \dots & a_{mn}
\end{pmatrix}
$$

---

## 9. Mermaid 丰富图表

M Notes 深度集成了现代化图表渲染器 **Mermaid.js**，使用纯文本即可绘制架构图、业务流、交互时序与版本脉络。

### 1. 业务流程图 (Flowchart)

```mermaid
graph TD
    A[💡 灵感与想法] --> B(📝 M Notes 记录创作)
    B --> C{是否完成?}
    C -->|否| D[🔍 跨文档搜索参考]
    D --> B
    C -->|是| E[✨ 即时排版检查]
    E --> F[📄 独立离线 HTML]
    E --> G[📑 A4 矢量分页 PDF]
    E --> H[📱 单页连续长图 PDF]
```

### 2. 系统交互时序图 (Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor Author as 👤 创作者
    participant View as 🖥️ 原生 macOS 窗口
    participant Editor as 📝 CodeMirror 编辑内核
    participant Exporter as 🖨️ 矢量导出引擎

    Author->>View: 键盘键入或粘贴内容
    View->>Editor: 触发文档更新事件
    Editor-->>View: 实时语法折叠与视觉排版
    Author->>View: 点击菜单「导出为 PDF」
    View->>Exporter: 请求准备页面与嵌入资源
    Exporter->>Editor: 渲染 Mermaid、KaTeX、图片
    Exporter-->>Author: 输出印刷级分页 PDF 文档
```

### 3. Git 版本分支流 (Git Graph)

```mermaid
gitGraph
    commit id: "Initial Commit"
    commit id: "Add WYSIWYG Engine"
    branch feature/mermaid
    checkout feature/mermaid
    commit id: "Integrate Mermaid.js"
    commit id: "Add SVG Export"
    checkout main
    merge feature/mermaid id: "Merge Mermaid"
    commit id: "Release v1.0.0" tag: "v1.0.0"
```

---

## 10. 智能导航与全局搜索

- **文档内查找与替换**：
  - `⌘F`：快速调出查找条，高亮所有匹配项。
  - `⌘H`：进入查找与替换模式，支持单个或一键全部替换。
- **跨文档全文搜索 (`⌘⇧F`)**：
  - 在侧边栏直接输入关键词，瞬间穿透检索所有「最近使用」文档库及当前未保存内容。
  - 搜索结果附带上下文摘要预览，点击结果秒级打开并滚动至目标段落。
- **大纲视图 (`⌘⌥O`)**：
  - 自动提取当前文档全部 H1 ~ H6 标题构建树形目录。
  - 无论长文有多长，单击任意目录节点均可平滑定位。

---

## 11. 导出与发布

M Notes 具备专业级的导出与交付能力：

1. **单页长图 PDF (Single-Page PDF)**：
   - 将整篇文档无缝连续渲染至一张完整的长图 PDF 中，没有任何生硬的页面折断，特别适合手机、平板与电子书通读。
2. **分页 A4 矢量 PDF (Paginated PDF)**：
   - 专为正式打印与归档设计。内置智能排版分页算法，自动避开图片内部、代码块中途、表格单行或公式正中间的截断，保证每一页印刷质量。
3. **独立离线 HTML (Standalone HTML)**：
   - 一键生成无需服务器支持的单文件 HTML，图片全部内联为 Base64，KaTeX 矢量数学字体、Mermaid 图表与高亮 CSS 完全内嵌，直接双击任意浏览器即可打开。
4. **复制为 HTML**：
   - 一键将排版渲染后的 HTML 富文本存入系统剪贴板，方便粘贴至微信公众号、知乎、语雀等外部平台。

---

## 12. 偏好设置与个性化

点击左侧栏左下角的「偏好设置」图标，或者通过菜单栏进入设置面板：

- **多语言界面**：原生支持「简体中文」与「English」，切换即时全局生效并持久保存。
- **外观主题**：默认「跟随系统 (System Default)」，亦可固定为「明亮 (Light)」或「暗黑 (Dark)」模式。窗口、侧边栏、工具栏与编辑正文完全协调。
- **排版微调**：自由调整编辑器基础字号（13px ~ 28px）、正文行高（1.4 ~ 2.4）以及编辑区最大行宽（480px ~ 1200px / 全宽）。
- **编辑辅助**：支持一键开启/关闭行号、拼写检查、智能成对引号替换以及智能破折号。

---

## 13. 快捷键速查表

| 功能操作 | macOS 快捷键 | 功能说明 |
| :--- | :--- | :--- |
| **新建文档** | `⌘ N` | 新建空白 Markdown 文件 |
| **打开文档** | `⌘ O` | 打开本地 `.md` 或 `.txt` 文件 |
| **保存文件** | `⌘ S` | 快速保存当前文档 |
| **另存为** | `⌘ ⇧ S` | 将当前文档另存到新路径 |
| **源码模式** | `⌘ /` | 切换实时预览 / 纯 Markdown 源码 |
| **文本查找** | `⌘ F` | 打开当前文档内查找条 |
| **文本替换** | `⌘ H` | 打开当前文档内替换面板 |
| **全文搜索** | `⌘ ⇧ F` | 打开左侧栏跨文档全局搜索 |
| **大纲导航** | `⌘ ⌥ O` | 打开或关闭文档大纲侧栏 |
| **粗体样式** | `⌘ B` | 选中文本快速加粗 |
| **斜体样式** | `⌘ I` | 选中文本快速设为斜体 |
| **表格增行** | `⌘ ⌥ ↓` | 在当前表格行下方追加新行 |
| **表格删行** | `⌘ ⌥ ⌫` | 删除当前表格行 |
| **表格增列** | `⌘ ⌥ →` | 在当前表格列右侧追加新列 |
| **表格删列** | `⌘ ⌥ ⇧ ⌫` | 删除当前表格列 |

---

## 14. 开源与贡献指南

M Notes 作为一个致力于提供纯粹写作体验的开源项目，欢迎来自全球开发者的参与与建议！

- **开源协议**：本项目基于 [MIT License](LICENSE) 开源发布。
- **GitHub 仓库**：欢迎 Star、Fork 与提出您的宝贵建议。
- **提交反馈**：如果您在使用中发现了任何体验细节问题，欢迎提交 GitHub Issue。
- **参与贡献**：欢迎发起 Pull Request，共同打造更强大的 macOS Markdown 编辑利器！

```bash
# 源码构建与开发
git clone https://github.com/your-username/m-notes.git
cd m-notes
xcodegen generate
scripts/test-mnotes.sh
xcodebuild -project MarkdownNotes.xcodeproj -scheme MarkdownNotes -configuration Release build
```

---

感谢您选择并体验 **M Notes**！祝您写作愉快，灵感无限！
"""#

    static let sampleGuideContentEnglish: String = #"""
# Welcome to M Notes

> **Elegant, High-Performance, Native WYSIWYG Markdown & Plain-Text Editor for macOS**
>
> Crafted for immersive writing, technical documentation, academic research, and knowledge management. Features live preview with zero-width syntax hiding, Mermaid diagrams, KaTeX formulas, interactive tables, task lists, and standalone HTML/PDF export.

---

## Table of Contents

- [1. Quick Start](#1-quick-start)
- [2. WYSIWYG & Zero-Width Syntax Hiding](#2-wysiwyg--zero-width-syntax-hiding)
- [3. Typography & Inline Formatting](#3-typography--inline-formatting)
- [4. Media & Images](#4-media--images)
- [5. Interactive Task Lists](#5-interactive-task-lists)
- [6. Live Interactive Tables](#6-live-interactive-tables)
- [7. Syntax-Highlighted Code Blocks](#7-syntax-highlighted-code-blocks)
- [8. Math Formulas (KaTeX)](#8-math-formulas-katex)
- [9. Mermaid Diagrams](#9-mermaid-diagrams)
- [10. Search, Replace & Outline Navigation](#10-search-replace--outline-navigation)
- [11. Export & Publishing](#11-export--publishing)
- [12. Preferences & Customization](#12-preferences--customization)
- [13. Keyboard Shortcuts Cheat Sheet](#13-keyboard-shortcuts-cheat-sheet)
- [14. Open Source & Contribution](#14-open-source--contribution)

---

## 1. Quick Start

M Notes unites the lightning speed of plain-text editing with the immediate clarity of rendered typography:

- **New Document**: Press `⌘N` to start writing instantly.
- **Open Files**: Press `⌘O` to open `.md`, `.markdown`, `.mdown`, or `.txt` files.
- **Save & Save As**: Press `⌘S` to save; `⌘⇧S` to save as a new file.
- **Source Mode Switch**: Press `⌘/` anytime to toggle between live preview and raw markdown source.
- **Reading Position**: The Recents list remembers your exact scroll position and cursor location for every note.

---

## 2. WYSIWYG & Zero-Width Syntax Hiding

M Notes implements seamless Typora-style **live preview rendering**.

### Heading Syntax Demonstration

When your cursor is outside a heading line, the `#` symbols automatically hide and **occupy zero width**, aligning text cleanly to the left margin. Moving your cursor into the line instantly reveals the `#` prefix with its full natural width:

# Header Level 1
## Header Level 2
### Header Level 3
#### Header Level 4
##### Header Level 5
###### Header Level 6

> 💡 **Try it now**: Use your keyboard `↑` and `↓` arrow keys to move through the headings above and watch the `#` prefixes smoothly reveal and collapse!

---

## 3. Typography & Inline Formatting

M Notes fully complies with CommonMark and GitHub Flavored Markdown (GFM). All formatting delimiters (`**`, `*`, `~~`, `` ` ``) are completely hidden when inactive and revealed on the cursor's line:

- **Bold Emphasis**: Select text and press `⌘B`, or type `**bold text**`.
- *Italic Emphasis*: Select text and press `⌘I`, or type `*italic text*`.
- ***Bold & Italic***: Use `***bold and italic***` for combined emphasis.
- ~~Strikethrough~~: Use `~~strikethrough~~` to mark deleted or superseded text.
- `Inline Code`: Use backticks `` `code` `` for code tokens, variables, or terminal commands.
- [Hyperlinks](https://github.com): Use `[Label](URL)` to create links. The URL is hidden when inactive.

### Blockquotes & Nesting

Type `>` at the start of a line to create a blockquote with custom theme border:

> Simplicity is the prerequisite for reliability.
>
> — Edsger W. Dijkstra
>
>> Nested blockquotes allow sub-discussions or commentary.
>> Formulas like $E = mc^2$ and **bold formatting** render cleanly inside quotes.

---

## 4. Media & Images

M Notes provides comprehensive support for local, web, and inline images:

![M Notes Banner](data:image/svg+xml;utf8,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27800%27%20height%3D%27180%27%20viewBox%3D%270%200%20800%20180%27%3E%3Cdefs%3E%3ClinearGradient%20id%3D%27g%27%20x1%3D%270%25%27%20y1%3D%270%25%27%20x2%3D%27100%25%27%20y2%3D%27100%25%27%3E%3Cstop%20offset%3D%270%25%27%20stop-color%3D%27%233B82F6%27%2F%3E%3Cstop%20offset%3D%2750%25%27%20stop-color%3D%27%236366F1%27%2F%3E%3Cstop%20offset%3D%27100%25%27%20stop-color%3D%27%238B5CF6%27%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%27100%25%27%20height%3D%27100%25%27%20rx%3D%2716%27%20fill%3D%27url%28%23g%29%27%2F%3E%3Ctext%20x%3D%2750%25%27%20y%3D%2745%25%27%20dominant-baseline%3D%27middle%27%20text-anchor%3D%27middle%27%20font-family%3D%27system-ui%2C%20-apple-system%2C%20sans-serif%27%20font-size%3D%2732%27%20font-weight%3D%27800%27%20fill%3D%27white%27%3EM%20Notes%20for%20macOS%3C%2Ftext%3E%3Ctext%20x%3D%2750%25%27%20y%3D%2770%25%27%20dominant-baseline%3D%27middle%27%20text-anchor%3D%27middle%27%20font-family%3D%27system-ui%2C%20-apple-system%2C%20sans-serif%27%20font-size%3D%2716%27%20fill%3D%27%23EEF2FF%27%3EWYSIWYG%20Markdown%20%E2%80%A2%20Mermaid%20Diagrams%20%E2%80%A2%20KaTeX%20Math%20%E2%80%A2%20Vector%20A4%20PDF%3C%2Ftext%3E%3C%2Fsvg%3E)

- **Drag & Drop**: Drag images directly from Finder into the editor to insert them at the caret.
- **Finder Picker**: Click `+` in the toolbar and select "Insert Image" to choose files via native macOS dialog.
- **Interactive Path Bar**: Click any rendered image to reveal a path editing field below it.
- **Relative & Absolute**: Relative paths, local file URLs, and remote HTTPS images are all supported.

---

## 5. Interactive Task Lists

Keep track of to-dos and project checklists. Clicking the checkbox toggles completion and updates the underlying Markdown:

- [x] Install and launch M Notes
- [x] Experience zero-width header syntax folding
- [ ] Draft your first technical blog post in M Notes
- [ ] Create a system architecture diagram with Mermaid
- [ ] Export to print-ready A4 vector PDF

---

## 6. Live Interactive Tables

Edit tables like a spreadsheet without manually formatting pipes and hyphens:

| Action | Shortcut | Description | Status |
| :--- | :---: | :--- | :---: |
| **Add Row** | `⌘⌥↓` | Inserts a new row below the current row | ✅ Supported |
| **Delete Row** | `⌘⌥⌫` | Removes the current row (header row is protected) | ✅ Supported |
| **Add Column** | `⌘⌥→` | Inserts a new column to the right | ✅ Supported |
| **Delete Column** | `⌘⌥⇧⌫` | Removes the current column | ✅ Supported |
| **Cell Navigation** | `Tab` / `⇧Tab` | Moves focus between cells; Tab at last cell appends a row | ✅ Supported |
| **Select & Delete** | Click toolbar space | Selects the entire table; press `Backspace` to delete, `⌘Z` to undo | ✅ Supported |

---

## 7. Syntax-Highlighted Code Blocks

Supports syntax highlighting for dozens of popular languages, with language badges and one-click copy:

```swift
import SwiftUI
import WebKit

/// Native communication bridge for M Notes
@MainActor
final class EditorBridge: ObservableObject {
    @Published var documentTitle: String = "Untitled"
    
    func onContentUpdated(_ newMarkdown: String) {
        print("Markdown updated, characters: \(newMarkdown.count)")
    }
}
```

```rust
// Fast concurrency and memory safety
fn calculate_fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0;
            let mut b = 1;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}
```

```python
# Data analysis and cosine similarity
import numpy as np

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    dot_product = np.dot(a, b)
    norm_product = np.linalg.norm(a) * np.linalg.norm(b)
    return float(dot_product / (norm_product + 1e-8))
```

> 💡 **Code Block Tip**: Hover over the header to click the Copy button. Clicking empty space on the header selects the whole block for easy deletion.

---

## 8. Math Formulas (KaTeX)

Built-in KaTeX engine provides instant typesetting for complex scientific and engineering notation.

### Inline Math

Use single dollar signs for inline expressions: $E = mc^2$, Euler's identity $e^{i\pi} + 1 = 0$, or limits $\lim_{x \to 0} \frac{\sin x}{x} = 1$.

### Display Math Blocks

Enclose display equations in `$$` blocks:

$$
f(x) = \frac{1}{\sigma \sqrt{2\pi}} \exp\left( -\frac{(x - \mu)^2}{2\sigma^2} \right)
$$

Maxwell's equations in differential form:

$$
\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \cdot \mathbf{B} &= 0 \\
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned}
$$

Matrix algebra:

$$
\mathbf{A} = \begin{pmatrix}
a_{11} & a_{12} & \dots & a_{1n} \\
a_{21} & a_{22} & \dots & a_{2n} \\
\vdots & \vdots & \ddots & \vdots \\
a_{m1} & a_{m2} & \dots & a_{mn}
\end{pmatrix}
$$

---

## 9. Mermaid Diagrams

M Notes renders **Mermaid.js** diagrams directly from fenced code blocks:

### 1. Flowchart

```mermaid
graph TD
    A[💡 Idea & Concept] --> B(📝 M Notes Authoring)
    B --> C{Complete?}
    C -->|No| D[🔍 Search Recents]
    D --> B
    C -->|Yes| E[✨ Instant WYSIWYG Review]
    E --> F[📄 Standalone HTML]
    E --> G[📑 Paginated Vector PDF]
    E --> H[📱 Single-Page Continuous PDF]
```

### 2. Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Author as 👤 Author
    participant Window as 🖥️ Native Window
    participant Editor as 📝 CodeMirror Engine
    participant Exporter as 🖨️ PDF & HTML Exporter

    Author->>Window: Type or paste Markdown
    Window->>Editor: Document change transaction
    Editor-->>Window: Real-time syntax folding
    Author->>Window: Select Export to PDF
    Window->>Exporter: Request export package
    Exporter->>Editor: Render Mermaid, KaTeX, images
    Exporter-->>Author: Print-ready vector PDF document
```

### 3. Git Graph

```mermaid
gitGraph
    commit id: "Initial Commit"
    commit id: "Add WYSIWYG Engine"
    branch feature/mermaid
    checkout feature/mermaid
    commit id: "Integrate Mermaid.js"
    commit id: "Add SVG Export"
    checkout main
    merge feature/mermaid id: "Merge Mermaid"
    commit id: "Release v1.0.0" tag: "v1.0.0"
```

---

## 10. Search, Replace & Outline Navigation

- **Find & Replace**:
  - `⌘F`: In-document quick find bar with instant match highlights.
  - `⌘H`: Search and replace with single or batch replacements.
- **Global Full-Text Search (`⌘⇧F`)**:
  - Search across all recent documents and unsaved drafts directly from the sidebar.
  - Results show context snippets with match highlighting.
- **Outline View (`⌘⌥O`)**:
  - Automatically parses document headings into an interactive hierarchical tree.
  - Jump directly to any section with a single click.

---

## 11. Export & Publishing

- **Single-Page PDF**: Exports the entire document onto one continuous page without page breaks. Ideal for digital reading.
- **Paginated A4 PDF**: Engineered for physical printing. Smart pagination avoids breaking images, table rows, headings, and equations across pages.
- **Standalone HTML**: Generates a self-contained HTML file with embedded Base64 images, KaTeX fonts, Mermaid diagrams, and highlight styles.
- **Copy as HTML**: Copies formatted rich HTML directly to your clipboard for easy pasting into external CMS platforms.

---

## 12. Preferences & Customization

Click the Preferences icon at the bottom of the sidebar or press `⌘,`:

- **Language**: Instant switching between Simplified Chinese and English.
- **Appearance Theme**: System Default, Light, and Dark modes that harmonize windows, sidebars, toolbars, and editor canvas.
- **Typography**: Fine-tune font size (13px ~ 28px), line height (1.4 ~ 2.4), and editor max width (480px ~ 1200px / Full Width).
- **Editor Options**: Toggle line numbers, spell check, smart quotes, and smart dashes.

---

## 13. Keyboard Shortcuts Cheat Sheet

| Action | macOS Shortcut | Description |
| :--- | :--- | :--- |
| **New Document** | `⌘ N` | Create a new blank Markdown note |
| **Open File** | `⌘ O` | Open local `.md` or `.txt` file |
| **Save Document** | `⌘ S` | Save the current document |
| **Save As** | `⌘ ⇧ S` | Save to a new destination |
| **Source Mode** | `⌘ /` | Toggle WYSIWYG / raw Markdown |
| **Find** | `⌘ F` | Open the find bar |
| **Replace** | `⌘ H` | Open find and replace panel |
| **Full-Text Search** | `⌘ ⇧ F` | Search across recent files |
| **Toggle Outline** | `⌘ ⌥ O` | Show or hide the document outline |
| **Bold** | `⌘ B` | Apply bold to selection |
| **Italic** | `⌘ I` | Apply italic to selection |
| **Add Table Row** | `⌘ ⌥ ↓` | Insert row below current cell |
| **Delete Table Row** | `⌘ ⌥ ⌫` | Remove current row |
| **Add Table Column** | `⌘ ⌥ →` | Insert column to the right |
| **Delete Table Column** | `⌘ ⌥ ⇧ ⌫` | Remove current column |

---

## 14. Open Source & Contribution

M Notes is dedicated to providing a distraction-free, high-performance writing experience:

- **License**: Released under the [MIT License](LICENSE).
- **GitHub**: Contributions, issues, and feature requests are warmly welcomed!

```bash
# Build from source
git clone https://github.com/your-username/m-notes.git
cd m-notes
xcodegen generate
scripts/test-mnotes.sh
xcodebuild -project MarkdownNotes.xcodeproj -scheme MarkdownNotes -configuration Release build
```

---

Thank you for choosing **M Notes**! Happy writing!
"""#


    // MARK: - File Operations

    func openFolder(_ url: URL) {
        let node = FileNode(url: url)
        if !rootFolders.contains(where: { $0.url == url }) {
            rootFolders.append(node)
        }
        selectedFolder = node
        saveRootFolders()
        startWatching(url: url)
    }

    var isPlainText: Bool { selectedFile?.url.pathExtension.lowercased() == "txt" }
    private var fileEncoding: String.Encoding = .utf8

    @discardableResult
    func openFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let alert = NSAlert()
            alert.messageText = "文件已经移动或删除"
            alert.informativeText = "无法打开“\(url.lastPathComponent)”。是否从最近使用中删除这条记录？"
            alert.addButton(withTitle: "删除记录")
            alert.addButton(withTitle: "保留记录")
            if alert.runModal() == .alertFirstButtonReturn { removeRecentFile(url) }
            return false
        }
        if selectedFile?.url == url { return true }
        var encoding = String.Encoding.utf8
        let content: String
        do { content = try String(contentsOf: url, usedEncoding: &encoding) }
        catch { showError("无法打开文件", error: error); return false }
        if isDirty && !saveCurrentFile() { return false }
        saveTimer?.invalidate()
        fileEncoding = encoding
        let node = FileNode(url: url)
        selectedFile = node
        currentContent = content
        isDirty = false
        addToRecent(url)
        updateWordCount(content)
        updateOutlineFromContent(content)
        isSourceMode = isPlainText
        return true
    }

    func openFileWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        if let mdown = UTType(filenameExtension: "mdown") { types.append(mdown) }
        panel.allowedContentTypes = types
        let isEnglish = preferences.language == .english
        panel.prompt = isEnglish ? "Open" : "打开"
        panel.message = isEnglish ? "Choose a Markdown or text file to open" : "选择要打开的 Markdown 或文本文件"
        if panel.runModal() == .OK, let url = panel.url {
            openFile(url)
        }
    }

    @discardableResult
    func saveCurrentFile() -> Bool {
        guard let file = selectedFile, isDirty else { return true }
        do {
            try currentContent.write(to: file.url, atomically: true, encoding: fileEncoding)
            isDirty = false
            return true
        } catch { showError("保存失败", error: error); return false }
    }

    @discardableResult
    func saveAs(_ url: URL) -> Bool {
        do {
            try currentContent.write(to: url, atomically: true, encoding: .utf8)
            fileEncoding = .utf8
            selectedFile = FileNode(url: url)
            isDirty = false
            isSourceMode = isPlainText
            addToRecent(url)
            return true
        } catch { showError("另存为失败", error: error); return false }
    }

    func showError(_ title: String, error: Error) {
        let alert = NSAlert(); alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    func readingPosition(for url: URL) -> [String: Any] {
        (defaults.dictionary(forKey: "readingPositions")?[url.path] as? [String: Any]) ?? [:]
    }
    func saveReadingPosition(_ position: [String: Any], documentID: String) {
        var positions = defaults.dictionary(forKey: "readingPositions") ?? [:]
        positions[documentID] = position
        defaults.set(positions, forKey: "readingPositions")
    }

    func defaultDirectory() -> URL {
        if !preferences.defaultSaveLocation.isEmpty {
            let customURL = URL(fileURLWithPath: preferences.defaultSaveLocation)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: customURL.path, isDirectory: &isDir), isDir.boolValue {
                return customURL
            }
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func createNewFile(in folder: FileNode? = nil) -> FileNode? {
        let dir = folder?.url ?? defaultDirectory()
        var name = "Untitled.md"
        var idx = 1
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) {
            name = "Untitled \(idx).md"
            idx += 1
        }
        let url = dir.appendingPathComponent(name)
        do {
            try "".write(to: url, atomically: true, encoding: .utf8)
            return FileNode(url: url)
        } catch { showError("无法新建文档", error: error); return nil }
    }

    func deleteFile(_ node: FileNode) {
        try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        if selectedFile?.url == node.url {
            selectedFile = nil
            currentContent = ""
        }
    }

    func contentDidChange(_ newContent: String) {
        guard newContent != currentContent else { return }
        currentContent = newContent
        isDirty = true
        if preferences.autoSave { scheduleAutoSave() }
        updateWordCount(newContent)
        updateOutlineFromContent(newContent)
    }

    // MARK: - Auto Save
    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.saveCurrentFile() }
        }
    }

    // MARK: - Word Count
    func updateWordCount(_ text: String) {
        let stripped = text
            .replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\*{1,2}([^*]+)\\*{1,2}", with: "$1", options: .regularExpression)
        let words = stripped.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        wordCount = words.count
        charCount = stripped.filter { !$0.isWhitespace }.count
    }

    func updateOutlineFromContent(_ content: String) {
        let lines = content.components(separatedBy: "\n")
        var items: [OutlineItem] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let pounds = trimmed.prefix(while: { $0 == "#" })
                let level = pounds.count
                if level >= 1 && level <= 6 {
                    let rest = trimmed.dropFirst(level)
                    if rest.hasPrefix(" ") || rest.hasPrefix("\t") {
                        let text = rest.trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            if let item = OutlineItem(dict: [
                                "id": "heading-\(idx)",
                                "level": level,
                                "text": text,
                                "line": idx
                            ]) {
                                items.append(item)
                            }
                        }
                    }
                }
            }
        }
        outlineItems = items
    }

    // MARK: - Global Full-Text Search
    func performGlobalSearch(query: String) {
        guard !query.isEmpty else { globalSearchResults = []; isSearching = false; return }
        isSearching = true
        let urls = Array(Set(recentFiles + [selectedFile?.url].compactMap { $0 }))
        let currentURL = selectedFile?.url
        let currentText = currentContent
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [GlobalSearchResult] = []
            for url in urls {
                var encoding = String.Encoding.utf8
                guard let content = url == currentURL ? currentText : try? String(contentsOf: url, usedEncoding: &encoding) else { continue }
                for (lineNum, line) in content.components(separatedBy: "\n").enumerated() {
                    if line.localizedCaseInsensitiveContains(query) {
                        results.append(GlobalSearchResult(fileURL: url, fileName: url.lastPathComponent,
                            lineNumber: lineNum + 1, lineText: line.trimmingCharacters(in: .whitespaces),
                            matchRange: line.range(of: query, options: .caseInsensitive)))
                    }
                    if results.count >= 200 { break }
                }
                if results.count >= 200 { break }
            }
            DispatchQueue.main.async {
                guard self.globalSearchQuery == query else { return }
                self.globalSearchResults = results; self.isSearching = false
            }
        }
    }

    /// Quick preview check for list filtering (non-blocking)
    func globalSearchPreview(_ url: URL, query: String) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return content.localizedCaseInsensitiveContains(query)
    }

    // MARK: - File System Watching
    func startWatching(url: URL) {
        fsWatcher?.stop()
        fsWatcher = FSEventWatcher(url: url) { [weak self] changedURL in
            Task { @MainActor in
                NotificationCenter.default.post(name: .fileSystemDidChange, object: changedURL)
                // Auto-reload if current file was changed externally
                if let currentFile = self?.selectedFile,
                   changedURL.deletingLastPathComponent() == currentFile.url.deletingLastPathComponent() {
                    self?.reloadCurrentFileIfNeeded()
                }
            }
        }
        fsWatcher?.start()
    }

    private func reloadCurrentFileIfNeeded() {
        guard let file = selectedFile, !isDirty else { return }
        guard let newContent = try? String(contentsOf: file.url, encoding: .utf8),
              newContent != currentContent else { return }
        currentContent = newContent
        NotificationCenter.default.post(name: .fileContentReloaded, object: newContent)
    }

    // MARK: - Persistence
    private func loadPreferences() {
        guard let data = defaults.data(forKey: "preferences"),
              var decoded = try? JSONDecoder().decode(Preferences.self, from: data) else { return }
        if !defaults.bool(forKey: "themeDefaultMigratedV4"), decoded.theme == .notesLight {
            decoded.theme = .system
            defaults.set(true, forKey: "themeDefaultMigratedV4")
        }
        preferences = decoded
    }

    private func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: "preferences")
    }

    private func loadRecentFiles() {
        let paths = defaults.stringArray(forKey: "recentFiles") ?? []
        let rawRecentURLs = paths.compactMap { URL(fileURLWithPath: $0) }

        if let catData = defaults.data(forKey: "recentCategories"),
           let decodedCats = try? JSONDecoder().decode([RecentCategory].self, from: catData) {
            recentCategories = decodedCats
        } else {
            recentCategories = []
        }

        if let uncatPaths = defaults.stringArray(forKey: "uncategorizedFiles") {
            uncategorizedFiles = uncatPaths.compactMap { URL(fileURLWithPath: $0) }
        } else {
            let categoryPaths = Set(recentCategories.flatMap { $0.filePaths })
            uncategorizedFiles = rawRecentURLs.filter { !categoryPaths.contains($0.path) }
        }

        syncRecentFiles()
    }

    func syncRecentFiles() {
        var allPaths: [String] = []
        var seen = Set<String>()

        for cat in recentCategories {
            for path in cat.filePaths {
                if !seen.contains(path) {
                    seen.insert(path)
                    allPaths.append(path)
                }
            }
        }
        for url in uncategorizedFiles {
            if !seen.contains(url.path) {
                seen.insert(url.path)
                allPaths.append(url.path)
            }
        }
        recentFiles = allPaths.map { URL(fileURLWithPath: $0) }
    }

    func saveRecentFilesAndCategories() {
        syncRecentFiles()
        defaults.set(recentFiles.map(\.path), forKey: "recentFiles")
        defaults.set(uncategorizedFiles.map(\.path), forKey: "uncategorizedFiles")
        if let catData = try? JSONEncoder().encode(recentCategories) {
            defaults.set(catData, forKey: "recentCategories")
        }
    }

    private func addToRecent(_ url: URL) {
        let alreadyInUncat = uncategorizedFiles.contains(url)
        let alreadyInCats = recentCategories.contains(where: { $0.filePaths.contains(url.path) })

        if alreadyInUncat || alreadyInCats {
            // Requirement: clicking to open other files does not change order
            return
        }

        uncategorizedFiles.insert(url, at: 0)
        if uncategorizedFiles.count > 50 {
            uncategorizedFiles = Array(uncategorizedFiles.prefix(50))
        }
        saveRecentFilesAndCategories()
    }

    func removeRecentFile(_ url: URL) {
        uncategorizedFiles.removeAll { $0 == url }
        for idx in recentCategories.indices {
            recentCategories[idx].filePaths.removeAll { $0 == url.path }
        }
        saveRecentFilesAndCategories()
    }

    func deleteRecentFile(_ url: URL) {
        removeRecentFile(url)
        if selectedFile?.url == url {
            saveTimer?.invalidate()
            isDirty = false
        }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }
        if selectedFile?.url == url {
            if let nextURL = recentFiles.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                openFile(nextURL)
            } else {
                selectedFile = nil
                currentContent = ""
                outlineItems = []
                wordCount = 0
                charCount = 0
            }
        }
    }

    func confirmAndDeleteRecentFile(_ url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        let isEnglish = preferences.language == .english
        alert.messageText = isEnglish ? "Delete \"\(url.lastPathComponent)\"?" : "确认删除“\(url.lastPathComponent)”？"
        alert.informativeText = isEnglish ? "This operation will delete the local file. Confirm deletion?" : "该操作会删除本地文件，确认删除。"
        alert.addButton(withTitle: isEnglish ? "Delete" : "确认删除")
        let cancelBtn = alert.addButton(withTitle: isEnglish ? "Cancel" : "取消")
        cancelBtn.keyEquivalent = "\u{1b}"

        if alert.runModal() == .alertFirstButtonReturn {
            deleteRecentFile(url)
        }
    }

    // MARK: - File Renaming
    func renameFile(_ url: URL, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let finalName: String
        if (trimmed as NSString).pathExtension.isEmpty && !url.pathExtension.isEmpty {
            finalName = trimmed + "." + url.pathExtension
        } else {
            finalName = trimmed
        }

        guard finalName != url.lastPathComponent else { return }

        let parentDir = url.deletingLastPathComponent()
        let destinationURL = parentDir.appendingPathComponent(finalName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let isEnglish = preferences.language == .english
            let alert = NSAlert()
            alert.messageText = isEnglish ? "File Already Exists" : "文件已存在"
            alert.informativeText = isEnglish
                ? "A file named \"\(finalName)\" already exists in this folder."
                : "当前目录下已存在名为“\(finalName)”的文件。"
            alert.runModal()
            return
        }

        do {
            try FileManager.default.moveItem(at: url, to: destinationURL)
        } catch {
            showError(preferences.language == .english ? "Rename Failed" : "重命名失败", error: error)
            return
        }

        var positions = defaults.dictionary(forKey: "readingPositions") ?? [:]
        if let existingPos = positions[url.path] {
            positions.removeValue(forKey: url.path)
            positions[destinationURL.path] = existingPos
            defaults.set(positions, forKey: "readingPositions")
        }

        if let idx = uncategorizedFiles.firstIndex(of: url) {
            uncategorizedFiles[idx] = destinationURL
        }

        for catIdx in recentCategories.indices {
            if let fIdx = recentCategories[catIdx].filePaths.firstIndex(of: url.path) {
                recentCategories[catIdx].filePaths[fIdx] = destinationURL.path
            }
        }

        saveRecentFilesAndCategories()

        if selectedFile?.url == url {
            selectedFile = FileNode(url: destinationURL)
        }

        NotificationCenter.default.post(name: .fileSystemDidChange, object: destinationURL)
    }

    func promptRenameFile(_ url: URL) {
        let alert = NSAlert()
        let isEnglish = preferences.language == .english
        alert.messageText = isEnglish ? "Rename File" : "重命名文件"
        alert.informativeText = isEnglish
            ? "Enter a new name for \"\(url.lastPathComponent)\":"
            : "请输入“\(url.lastPathComponent)”的新文件名："
        alert.addButton(withTitle: isEnglish ? "Rename" : "重命名")
        let cancelBtn = alert.addButton(withTitle: isEnglish ? "Cancel" : "取消")
        cancelBtn.keyEquivalent = "\u{1b}"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = url.deletingPathExtension().lastPathComponent
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            renameFile(url, newName: input.stringValue)
        }
    }

    // MARK: - Category Management
    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newCat = RecentCategory(name: trimmed)
        recentCategories.append(newCat)
        saveRecentFilesAndCategories()
    }

    func promptCreateCategory() {
        let alert = NSAlert()
        let isEnglish = preferences.language == .english
        alert.messageText = isEnglish ? "New Folder" : "新建文件夹"
        alert.informativeText = isEnglish ? "Enter folder name:" : "输入文件夹名称："
        alert.addButton(withTitle: isEnglish ? "Create" : "创建")
        let cancelBtn = alert.addButton(withTitle: isEnglish ? "Cancel" : "取消")
        cancelBtn.keyEquivalent = "\u{1b}"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = isEnglish ? "New Folder" : "新建文件夹"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            createCategory(name: input.stringValue)
        }
    }

    func deleteCategory(id: UUID) {
        guard let cat = recentCategories.first(where: { $0.id == id }) else { return }
        for url in cat.fileURLs {
            if !uncategorizedFiles.contains(url) {
                uncategorizedFiles.append(url)
            }
        }
        recentCategories.removeAll { $0.id == id }
        saveRecentFilesAndCategories()
    }

    func confirmAndDeleteCategory(id: UUID) {
        guard let cat = recentCategories.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        let isEnglish = preferences.language == .english
        alert.messageText = isEnglish ? "Delete Folder \"\(cat.name)\"?" : "确认删除文件夹“\(cat.name)”？"
        alert.informativeText = isEnglish
            ? "Files in this folder will be moved to the uncategorized list. No local files will be deleted."
            : "文件夹内的文件将移回未分类列表，不会删除本地文件。"
        alert.addButton(withTitle: isEnglish ? "Delete" : "删除")
        let cancelBtn = alert.addButton(withTitle: isEnglish ? "Cancel" : "取消")
        cancelBtn.keyEquivalent = "\u{1b}"

        if alert.runModal() == .alertFirstButtonReturn {
            deleteCategory(id: id)
        }
    }

    func renameCategory(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = recentCategories.firstIndex(where: { $0.id == id }) else { return }
        recentCategories[idx].name = trimmed
        saveRecentFilesAndCategories()
    }

    func promptRenameCategory(id: UUID) {
        guard let cat = recentCategories.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        let isEnglish = preferences.language == .english
        alert.messageText = isEnglish ? "Rename Folder" : "重命名文件夹"
        alert.informativeText = isEnglish ? "Enter new folder name:" : "输入新文件夹名称："
        alert.addButton(withTitle: isEnglish ? "Rename" : "重命名")
        let cancelBtn = alert.addButton(withTitle: isEnglish ? "Cancel" : "取消")
        cancelBtn.keyEquivalent = "\u{1b}"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = cat.name
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            renameCategory(id: id, newName: input.stringValue)
        }
    }

    func moveFileToCategory(fileURL: URL, targetCategoryId: UUID?) {
        uncategorizedFiles.removeAll { $0 == fileURL }
        for idx in recentCategories.indices {
            recentCategories[idx].filePaths.removeAll { $0 == fileURL.path }
        }

        if let targetId = targetCategoryId, let catIdx = recentCategories.firstIndex(where: { $0.id == targetId }) {
            if !recentCategories[catIdx].filePaths.contains(fileURL.path) {
                recentCategories[catIdx].filePaths.append(fileURL.path)
            }
        } else {
            if !uncategorizedFiles.contains(fileURL) {
                uncategorizedFiles.append(fileURL)
            }
        }

        saveRecentFilesAndCategories()
    }

    func reorderFile(dragged: URL, target: URL) {
        guard dragged != target else { return }

        // Both in uncategorizedFiles
        if let fromIdx = uncategorizedFiles.firstIndex(of: dragged),
           let toIdx = uncategorizedFiles.firstIndex(of: target) {
            uncategorizedFiles.remove(at: fromIdx)
            uncategorizedFiles.insert(dragged, at: toIdx)
            saveRecentFilesAndCategories()
            return
        }

        // Both in the same category
        for catIdx in recentCategories.indices {
            if let fromIdx = recentCategories[catIdx].filePaths.firstIndex(of: dragged.path),
               let toIdx = recentCategories[catIdx].filePaths.firstIndex(of: target.path) {
                recentCategories[catIdx].filePaths.remove(at: fromIdx)
                recentCategories[catIdx].filePaths.insert(dragged.path, at: toIdx)
                saveRecentFilesAndCategories()
                return
            }
        }

        // Dragged from uncategorized to a category's file
        for catIdx in recentCategories.indices {
            if let toIdx = recentCategories[catIdx].filePaths.firstIndex(of: target.path) {
                uncategorizedFiles.removeAll { $0 == dragged }
                for otherIdx in recentCategories.indices {
                    recentCategories[otherIdx].filePaths.removeAll { $0 == dragged.path }
                }
                recentCategories[catIdx].filePaths.insert(dragged.path, at: toIdx)
                saveRecentFilesAndCategories()
                return
            }
        }

        // Dragged from a category to uncategorized target
        if let toIdx = uncategorizedFiles.firstIndex(of: target) {
            for otherIdx in recentCategories.indices {
                recentCategories[otherIdx].filePaths.removeAll { $0 == dragged.path }
            }
            uncategorizedFiles.removeAll { $0 == dragged }
            uncategorizedFiles.insert(dragged, at: toIdx)
            saveRecentFilesAndCategories()
            return
        }
    }

    private func loadRootFolders() {
        let paths = defaults.stringArray(forKey: "rootFolders") ?? []
        rootFolders = paths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { FileNode(url: $0) }
    }

    private func saveRootFolders() {
        defaults.set(rootFolders.map(\.url.path), forKey: "rootFolders")
    }

    // MARK: - Custom Shortcuts
    func shortcut(for id: String, defaultKey: String, defaultModifiers: [String]) -> ShortcutDefinition {
        if let custom = preferences.customShortcuts[id] {
            return custom
        }
        return ShortcutDefinition(id: id, key: defaultKey, modifiers: defaultModifiers)
    }

    func setShortcut(id: String, key: String, modifiers: [String]) {
        preferences.customShortcuts[id] = ShortcutDefinition(id: id, key: key, modifiers: modifiers)
    }

    func resetShortcut(id: String) {
        preferences.customShortcuts.removeValue(forKey: id)
    }

    func resetAllShortcuts() {
        preferences.customShortcuts.removeAll()
    }

    func effectiveTheme(for colorScheme: ColorScheme? = nil) -> EditorTheme {
        if preferences.theme == .system {
            if let cs = colorScheme {
                return preferences.effectiveTheme(for: cs)
            }
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return preferences.effectiveTheme(for: isDark ? .dark : .light)
        }
        return preferences.theme
    }
}

// MARK: - Shortcut Definition
struct ShortcutDefinition: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var key: String
    var modifiers: [String]

    init(id: String, key: String, modifiers: [String]) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
    }

    var eventModifiers: EventModifiers {
        var mods: EventModifiers = []
        for m in modifiers {
            switch m.lowercased() {
            case "command", "cmd": mods.insert(.command)
            case "shift": mods.insert(.shift)
            case "option", "alt": mods.insert(.option)
            case "control", "ctrl": mods.insert(.control)
            default: break
            }
        }
        return mods
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(key.first ?? " ")
    }

    var displayString: String {
        var res = ""
        if modifiers.contains("control") { res += "⌃" }
        if modifiers.contains("option") { res += "⌥" }
        if modifiers.contains("shift") { res += "⇧" }
        if modifiers.contains("command") { res += "⌘" }
        res += key.uppercased()
        return res
    }
}

// MARK: - Global Search Result
struct GlobalSearchResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let lineNumber: Int
    let lineText: String
    let matchRange: Range<String.Index>?
}

// MARK: - Preferences
struct Preferences: Codable, Equatable {
    var editorFontSize: Double = 16
    var editorFontFamily: String = "system-ui"
    var lineHeight: Double = 1.75
    var maxWidth: Int = 740
    var showLineNumbers: Bool = false
    var smartQuotes: Bool = true
    var smartDashes: Bool = true
    var spellCheck: Bool = true
    var autoSave: Bool = true
    var watchFileChanges: Bool = true
    var theme: EditorTheme = .system
    var systemLightTheme: EditorTheme = .liquidGlassLight
    var systemDarkTheme: EditorTheme = .liquidGlassDark
    var customTheme: String = ""
    var imagePasteMode: ImagePasteMode = .copyToAssets
    var language: AppLanguage = .simplifiedChinese
    var defaultSaveLocation: String = ""
    var bottomPadding: Int = 25
    var autoCheckForUpdates: Bool = true
    var customShortcuts: [String: ShortcutDefinition] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        editorFontSize = try values.decodeIfPresent(Double.self, forKey: .editorFontSize) ?? editorFontSize
        editorFontFamily = try values.decodeIfPresent(String.self, forKey: .editorFontFamily) ?? editorFontFamily
        lineHeight = try values.decodeIfPresent(Double.self, forKey: .lineHeight) ?? lineHeight
        maxWidth = try values.decodeIfPresent(Int.self, forKey: .maxWidth) ?? maxWidth
        showLineNumbers = try values.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? showLineNumbers
        smartQuotes = try values.decodeIfPresent(Bool.self, forKey: .smartQuotes) ?? smartQuotes
        smartDashes = try values.decodeIfPresent(Bool.self, forKey: .smartDashes) ?? smartDashes
        spellCheck = try values.decodeIfPresent(Bool.self, forKey: .spellCheck) ?? spellCheck
        autoSave = try values.decodeIfPresent(Bool.self, forKey: .autoSave) ?? autoSave
        watchFileChanges = try values.decodeIfPresent(Bool.self, forKey: .watchFileChanges) ?? watchFileChanges
        theme = try values.decodeIfPresent(EditorTheme.self, forKey: .theme) ?? theme
        systemLightTheme = try values.decodeIfPresent(EditorTheme.self, forKey: .systemLightTheme) ?? .liquidGlassLight
        systemDarkTheme = try values.decodeIfPresent(EditorTheme.self, forKey: .systemDarkTheme) ?? .liquidGlassDark
        customTheme = try values.decodeIfPresent(String.self, forKey: .customTheme) ?? customTheme
        imagePasteMode = try values.decodeIfPresent(ImagePasteMode.self, forKey: .imagePasteMode) ?? imagePasteMode
        language = try values.decodeIfPresent(AppLanguage.self, forKey: .language) ?? language
        defaultSaveLocation = try values.decodeIfPresent(String.self, forKey: .defaultSaveLocation) ?? defaultSaveLocation
        bottomPadding = try values.decodeIfPresent(Int.self, forKey: .bottomPadding) ?? bottomPadding
        autoCheckForUpdates = try values.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? autoCheckForUpdates
        customShortcuts = try values.decodeIfPresent([String: ShortcutDefinition].self, forKey: .customShortcuts) ?? customShortcuts
    }

    func effectiveTheme(for colorScheme: ColorScheme?) -> EditorTheme {
        if theme == .system {
            if colorScheme == .dark {
                return systemDarkTheme.isDark ? systemDarkTheme : .liquidGlassDark
            } else {
                return systemLightTheme.isLight ? systemLightTheme : .liquidGlassLight
            }
        }
        return theme
    }
}

enum AppLanguage: String, CaseIterable, Codable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var locale: Locale { Locale(identifier: rawValue) }
    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }
}

enum EditorTheme: String, CaseIterable, Codable {
    case system = "system"
    case notesLight = "notes-light"
    case notesDark = "notes-dark"
    case liquidGlassLight = "liquid-glass-light"
    case liquidGlassDark = "liquid-glass-dark"
    case githubLight = "github-light"
    case githubDark = "github-dark"
    case dracula = "dracula"
    case solarized = "solarized"

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .notesLight: "备忘录（浅色）"
        case .notesDark: "备忘录（深色）"
        case .liquidGlassLight: "液态玻璃（浅色）"
        case .liquidGlassDark: "液态玻璃（深色）"
        case .githubLight: "GitHub 浅色"
        case .githubDark: "GitHub 深色"
        case .dracula: "Dracula"
        case .solarized: "Solarized"
        }
    }

    var isLight: Bool {
        switch self {
        case .notesLight, .liquidGlassLight, .githubLight, .solarized: true
        default: false
        }
    }

    var isDark: Bool {
        switch self {
        case .notesDark, .liquidGlassDark, .githubDark, .dracula: true
        default: false
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .notesLight, .liquidGlassLight, .githubLight, .solarized: .light
        case .notesDark, .liquidGlassDark, .githubDark, .dracula: .dark
        }
    }

    static var lightThemes: [EditorTheme] {
        [.liquidGlassLight, .notesLight, .githubLight, .solarized]
    }

    static var darkThemes: [EditorTheme] {
        [.liquidGlassDark, .notesDark, .githubDark, .dracula]
    }
}

enum ImagePasteMode: String, CaseIterable, Codable {
    case copyToAssets = "copy-to-assets"
    case keepOriginal = "keep-original"
    case base64 = "base64"
}

// MARK: - Notification Names
extension Notification.Name {
    static let editorCommand = Notification.Name("editorCommand")
    static let exportCommand = Notification.Name("exportCommand")
    static let fileSystemDidChange = Notification.Name("fileSystemDidChange")
    static let fileContentReloaded = Notification.Name("fileContentReloaded")
    static let preferencesDidChange = Notification.Name("preferencesDidChange")
}
