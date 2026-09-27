<p align="center">
  <img width="400" height="auto" src="https://gitjournal.io/images/logo.png">
  <br/>基于 Git 的移动端优先 Markdown 笔记应用（Fork 版）
</p>

# GitJournal（khl Fork）

GitJournal 是一个注重隐私和数据可移植性的笔记应用。所有笔记以标准的 Markdown + YAML 头（可选）格式存储，数据保存在你自己选择的 Git 仓库中（GitHub / GitLab / Gitea / 自建服务等），完全自主可控。

本仓库是 [GitJournal/GitJournal](https://github.com/GitJournal/GitJournal)（AGPL-3.0）的一个个人 fork（khl 维护），在保留上游全部功能的基础上，做了以下修改：

## 本 Fork 的修改

| 修改 | 说明 |
|------|------|
| **简体中文界面** | 上游的中文翻译文件从未实际翻译（471 条字符串几乎全是英文占位）。本 fork 已将 `lib/l10n/app_zh_Hans.arb` 全部 471 条翻译为简体中文，并修复了 locale 解析 bug（`zh_Hans` 被错误当作国家码、`Locale('zh')` 英文模板条目遮蔽中文翻译），系统语言为中文时 UI 自动全中文 |
| **只读模式** | 设置 → 编辑器 → 「只读模式」。开启后**不能以任何方式**修改/删除/创建笔记：编辑框锁定、左滑删除禁用、删除/重命名/移动/标签/新建入口全部隐藏，数据层（`repository.dart`）统一拦截兜底。Git 同步仍可 pull，但本地 commit/push 被跳过 |
| **Pro 功能解锁** | 本 fork 默认解锁全部 Pro 功能（主屏幕选择、外部存储、自定义元数据、标签页、禅模式、KaTeX 渲染等），跳过 Google Play IAP 验证，无需内购 |
| **一键构建脚本** | `build.sh`：编译 + 安装一条命令（详见下文） |

## 构建环境

已在 Arch Linux x86_64 上验证通过（2026-08）：

| 组件 | 版本 | 说明 |
|------|------|------|
| Flutter | 3.41.9（stable） | **不要用 3.44+**：该版本把 `IconData` 变为 final class，与 `font_awesome_flutter 10.x` 不兼容 |
| JDK | 17（`/usr/lib/jvm/java-17-openjdk`） | Gradle/AGP 专用；系统默认 JDK 26 会导致 Gradle 8.12 失败 |
| Android SDK | `~/Android/Sdk` | platform-36、build-tools 36.0.0、NDK 28.2.13676358、cmake 3.22.1 |
| ninja | 系统包 | NDK 构建必需 |
| Gradle | 8.12（wrapper 自动下载） | 代理配置在 `~/.gradle/gradle.properties` |

首次配置要点（Arch Linux）：

```bash
# 1. 系统包
sudo pacman -S --needed jdk17-openjdk ninja

# 2. Flutter（固定 3.41.9，勿升级）
git clone -b stable https://github.com/flutter/flutter.git ~/flutter
cd ~/flutter && git fetch origin tag 3.41.9 --depth 1 && git checkout 3.41.9
export PATH="$HOME/flutter/bin:$PATH"

# 3. Android SDK（下载 cmdline-tools 解压到 ~/Android/Sdk/cmdline-tools/latest）
#    然后安装组件并接受许可：
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "cmake;3.22.1"
yes | sdkmanager --licenses

# 4. 配置 Flutter 与 Gradle
flutter config --android-sdk ~/Android/Sdk --jdk-dir /usr/lib/jvm/java-17-openjdk
echo "org.gradle.java.home=/usr/lib/jvm/java-17-openjdk" >> ~/.gradle/gradle.properties

# 5. 拉取依赖
cd GitJournal && flutter pub get
```

## 编译与安装

```bash
./build.sh            # 编译 prod release 并安装到手机（默认）
./build.sh build      # 仅编译
./build.sh install    # 仅安装到已连接设备
./build.sh dev        # dev debug 版（包名带 .dev 后缀，可与正式版共存）
./build.sh build -f dev -m debug   # 自定义 flavor/模式
```

- 产物路径：`build/app/outputs/flutter-apk/app-prod-release.apk`
- 环境变量覆盖：`FLUTTER_BIN`、`ADB`
- 调试日志：`flutter analyze` / `flutter gen-l10n`

### 签名说明

- 仓库中 `android/secrets/` 下的正式签名文件是 **git-crypt 加密**的，无密钥时不可用
- 本地开发构建使用 `android/app/local123`（自动生成、已 gitignore），密码均为 `local123`，仅用于本地安装测试
- 正式发布需使用自己的 keystore，并将 `android/secrets/key.properties` 替换为明文内容

### 已知问题

- 安装到小米等设备时如提示 `INSTALL_FAILED_USER_RESTRICTED`，请在手机上确认 USB 安装授权弹窗
- 设备上已安装更高版本号的应用时，`adb install` 会拒绝降级，需先卸载旧版或用 `./build.sh dev`
- 构建时会有少量 l10n "untranslated messages" 警告，不影响产物

## 上游信息

- 上游项目：[GitJournal/GitJournal](https://github.com/GitJournal/GitJournal)
- 上游文档：[BUILD.md](BUILD.md)、[docs/](docs/)
- 上游社区：问题反馈请到上游仓库提交 [Issue](https://github.com/GitJournal/GitJournal/issues/new)

## 许可证

Vishesh Handa（上游作者）贡献的代码采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) 许可，其他贡献者的代码采用 Apache License 2.0。本 fork 遵循相同许可。

文档（包括本文件）和翻译采用 <a rel="license" href="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</a>。
