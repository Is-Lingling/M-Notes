# M Notes for macOS 🍏

M Notes 的原生 macOS 版本，基于 SwiftUI 5 + AppKit + WKWebView 深度打造。

## 目录结构
- `MarkdownNotes/`：Swift 源码与资源
  - `App/`：应用入口、生命周期与 AppState
  - `Views/`：SwiftUI 原生界面（侧边栏、工具栏、偏好设置、悬浮查找栏）
  - `Models/`：文档树、分类模型与配置
  - `Services/`：文件监视、UpdateChecker、导出服务
  - `Editor/`：本地加载的所见即所得编辑器资源
- `MarkdownNotes.xcodeproj/`：Xcode 工程
- `project.yml`：XcodeGen 描述文件

## 编译与打包
```bash
# 1. 生成 Xcode 工程 (如修改了 project.yml)
xcodegen generate

# 2. 编译 Release 应用
xcodebuild -scheme MarkdownNotes -configuration Release -derivedDataPath build/Release build

# 3. 运行自动化测试
./scripts/test-mnotes.sh

# 4. 生成 DMG 安装包
./scripts/build-dmg.sh
```
