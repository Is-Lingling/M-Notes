# M Notes for Android 🤖

M Notes 的 Android 移动端原生应用，基于现代 Android 原生架构（Kotlin + AndroidX + Material 3 + WebView）打造。

## 平台特性
- **触控优化所见即所得**：共享 `shared/editor` 核心内核，针对手机和平板触屏排版微调。
- **系统级 Scoped Storage 文档存取**：
  - 通过 Android Storage Access Framework (SAF) 读写本地储存与外部 SD 卡。
  - 支持调用系统文件管理器打开 `.md`、`.markdown`、`.txt` 文件。
- **沉浸式现代体验**：全面支持 Edge-to-Edge 沉浸式状态栏，跟随 Android 系统深色/浅色主题。
- **纯离线安全运行**：所有编辑引擎与依赖库内置于本地 App 资产，无需任何网络请求，隐私安全无虞。

## 构建与运行

### 方式 1：使用 Android Studio
1. 打开 **Android Studio**，选择 `Open` 并选中 `android/` 目录。
2. 等待 Gradle 同步完成。
3. 连接 Android 真机或启动模拟器，点击 **Run** (`Shift+F10`) 即可安装运行。

### 方式 2：使用命令行 Gradle 构建 APK
```bash
cd android

# 1. 编译 Debug 版本 APK
./gradlew assembleDebug

# 2. 生成产物路径：
# android/app/build/outputs/apk/debug/app-debug.apk

# 3. 安装至已连接设备
adb install app/build/outputs/apk/debug/app-debug.apk
```
