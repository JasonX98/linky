// lib/features/download/error_display.dart
//
// 统一错误展示：download_page（任务行 + 分析错误）与 history_page 共用。
// 设计目标：任何 kind/detail 组合都得到 [core]（本地化友好文案，恒非空），
// 绝不以裸 raw 技术文本作主文案；raw 仅在有意义时作为弱化副行。
import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

/// 纯函数核心（无 BuildContext，便于不 pump widget 时单测）：
/// - [core] 恒为本地化友好文案，非空
/// - [detail] 仅在非空且"有意义"时非 null：trim 后非空，且不等于 core；
///   engineMissing 的 detail（引擎路径）已嵌入 core，不再作副行
/// - unknown 走 [S.downloadFailed] 兜底，避免 [S.errorUnknown] 把 raw 嵌入 core
({String core, String? detail}) displayErrorWith(
    S s, EngineErrorKind kind, String detail) {
  final core = switch (kind) {
    EngineErrorKind.login => s.errorLogin,
    EngineErrorKind.geo => s.errorGeo,
    EngineErrorKind.unavailable => s.errorUnavailable,
    EngineErrorKind.network => s.errorNetwork,
    EngineErrorKind.timeout => s.errorTimeout,
    EngineErrorKind.parseFailed => s.errorParse,
    EngineErrorKind.engineMissing => s.errorEngineMissing(detail),
    EngineErrorKind.outputFileMissing => s.errorOutputMissing,
    EngineErrorKind.unknown => s.downloadFailed,
  };
  final trimmed = detail.trim();
  final detailText = kind == EngineErrorKind.engineMissing
      ? null
      : (trimmed.isNotEmpty && trimmed != core ? trimmed : null);
  return (core: core, detail: detailText);
}

/// 便捷入口：从 [context] 提取本地化后转 [displayErrorWith]。
({String core, String? detail}) displayError(
    BuildContext context, EngineErrorKind kind, String detail) =>
    displayErrorWith(S.of(context), kind, detail);

/// 渲染 core + 可选 detail 副行：主文案用正文，detail 用弱化小字
/// （最多 2 行 + 省略号）。供任务行、分析错误条、历史失败行复用。
class ErrorMessage extends StatelessWidget {
  const ErrorMessage({super.key, required this.kind, required this.detail});
  final EngineErrorKind kind;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final e = displayError(context, kind, detail);
    final core = Text(e.core);
    final d = e.detail;
    if (d == null) return core;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        core,
        Text(d,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption),
      ],
    );
  }
}
