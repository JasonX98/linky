# 视频下载器（基于 yt-dlp 的 Flutter Windows 桌面应用）设计文档

- 日期：2026-08-28
- 状态：已与需求方确认的设计定稿
- 项目类型：全新项目（Windows 桌面 GUI）

## 1. 背景与目标

基于开源项目 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 开发一个 Windows 桌面视频下载工具，支持 YouTube、Facebook、Bilibili 等站点。

**产品定位**：公开发布的产品。因此自动更新、完善的错误提示、双语界面、安装包分发均属必备能力。

**v1 功能范围**：

- ✅ 单视频下载（分析 → 选画质 → 下载 → 进度展示）
- ✅ 播放列表/合集批量下载（条目多选）
- ✅ 下载队列（可设并发数、支持取消）+ 本地持久化历史记录
- ❌ 音频提取、字幕下载（留待后续版本）

**明确的技术约束**：YouTube 高画质必须合并独立音视频流，因此捆绑 FFmpeg 是硬需求（并非仅为音频提取预留）。

## 2. 架构方案（已选定）

**方案 A：Process 驱动的 CLI 包装**（已否决：方案 B 嵌入 Python 运行时复杂度高收益为零；方案 C 依赖社区 Dart 包装包，维护风险高）。

Flutter 通过 `Process.start` 启动捆绑的 `yt-dlp.exe`，用其稳定的 JSON 输出与进度模板完成元数据探测和进度解析。这是 yt-dlp GUI 生态（Stacher、yt-dlg 等）的通行集成方式。

### 2.1 架构分层

```
┌──────────────────────────────────────────────┐
│         Flutter UI (Windows 桌面)             │
│   下载页 · 历史页 · 设置页（fluent_ui 导航）   │
├──────────────────────────────────────────────┤
│         业务层 (Riverpod Controllers)         │
│   DownloadQueue  · History  · EngineUpdate   │
├──────────────────────────────────────────────┤
│                服务层                         │
│   YtDlpService    进程启动/生命周期管理        │
│   YtDlpParser     JSON 元数据/进度行解析      │
│   HistoryRepository (SQLite/drift)           │
│   SettingsRepository (shared_preferences)    │
├──────────────────────────────────────────────┤
│   yt-dlp.exe │ ffmpeg.exe │ SQLite │ 用户目录 │
└──────────────────────────────────────────────┘
```

各单元职责与接口：

| 单元 | 职责 | 对外接口 | 依赖 |
|---|---|---|---|
| YtDlpService | 拉起/终止 yt-dlp 子进程，流式回传输出 | `probe(url)`、`download(task, onProgress)`、`cancel(taskId)` | 无（仅依赖引擎文件） |
| YtDlpParser | 纯函数解析 stdout/stderr | `parseVideoJson`、`parsePlaylistJson`、`parseProgressLine`、`mapError` | 无（可独立单测） |
| DownloadQueue | 任务队列、并发控制、状态流转 | `enqueue(task)`、`cancel(id)`、任务状态流 | YtDlpService |
| HistoryRepository | 历史记录持久化 | `add/query/delete/clear` | drift/SQLite |
| EngineUpdate | 引擎版本检查与自更新 | `checkUpdate()`、`applyUpdate()` | GitHub API、文件系统 |
| UI Controllers | 状态管理与界面桥接 | Riverpod Provider | 上述各层 |

## 3. 核心流程

### 3.1 分析

```
yt-dlp --dump-single-json --flat-playlist <url>
```

- 返回含 `_type` 字段：`video` 为单视频；`playlist` 为播放列表（条目经 `--flat-playlist` 轻量枚举，不逐个请求详情）
- 单视频：展示标题、时长、上传者、缩略图、画质预设选择
- 播放列表：展示条目列表（标题+时长），支持全选/反选后批量入队

### 3.2 画质选择（用户视角：画质预设，不暴露原始格式 ID）

| 预设 | yt-dlp 格式选择器 |
|---|---|
| 最佳画质 | `bv*+ba/b` |
| 1080p | `bv*[height<=1080]+ba/b[height<=1080]` |
| 720p | `bv*[height<=720]+ba/b[height<=720]` |
| 480p | `bv*[height<=480]+ba/b[height<=480]` |

统一参数：`--merge-output-format mp4 --ffmpeg-location <bundled>`。

### 3.3 下载与进度

```
yt-dlp -f <selector> --newline
  --progress-template "download:PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_estimate_str)s"
  -o <下载目录>/%(title)s.%(ext)s <url>
```

- Dart 逐行读取 stdout，`PROGRESS|` 前缀行解析出百分比/速度/ETA，驱动 UI 实时刷新
- stderr 末尾数行缓存在任务上，作为失败详情
- 完成 → 写入历史，可打开文件或所在文件夹；失败 → 展示友好错误 + 重试按钮

