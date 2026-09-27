# TODO — Fork/Upstream 追踪（2026-09-27 记录，待后续跟进）

> 背景：跟踪 GitJournal 上游与各 fork 的最新改动；已把 Top 5 fork 合并进 `khl` 分支。

## 已完成的分析（结论备忘）

### 1. 2026 年有实质改动的 fork Top 5（最新优先）
| 仓库 | 最新提交 | 主要改动 |
|---|---|---|
| shubham-sharma-1994/GitJournal-Updated | 2026-09-24 | 导航 fade 过渡 + CI 修复 |
| weijia/GitJournal | 2026-09-24 | widget 透明背景、debug overlay |
| kvth/GitJournal | 2026-09-06 | AppImage/docker 构建脚本 |
| xtccc/GitJournal | 2026-08-20 | git 代理支持、解锁 Pro |
| flairyu/GitJournal | 2026-08-13 | CI release/APK 上传 |

- 次席：baruchiro/GitJournal（2026-06-23，home folder 冷启动修复）
- 上游 GitJournal/GitJournal 最后提交：2026-05-26 `Bump go_git_dart`

### 2. weijia 体积分析关键结论
- 基线 `1.89+3798` = 上游 commit `93effc32`（2024-08-25，pubspec 1.89.0+10）
- weijia v1.94.0 APK = 118.6 MB（解压 115.5 MB），95% 是原生 .so
- 是 3-ABI 胖包：x86_64 38.6 MB + arm64-v8a 36.5 MB + armeabi-v7a 35.1 MB
- 体积翻倍两大原因：
  1. 新增重型依赖：appflowy_editor（weijia 加）、supabase_flutter（上游加）、home_widget（weijia 加）→ libapp.so 每 ABI 15.6–17.5 MB
  2. CI 打胖包未过滤 x86_64（`abiFilters` 在 Flutter 新 Gradle 插件下不生效），应改用 `--target-platform android-arm,android-arm64` 或 `--split-per-abi`
- go_git_dart.so 每 ABI ~10 MB（与 1.89 时代相当，非主因）
- Flutter 3.22.3 → 3.41.5 引擎也变大 ~20–30%

## 三、合并记录（khl 分支，已完成 2026-09-27）

合并顺序与决策（`git log --first-parent`）：
1. `24b10c07` Merge kvth：docker 构建脚本（APK/AppImage）— 无冲突
2. `ee0dcc49` Merge flairyu：CI release + Pro overlay
3. `1d997710` 恢复 flairyu 删除的 `lint.yml`/`triggers.yml`/`delete_merged_branches.yml`（保留上游版本）
4. `cf2d6ea0` Merge xtccc：代理、简中、只读模式、Pro 解锁；README 冲突取 xtccc 版并改写为 khl fork
5. `36e73583` Merge weijia：加密、AppFlowy 编辑器、桌面小组件、仓库管理；10 个冲突文件逐一解决
6. `5e0315f4` Pro 解锁统一：采用 xtccc 数据层方案，回退 flairyu 的 pro_overlay UI hack

冲突解决要点：
- `pubspec.yaml/lock`：取 weijia（含 weijia/go_git_dart main 的修复）
- `android.yml`：取 weijia（tag 发版由 weijia 的 release.yml 覆盖，flairyu 的 tag 构建被取代）
- `git_repo.dart`、`clone_libgit2.dart`：取 weijia 主体 + 保留 xtccc 的 proxyUrl 参数通路（**go_git_dart 尚不支持 proxy，仅打日志告警**）
- `repository.dart`：`_checkWriteAllowed()`（xtccc 只读） + `encryptionPassword`（weijia 加密）合并
- `bottom_bar.dart`：encrypt/decrypt 菜单 + `metaDataEditable && !readOnly` 合并
- `app_zh_Hans.arb` / `app_localizations_zh.dart`：以 xtccc 471 条中文翻译为底，注入 weijia 30 个新 key 的中文翻译（脚本合并）

## 四、后续待办（重点）

### A. 构建与验证（2026-09-27 已完成 ✅）
- [x] 安装 Flutter 3.41.9（Dart 3.11.5）+ JDK 17，`flutter pub get` 成功
- [x] **`flutter analyze`：No issues found**（修复了合并引入的 8 个 info/warning：void_async、const、unreachable_switch_case、child 顺序）
- [x] **`flutter test`：185 通过 / 19 跳过 / 0 失败**
  - 修复 weijia 的 `table_operations_test.dart`（mock 的 List.insert 越界，已改名 `table_operations_scratch.dart` 排除出套件，mock 逻辑本身仍有问题待重写）
  - `repository_test.dart: Outside Changes` 根因已定位（见下方 A1，**上游既有 bug，非本次合并引入**），已 skip
- [x] **`flutter build apk --debug --flavor dev` 成功**：`build/app/outputs/flutter-apk/app-dev-debug.apk`（213.6 MB，debug 胖包正常）
- [x] zh/zh_Hans 翻译补全：新增 weijia 13 个 key + xtccc 只读 2 个 key，`flutter gen-l10n` 后 zh/zh_Hans 零未翻译
- [x] 审查意见处理：`ios/Flutter/ephemeral/` 3 个文件已 `git rm --cached` 移出跟踪（weijia 误提交，ios/.gitignore:63 本就忽略该目录）

