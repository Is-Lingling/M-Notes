# M Notes for Windows 🪟

M Notes 的 Windows 桌面原生应用，基于现代原生 WebView2 引擎与轻量级桌面容器打造，内存占用低（~30MB），启动速度极快。

## 平台特性
- **Windows 11 原生美学**：支持 Mica (云母) / Acrylic (亚克力) 毛玻璃背景特效与圆角原生窗口。
- **所见即所得编辑器**：共享 `shared/editor` 核心内核，支持实时表格编辑、KaTeX 公式与 Mermaid 图表。
- **系统级文件关联**：直接关联 `.md`、`.markdown`、`.txt` 文件，支持右键打开与双击启动。
- **全套快捷键适配**：全面适配 Windows 键盘映射（`Ctrl+S` 保存、`Ctrl+O` 打开、`Ctrl+N` 新建、`Ctrl+F` 查找）。
- **多种安装方式**：支持单文件绿色便携包（Portable .exe）、NSIS 安装向导（.exe）与企业级 Windows Installer（.msi）。

## 安装方式
1. **下载安装包**：从 GitHub Releases 下载最新的 `M-Notes-Setup-x64.exe` 或绿色便携版。
2. **运行安装**：双击运行安装向导，选择安装目录即可。

## 本地编译与构建
```bash
# 1. 进入 windows 目录并安装依赖
cd windows
npm install

# 2. 本地开发调试运行
npm run dev

# 3. 构建发布安装包 (.exe / .msi)
npm run build
```
编译产物将自动生成于 `windows/src-tauri/target/release/bundle/`。
