// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/core/logger.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/features/shell/app_shell.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _attachLogger();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  runApp(UncontrolledProviderScope(
    container: container,
    child: const App(),
  ));
  unawaited(_bootstrapEngine(container));
}

/// 启动自愈 + 后台静默检查（节流）：先 ensureEngine，再按 24h 节流检查更新；
/// 仅在队列空闲时应用更新。全流程 best-effort，异常静默降级。
Future<void> _bootstrapEngine(ProviderContainer container) async {
  try {
    await container.read(engineServiceProvider).ensureEngine();
  } catch (_) {
    // 自愈失败静默，后续下载会再提示
  }
  try {
    final result = await container
        .read(settingsProvider.notifier)
        .checkEngineUpdates();
    if (result.ytDlp == ComponentUpdateOutcome.updated ||
        result.ffmpeg == ComponentUpdateOutcome.updated) {
      Logger.log('engine updated: yt-dlp=${result.ytDlpVersion} ffmpeg=${result.ffmpegVersion}');
    }
  } catch (_) {
    // 检查失败静默（网络/授权异常属预期降级）
  }
}

/// 附加文件落盘 sink：追加式写入 app support 目录下的 logs/app.log。
/// best-effort —— 目录创建失败或写入异常均静默降级，不影响启动。
Future<void> _attachLogger() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    await logDir.create(recursive: true);
    final logFile = File(p.join(logDir.path, 'app.log'));
    Logger.attach((m) async {
      await logFile.writeAsString('$m\n', mode: FileMode.append, flush: true);
    });
  } catch (_) {
    // 日志文件不可用时静默降级
  }
}

// fluent_ui 的 Colors 无 indigo 且 accentColor 要求 AccentColor，
// 按 fluent 内置 swatch 结构构造 Material Indigo 强调色
final _indigoAccent = AccentColor.swatch(const <String, Color>{
  'darkest': Color(0xFF1A237E),
  'darker': Color(0xFF283593),
  'dark': Color(0xFF303F9F),
  'normal': Color(0xFF3F51B5),
  'light': Color(0xFF5C6BC0),
  'lighter': Color(0xFF7986CB),
  'lightest': Color(0xFF9FA8DA),
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return FluentApp(
      title: 'Video Downloader',
      theme: FluentThemeData(accentColor: _indigoAccent),
      locale: Locale(settings.language),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: AppShell(),
    );
  }
}
