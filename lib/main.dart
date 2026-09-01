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
import 'package:video_downloader/features/shell/app_shell.dart';
import 'package:video_downloader/features/shell/window_close_gate.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';

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

/// 启动自愈：仅当引擎缺失或损坏（零字节）时重新下载，确保后续下载可用。
/// 不再在启动时执行任何"检查更新 / 应用更新"——检查更新仅由"检查更新"按钮触发。
/// 全流程 best-effort，异常静默降级。
Future<void> _bootstrapEngine(ProviderContainer container) async {
  try {
    await container.read(engineServiceProvider).ensureEngine();
  } catch (_) {
    // 自愈失败静默，后续下载会再提示
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

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return FluentApp(
      title: AppMeta.name,
      theme: buildAppTheme(),
      locale: Locale(settings.language),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: const WindowCloseGate(child: AppShell()),
    );
  }
}
