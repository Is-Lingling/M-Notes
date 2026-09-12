# M Notes for iOS & iPadOS 📱

M Notes 的 iOS / iPadOS 移动端原生应用，基于 SwiftUI 5 + UIKit + WKWebView 深度打造。

## 核心特性
- **iPhone / iPad 响应式自适应**：
  - iPhone：紧凑单列流线型视图，顶部集成文档标题与操作菜单，支持滑动返回。
  - iPad：双列分屏浏览（NavigationSplitView），完美支持 iPadOS 分屏（Split View）与台前调度（Stage Manager）。
- **移动端辅助输入工具条 (Keyboard Accessory Bar)**：
  - 虚拟键盘弹出时，顶部常驻触控格式栏：`# 标题`、`** 粗体`、`* 斜体`、`- 清单`、`[x] 待办`、`$$ 公式`、`表格`、`撤销/重做`。
- **系统文件 App 集成**：
  - 支持直接打开「文件 (Files)」App、iCloud Drive、本地文稿中的 `.md` 与 `.txt` 文件，实时双向保存。
- **所见即所得编辑器同步**：
  - 共享 `shared/editor` 的核心编辑器引擎与 6 套官方主题（支持跟随 iOS 系统深色模式秒级自动切换）。

## 构建与运行
```bash
# 1. 切换到 ios 目录
cd ios

# 2. 通过 XcodeGen 生成 iOS 原生工程
xcodegen generate

# 3. 在 Xcode 中打开工程或通过命令行编译
xcodebuild -scheme MNotesIOS -destination "generic/platform=iOS" -configuration Release build
```
