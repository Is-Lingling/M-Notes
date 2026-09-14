# M Notes for Linux 🐧

M Notes 的 Linux 桌面原生应用，支持主流发行版（Ubuntu、Debian、Fedora、Arch Linux 等），基于 WebKitGTK 原生渲染内核打造。

## 平台特性
- **支持现代 Linux 桌面环境**：完美兼容 GNOME、KDE Plasma、XFCE 等桌面环境与深色外观模式。
- **丰富的打包分发格式**：
  - **AppImage**：免安装、全环境即点即用单文件可执行包。
  - **.deb**：适用于 Ubuntu / Debian 系统的原生安装包。
  - **tar.gz**：通用 Linux 二进制归档。
- **系统文件与桌面集成**：内置 `.desktop` 启动器规范，自动注册 `text/markdown` 与 `text/plain` 默认打开方式。
- **轻量极速**：启动时间 < 0.3s，运行内存约 40MB。

## 安装与运行

### 方式 1：使用 AppImage（免安装推荐）
```bash
# 1. 赋予执行权限
chmod +x M-Notes-x86_64.AppImage

# 2. 直接双击或终端运行
./M-Notes-x86_64.AppImage
```

### 方式 2：Debian / Ubuntu (.deb 安装)
```bash
sudo dpkg -i m-notes_1.0.6_amd64.deb
sudo apt-get install -f
```

## 本地编译与构建
```bash
# 1. 安装系统依赖 (Ubuntu/Debian)
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev

# 2. 进入 linux 目录并安装依赖
cd linux
npm install

# 3. 构建 AppImage 与 .deb 包
npm run build
```
产物将自动生成于 `linux/src-tauri/target/release/bundle/`。

## 桌面工作区

现提供大纲、格式工具、图片嵌入、查找替换、HTML 导出、主题设置、未保存保护及草稿恢复。两平台共用 `shared/desktop/` 源码，构建前自动同步。详见 [工作区功能与测试说明](../shared/desktop/README.md)。
