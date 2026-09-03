// lib/features/settings/app_update_action.dart
//
// "检查应用更新"动作与按钮：触发一次应用版本检查，并把结果写入
// appUpdateStatusProvider / appUpdateAvailableProvider。跳转式——不做任何
// 文件替换，只在检测到新版本时用默认浏览器打开 GitHub 发布页。

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/features/settings/app_update.dart';
import 'package:video_downloader/features/settings/providers.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 触发一次应用更新检查，并把结果写入对应 provider。
/// 期间 [appUpdateCheckingProvider] 为 true（按钮禁用 + 显示"检查中…"）。
/// 整体有 [timeout] 顶层兜底（默认 30 秒）；测试可注入短值加速超时路径。
Future<void> runAppUpdateCheck(
  BuildContext context,
  WidgetRef ref, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final s = S.of(context);
  ref.read(appUpdateCheckingProvider.notifier).state = true;
  ref.read(appUpdateStatusProvider.notifier).state = s.appUpdateChecking;
  ref.read(appUpdateAvailableProvider.notifier).state = null;
  try {
    final result = await ref
        .read(appUpdateServiceProvider)
        .checkForUpdate()
        .timeout(timeout);
    switch (result) {
      case AppUpdateAvailable(:final release):
        ref.read(appUpdateStatusProvider.notifier).state =
            s.appUpdateAvailable(release.version, AppMeta.version);
        ref.read(appUpdateAvailableProvider.notifier).state = release;
      case AppUpdateUpToDate():
        ref.read(appUpdateStatusProvider.notifier).state = s.appUpdateUpToDate;
      case AppUpdateFailed(:final detail):
        ref
            .read(appUpdateStatusProvider.notifier).state =
            s.appUpdateFailed(detail);
    }
  } on TimeoutException {
    ref.read(appUpdateStatusProvider.notifier).state = s.appUpdateTimeout;
  } catch (e) {
    ref
        .read(appUpdateStatusProvider.notifier).state =
        s.appUpdateFailed(e.toString());
  } finally {
    ref.read(appUpdateCheckingProvider.notifier).state = false;
  }
}

/// 打开当前可用 release 的发布页；失败时把错误写回状态文案。
Future<void> _openRelease(BuildContext context, WidgetRef ref) async {
  final release = ref.read(appUpdateAvailableProvider);
  if (release == null) return;
  final s = S.of(context);
  final svc = ref.read(appUpdateServiceProvider);
  try {
    await svc.openReleasePage(release);
  } catch (e) {
    ref.read(appUpdateStatusProvider.notifier).state =
        s.appUpdateFailed(e.toString());
  }
}

/// "检查应用更新"按钮：label 随进行中状态切换。
/// key 只留最外层（AppUpdateButton），不再往下传给 GhostButton。
class AppUpdateButton extends ConsumerWidget {
  const AppUpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final checking = ref.watch(appUpdateCheckingProvider);
    return GhostButton(
      label: checking ? s.appUpdateChecking : s.settingsCheckAppUpdate,
      icon: FluentIcons.refresh,
      onPressed: checking ? null : () => runAppUpdateCheck(context, ref),
    );
  }
}

/// 应用更新结果区：状态文本 + （发现新版本时）"前往更新"按钮。
class AppUpdateStatusView extends ConsumerWidget {
  const AppUpdateStatusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final status = ref.watch(appUpdateStatusProvider);
    if (status.isEmpty) return const SizedBox.shrink();
    final available = ref.watch(appUpdateAvailableProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(status, style: AppText.meta(), maxLines: 3),
        ),
        if (available != null) ...[
          const SizedBox(width: 12),
          GhostButton(
            label: s.appUpdateGoUpdate,
            icon: FluentIcons.link,
            onPressed: () => _openRelease(context, ref),
          ),
        ],
      ],
    );
  }
}
