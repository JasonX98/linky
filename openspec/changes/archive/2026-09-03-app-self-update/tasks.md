# Tasks: 应用自更新（跳转式）

> 参照 `specs/self-update/spec.md`（行为契约）与 `design.md`（实现取舍）。按依赖顺序推进。

## 1. 服务层：`AppUpdateService` 与 `AppVersion`

- [x] 1.1 新增 `lib/features/settings/app_update.dart`，定义轻量 `AppVersion`（`tryParse` 去 `v` 前缀、剥离 `+build` 后缀、按段比较、缺段按 0），验证 `AppVersion.tryParse('v1.0.4')` 与 `AppVersion.tryParse('1.0.3+0')` 均可解析、`isNewerThan` 与相等语义正确。
- [x] 1.2 新增 `AppUpdateService`，提供 `checkForUpdate()`（读取当前版本 → 拉 GitHub `releases/latest` → 比较），验证：远端更高 → 返回含新版本号的结果；主次补丁相同 → 返回"已最新"；远端不可用 → 友好降级不抛异常。
- [x] 1.3 实现远端拉取与跳转：`fetchLatest()`（GitHub API，带 User-Agent，失败降级返回 null）与 `openReleasePage()`（经注入的 `openUrl` 回调打开 `html_url`），验证二者可注入、失败不崩。

## 2. 状态管理

- [x] 2.1 在 `lib/features/settings/providers.dart` 新增 `appUpdateStatusProvider` / `appUpdateCheckingProvider`（`StateProvider`），验证默认值与 `engineUpdate*` 同款模式、重置后回到初始态。

## 3. UI 挂载

- [x] 3.1 在设置页"关于与更新"卡片应用版本行旁加"检查更新"按钮，验证：key 只挂最外层封装（`find.byKey` 不歧义）、窄窗口（压窄视口）不触发 RenderFlex 溢出。
- [x] 3.2 实现"检查更新"动作（含总超时兜底与结果文案：已最新 / 发现新版本 +【前往更新】 / 失败），验证点击后状态正确更新一次、超时/失败走降级路径。
- [x] 3.3 "前往更新"触发 `openReleasePage()`，验证点击后调用注入的 `openUrl`。

## 4. 发布命名规范（文档）

- [x] 4.1 在 `AGENTS.md` 的"发布构建"小节加入统一命名规范表（tag `v<semver>`、标题 `Linky v<semver>`、资产 `Linky-v<semver>-windows-x64.zip`、版本号来源、更新日志文件），验证规范表现在 AGENTS.md 中；同步校对 README 中发布产物命名措辞。

## 5. 测试与门禁

- [x] 5.1 新增应用更新检测/跳转的单测（仿 `test/engine/engine_update_test.dart` 的注入式写法），覆盖：判新、主次补丁相同视为最新、网络失败降级、跳转调用 `openUrl`，验证 `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY no_proxy="localhost,127.0.0.1" flutter test` 通过。
- [x] 5.2 运行 `flutter analyze`，验证 warnings-as-errors 门禁下零告警。
