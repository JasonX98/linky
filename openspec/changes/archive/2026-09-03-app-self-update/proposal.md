## Why

应用本体（Linky）目前没有入口能发现新版本——引擎（yt-dlp / ffmpeg）支持检查更新，但程序本身的新版本只能靠用户手动访问 GitHub 才知道。需要一个轻量的"应用自更新"能力：检测 GitHub 是否有新版本，并把用户引导到 release 页自行下载更新，而不是贸然替换本机文件。

选择"跳转式"而非"自动替换"，是因为 Windows 上无法覆盖正在运行的 exe，自动替换需要额外的 updater 进程、写安装目录权限与回滚机制，复杂度和风险都远高于"检测 + 引导下载"。跳转式不触碰任何本地文件，几乎零风险，且能复用现有引擎的"检测"管线思路。

## What Changes

- 新增**应用更新检测**：在设置页"关于与更新"卡片的应用版本行旁增加"检查更新"按钮，点击后调用 GitHub `releases/latest` 获取最新 tag 与 release 页 URL。
- 检测到新版本后，UI 显示"发现新版本《最新版本号》（当前《当前版本号》）"，并提供【前往更新】按钮，用默认浏览器打开 GitHub release 页；已是最新或检测失败时给出对应状态文案。
- 新增 `AppUpdateService`（独立于 `EngineUpdateService`），内含轻量 `AppVersion` 版本比较，能正确处理 GitHub tag 的 `v` 前缀与 pubspec 版本的 `+build` 后缀。
- 统一 GitHub release 发布命名规范（tag `v<semver>`、标题 `Linky v<semver>`、zip 资产 `Linky-v<semver>-windows-x64.zip`），并写入 `AGENTS.md` 的"发布构建"小节。
- 非目标（明确排除）：
  - **不**实现应用自身文件的自动替换 / 覆盖 / 回滚（不做多进程交接）。
  - **不**做启动时静默检测 —— 维持"只按钮触发"，与现有引擎检查更新节奏一致。
  - **不**新增 `package_info_plus` 依赖 —— 当前版本沿用已有的 `AppMeta.version`。

## Capabilities

### New Capabilities

- `self-update`: 应用本体更新检测——读取当前版本、拉取 GitHub 最新 release、比较并提示用户，引导打开 release 页。行为覆盖"检测"与"跳转"，不覆盖任何文件的自动替换。

### Modified Capabilities

无。引擎更新能力（yt-dlp / ffmpeg）行为不变。

## Impact

- **新增代码**：`lib/features/settings/app_update.dart`（`AppUpdateService` + `AppVersion` 比较 + `openReleasePage`）。
- **状态管理**：`lib/features/settings/providers.dart` 增加 `appUpdateStatusProvider` / `appUpdateCheckingProvider`。
- **UI**：`lib/features/settings/settings_page.dart` 的"关于与更新"卡片（应用版本行），增加"检查更新"按钮与结果展示。
- **打开浏览器**：`Process.start('explorer', [url])`（Windows 专用、零新增依赖）；测试中可通过注入的 `openUrl` 回调替换。
- **文档**：`AGENTS.md` 增加统一 release 命名规范；`README.md` 视需要同步。
- **测试**：`test/` 新增 `AppUpdateService` 检测/比较/跳转的单测（注入 `fetchLatest` / `openUrl`）。
- **依赖**：无新增。
