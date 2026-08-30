# AGENTS.md

Flutter **Windows 桌面端**应用（基于 yt-dlp 的视频下载器，Riverpod + drift/SQLite）。

## 仓库布局要点
- git 仓库根目录即本工程根目录（`DownloadApp/`，分支 `main`，初始提交 `fc7b81c`）。
  Flutter 工程就在仓库根下，无需进入子目录。
- `.workbuddy/`（本地记忆/输出）与 `build/`、`.dart_tool/` 均在 `.gitignore` 中排除，**切勿提交**。
- `assets/bin/` 存放 `yt-dlp.exe`、`ffmpeg.exe`、`ffprobe.exe`，但**不纳入 git**（仅保留 `.gitkeep`）。
  克隆后必须先拉取引擎才能运行。

## 首次环境准备（非显而易见）
- 启用桌面端：`flutter config --enable-windows-desktop`
- **首次运行前必须拉取引擎**（yt-dlp + FFmpeg，约 220MB，不在 git 内）：
  `powershell -ExecutionPolicy Bypass -File tool/fetch_engine.ps1`
- `flutter pub get`

## 常用命令
- 运行 GUI：`flutter run -d windows`
- 全部测试（其中 8 个 e2e 会静默跳过）：`flutter test`
- 单文件测试：`flutter test test/engine/engine_update_test.dart`
- 分析/静态检查：`flutter analyze`（以 warnings-as-errors 为门禁，须保持零告警）
- 重建/运行注意：若 `video_downloader` 进程正在运行，重建会报 "file in use"，需先
  `taskkill /IM video_downloader /F`。
- 发布构建：`flutter build windows --release`
- MSIX：`flutter pub run msix:create --release`（需先执行 `flutter build windows --release`）。
  默认使用内置**测试证书**签名（仅可用于侧载/开发安装）。正式分发需在 `msix_config:` 中（见 README）
  或通过 `--certificate-path/-p` 提供 PFX。

## 测试与 e2e 注意点
- e2e 位于 `test/e2e/`，是**门控**的：仅当设置 `RUN_E2E=1` 才真正运行；否则每个用例以
  "set RUN_E2E=1 to run e2e" 跳过（普通 `flutter test` 显示为 `~8` 跳过，属正常/绿色）。
- 运行 e2e：`$env:RUN_E2E='1'; flutter test test/e2e --concurrency=1`
  必须加 `--concurrency=1`：e2e 文件间会争用系统资源，并发会互相干扰。
- e2e **自包含**：会启动本地限速 HTTP 服务 / 假 GitHub 服务，不需要真实的 `YTDLP_ENGINE_DIR`，也不访问外网。
- **本机环境有 `http_proxy`/`https_proxy=127.0.0.1:8987`，会让 `flutter test` 全部用例以
  `WebSocketException: Invalid WebSocket upgrade request` 启动失败**（flutter_tester 的本地
  WebSocket 被代理劫持）。跑测试前先摘掉代理变量：
  ```
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
      no_proxy="localhost,127.0.0.1" flutter test
  ```

## 国际化（flutter_localizations）
- 配置见 `l10n.yaml`：模板为 `app_zh.arb`，输出类 `S`，`nullable-getter: false`。
- 同时编辑 `lib/l10n/app_zh.arb`（模板）与 `app_en.arb`；用 `flutter gen-l10n` 重新生成。
  通过 `S.of(context)`（或 `S.current`）访问字符串 → `s.someKey`。
- **ARB 文件必须是无 BOM 的 UTF-8。** 带 BOM 会导致 git 对 `generated/` 产生改动噪音，
  且违反无 BOM 约定——切勿以 BOM 写入 ARB。

## UI 主题与通用组件（改界面前必读）
- 设计令牌集中在 `lib/theme/app_theme.dart`（`AppColors` / `AppRadius` / `AppSize` /
  `AppText` / `AppMeta` + `buildAppTheme()`）。**不要在页面里写裸色值**，一律引用令牌。
- 通用组件在 `lib/theme/widgets.dart`：`AppCard`、`AppHeader`、`SectionHeader`、
  `PrimaryButton`、`GhostButton`、`IconTile`、`AppProgressBar`、`AppToggleSwitch`、
  `NumberStepper`、`EmptyState`、`StatusDot`、`FilterTab`、`QualityChip`、`SegmentedPicker`。
  - 命名注意：fluent_ui 自带 `PageHeader`，本项目改叫 **`AppHeader`**，勿混用。
  - `SubtitleLine` 用于"可能为 null 的副标题"，内部自处理 null 后返回
    `SizedBox.shrink()`——直接写 `if (x != null) Text(x)` 会被 `use_null_aware_elements` 告警。
- 令牌是 **const 类而非 ThemeExtension**：这样单测可以脱离 `App` 外壳单独挂载某个页面。
- **key 只挂最外层封装**：`PrimaryButton` / `GhostButton` / `CheckUpdateButton` 等包装件
  若把同一个 key 继续传给内层 fluent 控件，`find.byKey` 会同时命中两个 Element 而报
  "ambiguously found multiple matching widgets"。
- 外壳：`lib/features/shell/` 的 `Sidebar`（232px）+ `appShellIndexProvider`（StateProvider<int>）
  控制页面切换。**已移除 fluent `NavigationView`**——Windows 原生已有标题栏，再用会双标题栏。
- 页面结构统一为：`AppHeader`（76px，含右侧操作）+ `Expanded` 内容区，内容区用
  `Align(topCenter)` + `BoxConstraints(maxWidth: AppSize.contentMax)` 居中，
  列表用 `ListView` 而非 `SingleChildScrollView`，避免窄窗口溢出。

## 引擎更新 / 自愈
- `lib/engine/engine_update.dart` 会向 GitHub 查询更新的 yt-dlp 并以原子方式替换
  （`.new`/`.bak` 交换）。`ensureEngine()` 可自愈：当 `yt-dlp.exe` 缺失**或为零字节**时重新下载。
  更新需要带 GitHub 的 `User-Agent`（在 `EngineUpdateService` 中设置）。
