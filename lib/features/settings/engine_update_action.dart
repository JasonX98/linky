// lib/features/settings/engine_update_action.dart
//
// "检查更新"动作与按钮：下载页头部、设置页"关于与更新"共用同一份逻辑，
// 避免两处各写一遍导致文案与节流行为分叉。

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 触发一次强制检查，并把结果写入 [engineUpdateStatusProvider]。
/// 期间 [engineUpdateCheckingProvider] 为 true（按钮禁用 + 显示"检查中…"）。
///
/// 整个操作有 [timeout] 顶层超时兜底（默认 30 秒）：即使各子步骤的独立
/// 超时均未触发，也不会永远卡在"检查中…"状态。[timeout] 参数主要供测试注入
/// 短值以加速验证超时路径；生产调用省略即可。
Future<void> runEngineUpdateCheck(
  BuildContext context,
  WidgetRef ref, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final s = S.of(context);
  ref.read(engineUpdateCheckingProvider.notifier).state = true;
  ref.read(engineUpdateStatusProvider.notifier).state = s.updateChecking;
  try {
    final result = await ref
        .read(settingsProvider.notifier)
        .checkEngineUpdates()
        .timeout(timeout);
    final parts = <String>[
      ..._componentFrags('yt-dlp', result.ytDlp, result.ytDlpVersion,
          result.ytDlpError, s),
      ..._componentFrags('ffmpeg', result.ffmpeg, result.ffmpegVersion,
          result.ffmpegError, s),
    ];
    ref.read(engineUpdateStatusProvider.notifier).state =
        parts.isEmpty ? s.updateUpToDate : parts.join('\n');
  } on TimeoutException {
    ref
        .read(engineUpdateStatusProvider.notifier).state = s.updateTimeout;
  } finally {
    ref.read(engineUpdateCheckingProvider.notifier).state = false;
  }
}

/// 单个组件的更新结果 → 0~1 条文案（upToDate 返回空：仅当全部组件都最新时
/// 才显示"已是最新版本"）。
List<String> _componentFrags(
  String component,
  ComponentUpdateOutcome outcome,
  String? version,
  String? error,
  S s,
) {
  switch (outcome) {
    case ComponentUpdateOutcome.upToDate:
      return const [];
    case ComponentUpdateOutcome.updated:
      return [s.updateUpdated(component, version ?? '')];
    case ComponentUpdateOutcome.busy:
      return [s.updateBusy(component)];
    case ComponentUpdateOutcome.failed:
      return [s.updateFailed(component, error ?? '')];
  }
}

/// 描边"检查更新"按钮：label 随进行中状态切换。
class CheckUpdateButton extends ConsumerWidget {
  const CheckUpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final checking = ref.watch(engineUpdateCheckingProvider);
    // 注意：key 只留在最外层（CheckUpdateButton），不要再往下传给 GhostButton，
    // 否则 find.byKey 会同时命中两个 Element。
    return GhostButton(
      label: checking ? s.updateChecking : s.settingsCheckUpdate,
      icon: FluentIcons.refresh,
      onPressed: checking ? null : () => runEngineUpdateCheck(context, ref),
    );
  }
}
