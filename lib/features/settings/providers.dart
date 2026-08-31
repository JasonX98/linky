// lib/features/settings/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/features/download/providers.dart';

/// 引擎组件版本（`FutureProvider<({String? ytDlp, String? ffmpeg})>`）：
/// 分别读取 yt-dlp 与 ffmpeg 的当前版本，缺失时为 null，由 UI 层逐项渲染本地化占位。
final engineVersionsProvider =
    FutureProvider<({String? ytDlp, String? ffmpeg})>((ref) async {
  final svc = ref.watch(engineServiceProvider);
  // 逐组件独立读取，任一失败（缺失/超时）降级为 null，互不牵连——避免 ffmpeg
  // 版本探测异常把整个 provider 打成 error，导致 yt-dlp 版本也被误显示为“未知”。
  String? yt;
  String? ff;
  try {
    yt = (await svc.version())?.toString();
  } catch (_) {}
  try {
    ff = await svc.ffmpegVersion();
  } catch (_) {}
  return (ytDlp: yt, ffmpeg: ff);
});

/// 设置页"检查更新"进行中标记：为 true 时按钮禁用并显示"检查中…"。
final engineUpdateCheckingProvider = StateProvider<bool>((ref) => false);

/// 设置页"检查更新"的状态文字：由 UI 在点击后按结果写入本地化串。
final engineUpdateStatusProvider = StateProvider<String>((ref) => '');

