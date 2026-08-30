# UI 改版计划（对齐 Video-Downloader 原型v1）

原型来源：`D:\Documents\AgentSpace\WorkBuddySpace\Video-Downloader\{home,history,settings}.html`
目标：把现有"功能可用但简陋"的 fluent 界面，改造成原型定义的深色 / 青色 / 卡片式界面。
**范围仅限 UI 层**：provider、仓储、引擎、解析逻辑一律不动。

---

## 一、现状差距

| 维度 | 现状 | 原型目标 |
| --- | --- | --- |
| 主题 | fluent 默认**浅色** + Indigo 强调色 | 深色（`#0B1120`）+ 青色 `#22D3EE` |
| 导航 | `NavigationView` + 内嵌 `TitleBar`（与原生标题栏重复成"双标题栏"） | 232px 自绘侧边栏：Logo + 3 项 + 版本 chip |
| 页面头 | 无，只有 `ScaffoldPage` | 76px 头部：20px 标题 + 12px 副标题 + 右侧操作按钮 |
| 下载页 | 单行输入框 + 画质下拉 + 卡片列表 | 大输入卡（h50 输入 + 130px 主按钮）+ 解析预览卡（缩略图 / 来源 / 画质 chip）+ 任务卡（48px 图标块 / 百分比 / 进度条 / 速度·剩余 / 图标操作） |
| 历史页 | 平铺 Card + 4 个文字按钮 | 计数徽标 + 筛选 tab + 表头 + 表格式行（9×9 图标块）+ 空态 |
| 设置页 | 单列表单 + Slider + ComboBox | 180px 二级分区导航 + 分组卡（分隔线）+ 开关 / 步进器 / 分段语言选择器 |

## 二、设计令牌（新增 `lib/theme/app_theme.dart`）

```dart
class AppColors {                       // 直接取自原型 hex
  static const bgBase      = Color(0xFF0B1120);  // 主背景
  static const bgSurface   = Color(0xFF0F172A);  // 侧边栏 / 头部
  static const bgCard      = Color(0xFF131C2E);  // 卡片
  static const bgTrack     = Color(0xFF1E2A40);  // 进度条底 / 关闭态开关
  static const border      = Color(0x12FFFFFF);  // white/7%  描边
  static const borderInput = Color(0xFF2A3A52);  // 输入框描边
  static const accent      = Color(0xFF22D3EE);  // 主色
  static const accentHover = Color(0xFF67E8F9);
  static const onAccent    = Color(0xFF06222A);  // 主色上的文字
  static const success     = Color(0xFF4ADE80);
  static const successText = Color(0xFF86EFAC);
  static const danger      = Color(0xFFEF9B83);
  static const textPrimary = Color(0xFFE6F1FF);
  static const textBody    = Color(0xFFA9B8D0);
  static const textSecond  = Color(0xFF94A8C4);
  static const textMuted   = Color(0xFF7C8CA8);
  static const textDim     = Color(0xFF5A6B85);
}
// 尺寸：侧边栏 232 / 头部 76 / 内容最大 1120 / 页面内边距 40 / 导航项 44 /
//       输入控件 50 / 卡片圆角 16 / 控件圆角 12 / 小控件圆角 8 / 进度条 6
```

`buildAppTheme()` 返回 `FluentThemeData(brightness: Brightness.dark, accentColor: 青色 swatch,
scaffoldBackgroundColor: bgBase, cardColor: bgCard, menuColor: bgSurface, micaBackgroundColor: bgSurface, …)`，
其余无法用主题表达的部分统一走 `AppColors` 常量。

## 三、通用组件（新增 `lib/theme/widgets.dart`）

`AppCard`（圆角 16 + 1px 描边 + bgCard）· `PageHeader`（76px 标题区）· `SectionTitle`
`PrimaryButton`（青底深字）· `GhostButton`（描边按钮）· `IconTile`（48/36/32 方形图标块）
`AppProgressBar`（6px 圆角）· `AppToggleSwitch`（36×20）· `NumberStepper`（− 值 +）· `EmptyState` · `StatusDot`

## 四、文件级改动

| # | 文件 | 动作 | 说明 |
| --- | --- | --- | --- |
| 1 | `lib/theme/app_theme.dart` | 新增 | 颜色 / 圆角 / 间距令牌 + 深色主题 |
| 2 | `lib/theme/widgets.dart` | 新增 | 上表通用组件 |
| 3 | `lib/features/shell/sidebar.dart` | 新增 | Logo（渐变块 + `FluentIcons.download`，避免使用原型 logo.png 的版权/资源注册问题）+ Linky/链可 + 3 个导航项（选中态：左侧 3px 青色指示条 + `#16233A` 底）+ 底部版本 chip |
| 4 | `lib/features/shell/app_shell.dart` | 重写 | `Row[Sidebar(232), Expanded(PageHeader + 页面)]`；**移除 `NavigationView` 与内嵌 `TitleBar`**（WS_OVERLAPPEDWINDOW 原生标题栏已存在，原型也没有第二层标题栏）。导航文案继续复用 `s.navDownload / navHistory / navSettings` |
| 5 | `lib/features/download/download_page.dart` | 布局重写 | 见第五节 |
| 6 | `lib/features/history/history_page.dart` | 重写 | 见第六节 |
| 7 | `lib/features/settings/settings_page.dart` | 重构 | 见第七节 |
| 8 | `lib/main.dart` | 小改 | 深色主题 + `title: 'Linky'`（与 msix 的 display_name 对齐） |
| 9 | `lib/l10n/app_zh.arb` / `app_en.arb` | 追加 | 约 25 条新文案，`flutter gen-l10n` 重新生成 |
| 10 | `test/ui/*.dart` | 视分区方案更新 | 见第八节 |

