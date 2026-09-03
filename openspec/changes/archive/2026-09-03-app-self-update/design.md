# Design: 应用自更新（跳转式）

> 动机与范围见 `proposal.md`。本文件只解释"如何实现"及其取舍。

## Context

- 现状：引擎（yt-dlp / ffmpeg）更新已由 `EngineUpdateService` 实现，采用"GitHub `releases/latest` 拉 tag → `EngineVersion` 比较 → 原子 `.new`/`.bak` 替换"。产品名 Linky，仓库 `JasonX98/linky`。
- 约束：Windows 上运行中的 exe 被锁，无法就地覆盖 → 排除自动替换，采用"检测 + 引导跳转"。
- 当前应用版本来源：`AppMeta.version`（`lib/theme/app_theme.dart`，硬编码 `'1.0.3'`），与 `pubspec.yaml` 的 `version:`、Windows `Runner.rc` 三者需人工同步。
- GitHub release 资产命名历史不统一：`v1.0.1 → Linky-1.0.1-windows-x64.zip`、`v1.0.2 → Linky-1.0.2-win64.zip`、`v1.0.3 → Linky-v1.0.3-windows-x64.zip`。

## Goals / Non-Goals

- Goals：新增一个从设置页触发的"应用更新检测"，检测到新版后展示提示，并引导用户用默认浏览器打开 GitHub release 页。
- Non-Goals：
  - 不实现任何文件替换/回滚/多进程交接（引擎自动替换不扩展到此）。
  - 不做启动时静默检测，维持"只按钮触发"。
  - 不新增运行时依赖（无 `package_info_plus`、无 `url_launcher`）。

## Decisions

### D1: 新建 `AppUpdateService`，不复用 `EngineUpdateService`

独立一个 `lib/features/settings/app_update.dart`，内含 `AppUpdateService` 与轻量 `AppVersion`。

- **理由**：两者职责不同——引擎要"应用更新"（原子替换），应用要"检测 + 跳转"（纯只读）。且 `EngineUpdateService` 的 `httpGet` / `_fetchGitHubTag` 均为私有，`EngineVersion` 专为 yt-dlp 日期式 tag（如 `2026.08.19`）设计，无法解析 `v1.0.3+0` 这类带 `v` 前缀与 `+build` 后缀的版本串。
- **备选**：复用 `EngineUpdateService` 并扩一个方法 → 被拒：会污染引擎职责、强耦合两种语义，且需要对外暴露私有方法。
- **复用点**：`AppUpdateService` 沿用 `EngineUpdateService` 的 UA 设置与"失败降级为 null"的容错思路，但不共享代码。

### D2: 跳转目标用 GitHub API 返回的 `html_url`

调用 `GET /repos/JasonX98/linky/releases/latest`，一次拿到 `tag_name`（用于比较）与该 release 的 `html_url`（用于跳转，形如 `https://github.com/JasonX98/linky/releases/tag/v<x.y.z>`）。

- **理由**：一次请求同时获得版本号 + 发布页链接；`html_url` 是官方字段，稳定。即便后续想展示更新日志（`body`）也顺手。
- **备选**：拼 `https://github.com/JasonX98/linky/releases/latest` → 也有效且不依赖 tag 比对，但拿不到结构化 tag 供比较，需二次解析；不作为主选。

### D3: 打开浏览器用 `Process.start('explorer', [url])`，注入 `openUrl` 回调

- **理由**：Windows 专用、零新增依赖，契合项目已有的原生路线（`ProcessLauncher`、tray、window_manager）。通过构造器注入 `openUrl`（默认用 `Process.start('explorer', [url])`）以便测试替身。
- **备选**：`url_launcher` → 跨平台但引入依赖，本项目仅 Windows，收益低；被拒。

### D4: 当前版本沿用 `AppMeta.version`，不加 `package_info_plus`

- **理由**：跳转式不做实际替换，版本号偶尔漂移只是"是否提示"的影响，酿不成错误；`AppMeta.version` 已在 UI 展示，零改动。若要根治多源同步，作为后续独立事项。
- **备选**：`package_info_plus` 读 exe 文件版本 → 更准但引入依赖与生命周期处理；跳转式下收益不划算，被拒。

