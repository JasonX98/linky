// lib/features/download/providers.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/engine_update.dart';
import 'package:video_downloader/engine/models.dart';
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

/// 根据代理配置创建 HttpClient 的 findProxy 回调。
/// 启用时返回固定代理地址；禁用时回退到系统环境变量代理。
String _proxyFindProxy(Uri uri, SettingsState settings) {
  if (!settings.proxyEnabled) {
    return HttpClient.findProxyFromEnvironment(uri);
  }
  return 'PROXY ${settings.proxyHost}:${settings.proxyPort}';
}

/// 引擎更新服务：根据设置中的代理配置创建 HTTP 函数，
/// 启用代理时所有请求走配置的 host:port，禁用时走系统环境变量代理。
/// 测试可整体 override 本 provider 以注入假实现。
final engineServiceProvider = Provider<EngineUpdateService>((ref) {
  final locator = ref.watch(engineLocatorProvider);
  final settings = ref.watch(settingsProvider);
  final timeout = const Duration(seconds: 10);

  Future<String> httpGet(String url) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (uri) => _proxyFindProxy(uri, settings);
    try {
      return await () async {
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.userAgentHeader,
            'video_downloader/1.0 (yt-dlp updater)');
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode != 200) {
          throw DownloadException(
              EngineErrorKind.network, 'HTTP ${resp.statusCode}');
        }
        return body;
      }().timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<void> downloader(String destPath) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (uri) => _proxyFindProxy(uri, settings);
    try {
      final req = await client
          .getUrl(Uri.parse(
              'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'))
          .timeout(timeout);
      req.headers.set(HttpHeaders.userAgentHeader,
          'video_downloader/1.0 (yt-dlp updater)');
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) {
        throw DownloadException(EngineErrorKind.network,
            'download failed: HTTP ${resp.statusCode}');
      }
      final sink = File(destPath).openWrite();
      try {
        await resp.pipe(sink).timeout(timeout);
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> ffmpegDownloader(String zipPath) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (uri) => _proxyFindProxy(uri, settings);
    try {
      final req = await client
          .getUrl(Uri.parse(
              'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'))
          .timeout(timeout);
      req.headers.set(HttpHeaders.userAgentHeader,
          'video_downloader/1.0 (yt-dlp updater)');
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) {
        throw DownloadException(EngineErrorKind.network,
            'ffmpeg download failed: HTTP ${resp.statusCode}');
      }
      final sink = File(zipPath).openWrite();
      try {
        await resp.pipe(sink).timeout(timeout);
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  return EngineUpdateService(
    locator: locator,
    httpGet: httpGet,
    downloader: downloader,
    ffmpegDownloader: ffmpegDownloader,
    checkTimeout: timeout,
  );
});

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