## 五、下载页（home.html）

- **输入卡**：`视频链接` 标签 → 50px 输入框（地球图标 + 占位文案 + 有内容时出现清除按钮）→ 130px `解析链接` 主按钮 → 下方状态行（默认提示 / 解析中转圈 / 成功变绿 / 失败走 `ErrorMessage`）
- **解析预览卡**：顶栏（绿点 + `链接解析成功` + `READY` 徽标）；左 220×124 缩略图（无缩略图时渐变占位 + 播放图标）；右侧标题 + `来源 · 时长` + 画质 chip 组（最佳 / 1080p / 720p / 480p，chip 替代下拉，选中青色描边）+ `加入下载队列` 主按钮
- **播放列表分支**：保留现有勾选列表（`entry_list` / `check_<url>` / 全选 / 反选 / 已选计数），套新版卡片样式
- **任务区**：`正在下载 N 个任务` + `当前并发下载数：N`（读 `settings.concurrency`）+ 右上 `查看全部历史` 跳转；任务卡 = 48px 图标块（下载中青色 film / 完成绿色 check / 失败橙色 alert）+ 标题 + 右侧百分比（按状态着色）+ 元信息行（画质 · 剩余 / 速度）+ 6px 进度条 + 图标操作按钮
- **所有 key 保持**：`url_field` `analyze_button` `enqueue_button` `open_<id>` `cancel_<id>` `retry_<id>` `entry_list` `check_<url>`

## 六、历史页（history.html）

- 标题区：`全部记录` + 条数徽标 + `最近更新：<时间>` + 右上 `清空记录`（带二次确认，调 `removeAll()` —— 该 API 已在仓储中存在但当前未接线）
- 筛选 tab：见决策项 Q2
- 表头：`文件名称 / 格式·清晰度 / 下载时间 / 状态 / 操作`（`1fr 140 140 100 64`）
- 行：36px 图标块（视频 film / 音频 music / 失败 alert）+ 标题 + 副行为保存目录（`dirname(filePath)`）+ 格式标签（preset 本地化）+ 时间（`今天 HH:mm` / `昨天 HH:mm` / `yyyy/MM/dd`）+ 状态点 + 操作图标
- 空态：`暂无下载记录`（保留现文案与查找）
- **所有 key 保持**：`open_file_<id>` `open_dir_<id>` `redownload_<id>` `delete_<id>`

## 七、设置页（settings.html）

- 头部右侧 `保存设置` 主按钮；主体 = 180px 二级分区导航（常规 / 下载设置 / 关于与更新）+ 内容卡
- **常规**：界面语言（分段控件 `中文 | English`，替换 ComboBox）· 完成后发出通知（新增开关，见备注）· 默认画质（chip 组）
- **下载设置**：视频保存目录（路径框 + `选择目录`）· Cookie 文件（路径框 + `选择文件` + 状态徽标 + 清除）· 并发下载数（步进器 − 3 +，范围 1–5，替换 Slider）
- **关于与更新**：Logo 卡片 + 版本信息 + yt-dlp / ffmpeg 版本 + 更新状态 + `检查更新` + 免责声明 + 开源许可说明
- 备注：原型的"完成后发出通知"需要系统通知能力，当前无通知依赖；**方案：开关先落地为本地偏好项（写入 SharedPreferences 并持久化，不改变行为），待后续接入通知时再生效**，避免引入新依赖

## 八、测试与验证

- 受影响的现有断言：`settings_page_test`（并发控件由 Slider 变步进器 → `concurrency_slider` 相关用例需改写为点 `+`/`−`）、`app_shell_test`（设置页分区后 `下载目录` 需先切到"下载设置"）
- 其余断言（下载页 key 链路、历史页 key 链路、错误文案、中英文切换、更新状态）全部保持原样，用于验证"只改外观不改行为"
- 门禁：`flutter analyze`（零告警）→ `flutter test`（全绿）→ `flutter run -d windows` 目测

## 九、执行顺序（每步一次提交，便于回滚）

1. 主题与通用组件（`app_theme.dart` + `widgets.dart`）
2. 侧边栏 + 外壳 + main.dart 深色主题（此时三页仍是旧内容，但已是深色壳）
3. 下载页
4. 历史页
5. 设置页
6. ARB 补齐 + `flutter gen-l10n`
7. 更新受影响测试 → `flutter analyze` + `flutter test`
8. 更新 `AGENTS.md`（补充主题/组件约定）与 README 截图说明（可选）

## 十、已确认决策

- **Q1 设置页分区** → **原型式分区切换**：一次只显示一个分区，同步改写 `settings_page_test` / `app_shell_test` 的断言（测试需先点分区 tab 再找控件）
- **Q2 历史筛选维度** → **按状态筛选**：全部 / 已完成 / 失败（对应数据库 `status` 字段），保留原型 tab 视觉
- **Q3 历史分页** → **暂不分页**：长列表直接滚动，不引入分页状态
