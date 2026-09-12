# M Notes 共享核心模块 (Shared Core)

本目录包含 M Notes 全平台（macOS、iOS、Windows、Linux、Android）共享复用的核心资产与编辑器引擎：

- **`editor/`**：基于 CodeMirror 6 构建的现代化所见即所得 Markdown 与纯文本编辑引擎。
  - `editor.html` / `editor.js` / `editor.css`：核心编辑与渲染调度器。
  - `themes.css` & `themes/`：预编译的 6 套官方主题（液态玻璃浅色/深色、Dracula、Solarized、GitHub 浅色/深色）。
  - `katex/`：数学公式排版库。
  - `mermaid/`：图表与架构流程图渲染引擎。
  - `highlight/`：数十种代码语法高亮引擎。
  - `markdown-it/`：CommonMark 与 GFM 解析引擎。
- **`assets/`**：跨平台通用的图标、矢量图形与品牌徽标资源。

各平台容器（macOS/iOS 的 WKWebView、Android 的 WebView、Windows 的 WebView2、Linux 的 WebKitGTK）直接挂载此目录下的编辑器资源运行。