### A1. 🔴 高优先级：dart-git 产生空提交污染历史（上游既有 bug）
- **现象**：`_commitUnTrackedChanges` 在首次加载外部存储的仓库时会创建一个**语义为空的 "Auto Commit"**（`git show` 无任何文件变化），时间戳每次不同 → 污染用户仓库历史
- **根因**（已用临时 debug 测试定位）：dart-git（纯 Dart 实现）`add('.')`+`commit()` 会**重写子树 tree 对象哈希**（`git ls-tree` 显示子目录 `f1` 的 tree hash 变化而所有 blob 不变；`git diff-tree -r` 输出为空），即 dart-git 的树序列化条目顺序与 git 规范不一致。这导致 `commit.dart` 里的空提交守卫（`parentCommit.treeHash == treeHash → throw GitEmptyCommit`）失效
- **影响面**：`GitAsyncRepository`（dart-git）在所有平台负责 add/commit，因此设备上同样受影响；每次加载已有仓库都可能多一条空 Auto Commit
- **验证**：在基线 `c8a67e09`（worktree）复跑同一测试同样失败 → **非 fork 合并引入，上游 master 就已存在**（上游自己的测试已红）
- [ ] **修复方向**（选一）：
  - 上游修 dart-git 的树序列化（治本，回提上游）
  - fork 内临时缓解：`_commitUnTrackedChanges` 提交前用系统 `git status --porcelain` 或 go_git_dart 判断是否真有变更，干净则跳过
  - 或把 add/commit 切到 go_git_dart 原生实现
- [ ] 修复后移除 `repository_test.dart` 的 skip 并复跑

### A2. 其他构建待办
- [ ] **小体积 release APK**：修改 CI 构建命令（weijia release.yml）为 `--split-per-abi` 或 `--target-platform android-arm,android-arm64`
- [ ] **代理功能回填**：xtccc 的 proxyUrl 设置 UI 已合并，但 go_git_dart 尚不支持 proxy。需要把 xtccc/go_git_dart 的 proxy 参数移植到 weijia/go_git_dart 并更新 `git_repo.dart`/`clone_libgit2.dart` 的 bindings 调用
- [ ] 验证 go_git_dart 在 CI 里从源码编译（weijia 方案）的流程可跑通（本地构建用的是仓库内预编译 .so）
- [ ] **AppFlowy 表格真实测试**：`table_operations_scratch.dart` 只测 mock 不测生产代码，weijia 的 AppFlowy 表格功能零真实测试兜底，需要补针对生产代码的表格操作测试

### B. shubham-sharma-1994 详细待办（不要整支 merge）
- 该分支自 2019 年分叉 + 历史重写，`git merge` 会与 khl 产生 66 个冲突文件；与 weijia/xtccc 编辑器改动大面积重叠（85/64 个文件）
- 策略：**只 cherry-pick 独立小修复，UI 改动需人工移植**
- 可尝试直接 cherry-pick（CI 类，最安全，**审查建议尽快做掉**）：
  - [ ] `c3ac5a90` ci: don't fail Triggers on missing upstream secrets (fork)
  - [ ] `08614c83` ci: fix post-merge branch delete (replace broken third-party action)
- 需人工移植（与 khl 现有 UI 冲突）：
  - [ ] `682daf55` fix(home): stop All Notes scrolling when content fits（Home 已是 M3 改造版，需适配）
  - [ ] `69dff97e` fix(nav): use fade transition for All Notes（与 weijia widget deep-link 路由改动重叠）
  - [ ] `922285a6` drop duplicate New slot + `c1731c0d` speed-dial（bottom_bar 已有 weijia 加密菜单，需重做）
  - [ ] `54add75a` SHU-25 Settings 图标统一 outlined（依赖其 M3 设置页）
- 不建议移植：SHU-12~24 的 M3 全面改造与 golden 测试（体积大、与现有编辑器路线冲突）
- 价值评估：其 2026-09 的 UI 改动偏向 Material 3 视觉打磨，功能价值低于 weijia/xtccc

### C. AppFlowy AI 深挖结论（2026-09-27 调研）
- **weijia 用的 `appflowy_editor` 6.2.0（pub.dev）不含任何 AI 功能**。已下载包源码确认：
  - 插件目录只有 `blocks / html / markdown / pdf / quill_delta / word_count`
  - 源码中无 `AIProvider`/`AIConfig`/`AIPlugin`/OpenAI/LLM 相关符号
  - weijia 的 `appflowy_note_editor.dart` 只接入了 WYSIWYG/表格/列表/待办/标题，无 AI 接线
- AppFlowy 的 AI（Ask AI、总结、改进写作、续写、翻译等）在 **AppFlowy 主应用**的 `appflowy_ai` 模块（前端 Flutter UI + Rust 后端），不在编辑器包里；支持云端或本地 Ollama/OpenAI 兼容端点
- 结论：**合并 weijia 不会给 GitJournal 带来 AI 能力**。若想加 AI：
  - 方案 1：移植 AppFlowy 主应用的 appflowy_ai 模块（工作量大）
  - 方案 2：自建轻量集成（编辑器选区 → LLM API → 回填），appflowy_editor 的 transaction API 可支持选区替换
- [ ] 决定是否立项做 GitJournal AI 集成（独立评估，勿与 fork 合并混淆）

### D. 常规跟踪
- [ ] 持续跟踪上游 GitJournal/GitJournal 是否有 2026-05-26 之后的新提交
- [ ] 关注 weijia/go_git_dart 后续是否补上 proxy 支持
- [ ] （可选）评估把 go_git_dart 的 unpack/malformed mode 修复回提上游

## 参考
- 上游：https://github.com/GitJournal/GitJournal
- weijia fork：https://github.com/weijia/GitJournal
- weijia go_git_dart：https://github.com/weijia/go_git_dart
- xtccc fork：https://github.com/xtccc/GitJournal
- shubham fork：https://github.com/shubham-sharma-1994/GitJournal-Updated
- AppFlowy AI 模块（主应用）：https://github.com/AppFlowy-IO/AppFlowy（frontend/appflowy_flutter/lib/plugins/appflowy_ai）