## 4. 引擎分发与自动更新

- `yt-dlp.exe` + `ffmpeg.exe`（Windows essentials 构建）随安装包捆绑在安装目录 `bin/` 下
- 应用启动时**后台静默**检查（节流：每 24 小时至多一次，记录上次检查时间）：请求 GitHub API `repos/yt-dlp/yt-dlp/releases/latest` → 与本地 `yt-dlp --version` 比对 → 有新版则下载到临时文件 → 校验存在后**原子替换**（先 rename 旧版再换入），替换在下个下载任务启动前完成即可
- 全程不阻塞使用；更新失败静默降级（旧版引擎通常仍可用），设置页提供"立即检查更新"与版本号显示
- **引擎自愈**：启动时校验 `bin/` 下引擎文件存在，缺失/损坏则自动重新下载

## 5. 数据模型

### 5.1 SQLite（drift）—— 历史表

`download_history`：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | int PK 自增 | |
| url | text | 原始链接 |
| title | text | 视频标题 |
| uploader | text? | 上传者 |
| duration_sec | int? | 时长 |
| format_label | text | 画质预设标签 |
| file_path | text? | 完成后的文件路径 |
| file_size | int? | 文件大小（字节） |
| status | text | completed / failed / canceled |
| error_summary | text? | 失败原因（友好文案） |
| created_at | datetime | 入队时间 |
| completed_at | datetime? | 结束时间 |

- 队列任务只存内存；应用关闭时进行中的任务终止，v1 明确接受此限制（恢复下载列为后续增强）
- 单文件并发写通过 drift 单连接保证

### 5.2 设置（shared_preferences）

下载目录、并发数（默认 3，范围 1–5）、默认画质、界面语言（zh/en）、忽略的引擎版本。

## 6. UI 设计（fluent_ui，Windows 11 原生观感）

- 默认窗口约 1000×680，左侧导航栏：**下载 / 历史 / 设置**，关于与免责声明在设置页底部
- **下载页**：顶部 URL 输入框+分析按钮 → 分析结果卡片（单视频：缩略图+标题+画质预设；播放列表：多选条目列表）→"加入下载"；下方任务列表：缩略图、标题、进度条、速度、ETA、取消按钮
- **历史页**：时间倒序，行内操作：打开文件 / 打开文件夹 / 重新下载 / 删除
- **设置页**：下载目录选择器、并发数滑块、默认画质、语言切换、检查更新按钮、免责声明
- **国际化**：第一天即接入 intl，zh + en 两套文案

## 7. 错误处理

| 场景 | 处理 |
|---|---|
| yt-dlp 失败 | 解析 stderr 映射为友好提示（网络超时/视频不可用/地区限制/需要登录），原始输出可在"详情"展开 |
| 磁盘空间不足 | 下载前用元数据预估大小对比目标盘剩余空间，入队前拦截 |
| 引擎缺失/损坏 | 启动自检，自动重新下载修复 |
| 引擎更新失败 | 静默降级 + 设置页手动重试 |
| 分析超时 | 60s 超时终止进程，提示检查网络或链接有效性 |
| Windows 控制台闪窗 | `Process.start` 验证无黑框闪现（Dart 默认 `CREATE_NO_WINDOW`，实现时验证） |

## 8. 测试策略

- **单元测试（重点）**：`YtDlpParser` 以真实 yt-dlp 输出为 fixture（单视频 JSON、flat-playlist JSON、进度行、stderr 样例）；画质预设→格式选择器映射；错误文案映射
- **集成测试**（手动触发，打 tag）：真实调用引擎下载一个小视频验证全链路
- **Widget 测试**：任务列表渲染、历史页增删操作

## 9. 里程碑（每步独立可验证）

1. **M1 引擎跑通**：Flutter 工程 + 捆绑引擎 + CLI 调用完成单视频下载（极简 UI）。风险最高点（进程管理/进度解析/无闪窗）最先验证
2. **M2 队列与主界面**：fluent_ui 框架、分析→选画质→入队→进度展示、取消
3. **M3 完整功能**：播放列表批量、历史持久化、设置页、双语
4. **M4 发布**：自动更新、错误打磨、免责声明、打包安装器（msix）

## 10. 项目结构

```
lib/
  core/          # 常量、工具、错误类型、i18n
  engine/        # YtDlpService / YtDlpParser / 引擎更新
  data/          # drift 历史表、设置仓库
  features/      # download / history / settings（UI + controller）
  main.dart
```

## 11. 合规说明

应用内需展示免责声明：本工具仅供个人学习研究，下载行为请遵守目标网站服务条款及当地法律法规。分发时附带 yt-dlp（Unlicense）与 FFmpeg（LGPL/GPL 构建）的许可说明。
