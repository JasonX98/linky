// lib/features/download/providers.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/engine_update.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/features/download/analysis_controller.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/features/download/queue_controller.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';

final ytDlpServiceProvider =
    Provider<YtDlpService>((ref) => YtDlpService());

/// 共享的引擎定位器（baseDirOverride/环境变量解析逻辑唯一入口）。
final engineLocatorProvider =
    Provider<EngineLocator>((ref) => EngineLocator());

/// 引擎更新服务：依赖 [engineLocatorProvider]；downloader/verifier/httpGet
/// 使用默认网络/进程实现，测试可整体 override 本 provider。
final engineServiceProvider = Provider<EngineUpdateService>((ref) => EngineUpdateService(
      locator: ref.watch(engineLocatorProvider),
    ));

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

final downloadsDirProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final configured = ref.read(settingsProvider).downloadDir;
    if (configured != null && configured.isNotEmpty) return configured;
    return (await getDownloadsDirectory())?.path ?? Directory.systemTemp.path;
  };
});

final downloadQueueProvider =
    NotifierProvider<DownloadQueueController, List<DownloadTask>>(
        DownloadQueueController.new);

final analysisProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final historyRepositoryProvider = Provider<HistoryRepository>(
    (ref) => HistoryRepository(ref.watch(appDatabaseProvider)));