### D5: 版本比较用强比较的轻量 `AppVersion`

`AppVersion` 解析时去 `v` 前缀、剥离 `+build` 后缀，按主/次/补丁分段比较（缺段按 0）。

- **理由**：规范（spec.md）定义了强语义比较场景（`v1.0.4` vs `1.0.3+0` → 更新；`v1.0.3` vs `1.0.3+0` → 无更新），需要有确定性的比较而非字符串不等即提示。
- **备选**：弱比较（版本字符串不相等即提示）→ 更简单，但会在"build 号变化但主次补丁相同"时误报更新，与已定义的 spec 场景冲突；被拒。

### D6: UI 挂载在"关于与更新"卡片的应用版本行

在 `settings_page.dart` 的 About 卡片顶部（`aboutVersionLine(AppMeta.version)` 所在行）旁加"检查更新"按钮与结果状态。

- **理由**：应用版本号就显示在这一行，语义相邻；不加新卡片，改动最小。
- **状态承载**：在 `lib/features/settings/providers.dart` 新增 `appUpdateStatusProvider` / `appUpdateCheckingProvider`（`StateProvider`），复刻现有引擎检查更新的一套状态模式（`engineUpdateStatusProvider` / `engineUpdateCheckingProvider`），并提供独立的总超时兜底（仿 `runEngineUpdateCheck` 的 `timeout`）。
- **触发**：只按钮触发；无新版显示"已是最新版本"，新版显示"发现新版本 vX（当前 vY）+【前往更新】"，失败显示友好错误。

### D7: 统一发布命名规范并写入 `AGENTS.md`

在 `AGENTS.md` 的"发布构建"小节补充规范表：

| 项 | 规范 | 示例 |
| --- | --- | --- |
| Release tag | `v<semver>` | `v1.0.4` |
| Release 标题 | `Linky v<semver>` | `Linky v1.0.4` |
| zip 资产 | `Linky-v<semver>-windows-x64.zip` | `Linky-v1.0.4-windows-x64.zip` |
| 版本号来源 | `pubspec.yaml` 的 `version:`（去 `+build`），与 `AppMeta.version` 一致 | `1.0.4` |
| 更新日志 | `release/release_notes_v<semver>.md` + `release/payload.json` | 沿用现有 |

- **理由**：历史发布命名不一（`-win64.zip` / `-windows-x64.zip` / 有无 `v`）。规范它，消除"直接下载链接"类的隐患（本变更虽不写死下载链接，但统一规则降低成本与歧义）。
- **生效点**：`README.md` 等如涉及发布产物命名一并校对（可选）。

## Risks / Trade-offs

- [GitHub API 未认证限流（60 req/h）] → 沿用引擎现有容错：仅按钮触发、失败降级为友好错误，不阻塞应用。单靠此按钮触发，量级远低于限流。
- [`explorer` 启动方式在个别环境不可用] → 已注入 `openUrl`；默认 `Process.start('explorer', ...)` 失败时回退到 `curl`/`cmd start` 或报错提示，用 `openUrl` 统一兜底。
- [`AppMeta.version` 与 pubspec 不同步导致误报/漏报] → 影响仅限跳转式"提示是否出现"，不破坏数据或文件；治理多源同步作为后续独立事项（D4 已注明）。
- [不同步发布命名导致规范落空] → `AGENTS.md` 规范表 + README 校对作为本变更必含任务，确保下次发布遵守。

## Migration Plan

- 纯新增能力 + 文档，无数据迁移、无回滚需求（改动不动任何本地文件）。
- 部署：随下次 release 内置；`AGENTS.md` 规范表在实现阶段写入。
- 兼容性：不影响现有引擎更新流程；两者独立，可并行存在。

## Open Questions

- 是否要在"发现新版本"提示中同时展示 `body`（更新日志）摘要，而非仅版本号？→ 不影响 spec / 方案 / 任务拆分，实现时按 UI 需要取舍即可。
- "检查更新"按钮是否与已有引擎更新按钮并排为两枚，还是合并为一次统一检查？→ 本变更先做独立的一枚（职责清晰）；合并与否属 UI 微调，可延后。
