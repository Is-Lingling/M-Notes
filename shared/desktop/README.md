# Windows / Linux 桌面工作区

`index.html`、`desktop.css`、`main.js` 是两个 Tauri 平台的共同界面源码。请修改这里，避免直接修改平台目录里的生成文件。

在 `windows/` 或 `linux/` 中运行 `npm run prepare:ui`，会复制界面和 `shared/editor/`，并使用 esbuild 将 Tauri 官方 JavaScript API 打包到 `src/main.js`。`npm run dev`、`npm run build` 的 Tauri 前置步骤自动执行此操作；CI 直接运行 `npx tauri build` 也会执行。

## 功能

- 原生打开、保存、另存为 Markdown / TXT，文件名兼容 Windows 和 POSIX 路径。
- 大纲导航（忽略代码围栏内的标题）、字符与行数、保存状态、可见错误提示。
- 标题、粗体、斜体、删除线、列表、待办、引用、链接、代码、表格、公式和分隔线；本地图片内嵌为 Data URL。
- 查找、上一个/下一个、区分大小写、替换及全部替换。
- 源码、打字机模式、行号、字号和七种主题选项，设置本地持久化。
- HTML 导出：使用编辑器导出接口渲染公式与 Mermaid；保留内嵌和网络图片，相对路径图片显示缺失说明。
- 新建、打开、关闭前提供保存/不保存/取消；保存失败不会丢弃当前文档。切换文档重新创建编辑器，隔离撤销历史。
- 本地保存一份当前未保存文档的恢复草稿，异常退出后恢复为需要另存为的文档，避免覆盖外部修改的文件。大图片可能触及 WebView 存储配额，失败时会提示手动保存。
- Ctrl+N/O/S、Ctrl+Shift+S、Ctrl+F/H 和 Ctrl+\ 快捷键在 iframe 编辑区内有效。

原生文件访问使用 Tauri dialog/fs 插件，仅授予所需命令权限，路径范围由用户的原生文件对话框选择授予。浏览器预览使用文件选择器和下载替代原生文件操作。

## 验证

在任意平台目录运行：

```sh
npm install
npx playwright install webkit
npm run test:ui
# 也可安装 chromium，然后以 UI_BROWSER=chromium 运行测试。
cargo check --manifest-path src-tauri/Cargo.toml
```

测试覆盖编辑器初始化、大纲、iframe 快捷键、查找替换、图片和 HTML 导出、未保存提示、草稿恢复、主题、源码模式、撤销隔离、640–1100px 布局；模拟 Tauri IPC 验证读写失败、取消保存、TXT、Windows 路径和关闭保护。

这些测试不能替代 Windows WebView2 / Linux WebKitGTK 上的真实原生对话框和安装包验收。文件关联的启动参数加载、多文档标签页和相对路径资源解析尚未实现。

后台节能：失去前台状态后停止全文轮询、保存恢复草稿并暂停预览；连续后台 5 分钟后卸载编辑器 iframe，返回后恢复文档、选择、滚动位置及撤销历史。正在导出、处理未保存提示或输入/图片导入未完成时延后休眠。
