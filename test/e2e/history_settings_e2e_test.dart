@Tags(['e2e'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';

// 确定性策略沿用 M2：本地节流 HTTP 服务器，取消/完成窗口完全可控。
// 本文件聚焦 M3：完成/失败落库（真实 drift 内存库）+ 设置驱动（并发/目录）。
// 默认跳过：运行 [$env:RUN_E2E='1'] 后执行 flutter test test/e2e --concurrency=1（文件级串行，避免跨文件互扰）
bool get _e2eEnabled => Platform.environment['RUN_E2E'] == '1';

Future<(HttpServer, String)> _startThrottledServer({
  required String path,
  required int megabytes,
  int chunkDelayMs = 500,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final chunk = List<int>.filled(1024 * 1024, 0x61);
  final delay = Duration(milliseconds: chunkDelayMs);
  server.listen((req) async {
    try {
      req.response.headers.contentType = ContentType('video', 'mp4');
      req.response.contentLength = megabytes * chunk.length;
      for (var i = 0; i < megabytes; i++) {
        req.response.add(chunk);
        await req.response.flush();
        await Future<void>.delayed(delay);
      }
      await req.response.close();
    } catch (_) {
      // 客户端取消（下载被 kill）导致的写失败属预期
    }
  });
  return (server, 'http://127.0.0.1:${server.port}$path');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Directory tmp;
  late AppDatabase db;
  late HistoryRepository history;
  late SharedPreferences prefs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('e2e_m3');
    db = AppDatabase(NativeDatabase.memory());
    history = HistoryRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
  });

  tearDown(() async {
    final notifier = container.read(downloadQueueProvider.notifier);
    for (final t in container.read(downloadQueueProvider)) {
      if (t.isActive) {
        await notifier.cancel(t.id);
      }
    }
    container.dispose();
    // 清扫可能的孤儿引擎进程（PyInstaller 子进程可能在父退出后存活）。
    // 仅在真正运行 e2e 时清扫，避免误杀机器上无关的 yt-dlp/ffmpeg。
    if (_e2eEnabled) {
      await Process.run('taskkill', ['/IM', 'yt-dlp.exe', '/F']);
      await Process.run('taskkill', ['/IM', 'ffmpeg.exe', '/F']);
    }
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // 进程句柄可能尚未完全释放；残留交由系统临时目录回收
    }
  });

  Future<TaskStatus> waitStatus(ProviderContainer c, String id,
      Set<TaskStatus> wanted, Duration limit) async {
    final end = DateTime.now().add(limit);
    while (DateTime.now().isBefore(end)) {
      final matches =
          c.read(downloadQueueProvider).where((t) => t.id == id).toList();
      if (matches.isNotEmpty && wanted.contains(matches.single.status)) {
        return matches.single.status;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final dump = c
        .read(downloadQueueProvider)
        .map((t) => '${t.id}[${t.title}]: ${t.status}'
            '${t.errorDetail != null ? ' (${t.errorDetail})' : ''}')
        .join('\n');
    fail('timeout waiting $wanted for task $id\n tasks:\n$dump');
  }

  test('completed download lands a history row in drift', () async {
    final (server, url) =
        await _startThrottledServer(path: '/done.mp4', megabytes: 2);
    addTearDown(() => server.close(force: true));

    // 目录经 prefs 设置（真实链路：设置 → downloadsDirProvider）
    await prefs.setString('downloadDir', tmp.path);
    final controller = container.read(downloadQueueProvider.notifier);
    final id = await controller.enqueue(
        url: url, title: 'history-me', preset: QualityPreset.best);

    expect(
        await waitStatus(container, id, {TaskStatus.completed},
            const Duration(minutes: 3)),
        TaskStatus.completed);

    // 轮询等待落库（终态 patch 后异步写入）
    final end = DateTime.now().add(const Duration(seconds: 10));
    var rows = await history.recentEntries();
    while (rows.isEmpty && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      rows = await history.recentEntries();
    }
    expect(rows, hasLength(1));
    expect(rows.single.title, 'history-me');
    expect(rows.single.status, 'completed');
    expect(rows.single.filePath, isNotNull);
    expect(rows.single.filePath!.startsWith(tmp.path), isTrue,
        reason: 'filePath=${rows.single.filePath}');
  }, timeout: const Timeout(Duration(minutes: 5)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');

  test('settings drive serial execution and download directory', () async {
    // 并发与目录都经 prefs（设置→下载路径的真实链路）：
    // 移除 downloadsDirProvider override，走默认 provider 读设置
    await prefs.setInt('concurrency', 1);
    await prefs.setString('downloadDir', tmp.path);
    final (serverA, urlA) =
        await _startThrottledServer(path: '/s-a.mp4', megabytes: 2);
    final (serverB, urlB) =
        await _startThrottledServer(path: '/s-b.mp4', megabytes: 2);
    addTearDown(() async {
      await serverA.close(force: true);
      await serverB.close(force: true);
    });

    final controller = container.read(downloadQueueProvider.notifier);
    final a = await controller.enqueue(
        url: urlA, title: 'set-a', preset: QualityPreset.best);
    final b = await controller.enqueue(
        url: urlB, title: 'set-b', preset: QualityPreset.best);

    // A 完成前的每个轮询点都断言：并发=1 生效（同时下载 ≤1）
    final end = DateTime.now().add(const Duration(minutes: 3));
    var aStatus = TaskStatus.queued;
    while (DateTime.now().isBefore(end) && aStatus != TaskStatus.completed) {
      final tasks = container.read(downloadQueueProvider);
      final downloading = tasks.where((t) => t.status == TaskStatus.downloading).length;
      expect(downloading <= 1, isTrue,
          reason: 'concurrency=1 violated: '
              '${tasks.map((t) => '${t.id}:${t.status}').join(', ')}');
      aStatus = tasks.firstWhere((t) => t.id == a).status;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    expect(aStatus, TaskStatus.completed,
        reason: 'A failed: '
            '${container.read(downloadQueueProvider).firstWhere((t) => t.id == a).errorDetail}');
    expect(
        await waitStatus(container, b,
            {TaskStatus.completed, TaskStatus.failed}, const Duration(minutes: 3)),
        TaskStatus.completed);

    // 目录设置生效：产物经 prefs 链路落在 tmp（generic 提取器以 URL 文件名命名）
    final products = Directory(tmp.path)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList();
    expect(
        products.any((f) => f.endsWith('s-a.mp4')), isTrue,
        reason: 'a product missing; tmp: $products');
    expect(
        products.any((f) => f.endsWith('s-b.mp4')), isTrue,
        reason: 'b product missing; tmp: $products');
  }, timeout: const Timeout(Duration(minutes: 8)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');

  test('failed download records history with error detail', () async {
    // 指向不存在的本地端口 → 快速失败
    await prefs.setString('downloadDir', tmp.path);
    final controller = container.read(downloadQueueProvider.notifier);
    final id = await controller.enqueue(
        url: 'http://127.0.0.1:9/never.mp4',
        title: 'fail-me',
        preset: QualityPreset.best);

    expect(
        await waitStatus(container, id, {TaskStatus.failed},
            const Duration(minutes: 2)),
        TaskStatus.failed);

    final end = DateTime.now().add(const Duration(seconds: 10));
    var rows = await history.recentEntries();
    while (rows.isEmpty && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      rows = await history.recentEntries();
    }
    expect(rows, hasLength(1));
    expect(rows.single.status, 'failed');
    expect(rows.single.errorSummary, isNotNull,
        reason: 'history row must carry error detail');
    final task =
        container.read(downloadQueueProvider).firstWhere((t) => t.id == id);
    expect(task.errorDetail, isNotNull,
        reason: 'failed task must carry error detail');
  }, timeout: const Timeout(Duration(minutes: 4)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');
}
