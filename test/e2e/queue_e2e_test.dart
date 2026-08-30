@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';

/// M2 e2e 不关心历史：no-op 仓库，避免 drift 打开路径引入 path_provider 依赖
class _NoopHistory implements HistoryRepository {
  @override
  Future<void> record(
          {required String url,
          required String title,
          String? uploader,
          int? durationSec,
          required String formatLabel,
          String? filePath,
          int? fileSize,
          required String status,
          String? errorDetail,
          DateTime? completedAt}) async {}

  @override
  Future<List<DownloadHistoryEntry>> recentEntries({int limit = 200}) async =>
      [];

  @override
  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) =>
      const Stream.empty();

  @override
  Future<void> deleteById(int id) async {}

  @override
  Future<int> removeAll() async => 0;
}

// 确定性策略：用本地节流 HTTP 服务器（generic 提取器下载直链 MP4），
// 取消窗口完全可控，不依赖外站速度/稳定性/限流策略。
// 真实站点（B 站/YouTube）的引擎覆盖由 M1 端到端历史与 GUI 冒烟承担。
// 默认跳过：运行 [$env:RUN_E2E='1'] 后执行 flutter test test/e2e --concurrency=1（文件级串行，避免跨文件互扰）
bool get _e2eEnabled => Platform.environment['RUN_E2E'] == '1';
Future<(HttpServer, String)> _startThrottledServer({
  required String path,
  required int megabytes,
  int chunkDelayMs = 500,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final chunk = List<int>.filled(1024 * 1024, 0x61);
  final total = megabytes * chunk.length;
  final delay = Duration(milliseconds: chunkDelayMs);
  server.listen((req) async {
    try {
      if (req.method == 'HEAD') {
        req.response.headers.contentType = ContentType('video', 'mp4');
        req.response.contentLength = total;
        await req.response.close();
        return;
      }
      req.response.headers.contentType = ContentType('video', 'mp4');
      req.response.contentLength = total;
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
  final tl = await Process.run('tasklist', []);
  final procs = (tl.stdout as String)
      .split('\n')
      .where((l) => l.contains('yt-dlp') || l.contains('ffmpeg'))
      .join('\n');
  fail('timeout waiting $wanted for task $id\n tasks:\n$dump\n'
      'processes:\n${procs.isEmpty ? '(none)' : procs}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Directory tmp;

  setUp(() async {
    // Task 4 起 queue 依赖 settings（sharedPrefsProvider），e2e 必须注入
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('e2e_m2');
    container = ProviderContainer(overrides: [
      downloadsDirProvider.overrideWithValue(() async => tmp.path),
      sharedPrefsProvider.overrideWithValue(prefs),
      historyRepositoryProvider.overrideWith((ref) => _NoopHistory()),
    ]);
  });

  tearDown(() async {
    // 先取消所有未完成任务，避免孤儿进程跨测试污染（tasklist 断言/临时目录删除）
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
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // 进程句柄可能尚未完全释放；残留交由系统临时目录回收
    }
  });

  test('serial queue completes tasks one at a time (concurrency=1)', () async {
    final (serverA, urlA) =
        await _startThrottledServer(path: '/alpha.mp4', megabytes: 1);
    final (serverB, urlB) =
        await _startThrottledServer(path: '/beta.mp4', megabytes: 1);
    addTearDown(() async {
      await serverA.close(force: true);
      await serverB.close(force: true);
    });

    final controller = container.read(downloadQueueProvider.notifier);
    controller.setConcurrency(1);
    final a = await controller.enqueue(
        url: urlA, title: 'serial-A', preset: QualityPreset.best);
    final b = await controller.enqueue(
        url: urlB, title: 'serial-B', preset: QualityPreset.best);

    final earlyB = await waitStatus(container, b,
        {TaskStatus.queued, TaskStatus.downloading}, const Duration(minutes: 1));
    if (earlyB == TaskStatus.queued) {
      // A 占用唯一并发槽期间 B 保持排队，且同时只有 1 个任务在下载
      expect(
          container
              .read(downloadQueueProvider)
              .where((t) => t.status == TaskStatus.downloading)
              .length,
          1);
    }

    expect(
        await waitStatus(container, a, {TaskStatus.completed, TaskStatus.failed},
            const Duration(minutes: 3)),
        TaskStatus.completed,
        reason:
            'A error: ${container.read(downloadQueueProvider).firstWhere((t) => t.id == a).errorDetail}');
    expect(
        await waitStatus(container, b, {TaskStatus.completed, TaskStatus.failed},
            const Duration(minutes: 3)),
        TaskStatus.completed,
        reason:
            'B error: ${container.read(downloadQueueProvider).firstWhere((t) => t.id == b).errorDetail}');
  }, timeout: const Timeout(Duration(minutes: 5)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');

  test('cancel kills the process tree and lands canceled', () async {
    final (server, url) = await _startThrottledServer(
        path: '/big.mp4', megabytes: 60, chunkDelayMs: 500);
    addTearDown(() => server.close(force: true));

    final controller = container.read(downloadQueueProvider.notifier);
    controller.setConcurrency(1);
    final c = await controller.enqueue(
        url: url, title: 'cancel-me', preset: QualityPreset.best);

    await waitStatus(
        container, c, {TaskStatus.downloading}, const Duration(minutes: 2));
    // 节流下下载需要 30s+，此刻取消必然命中进行中的进程树
    await controller.cancel(c);
    expect(
        await waitStatus(
            container, c, {TaskStatus.canceled}, const Duration(seconds: 30)),
        TaskStatus.canceled);

    // 无孤儿进程：taskkill /T 后不应残留 yt-dlp / ffmpeg。
    // PyInstaller 子进程可能在父退出后短暂存活（跨测试时序抖动），故有界重试等待消失。
    Future<bool> noOrphan() async {
      final tl = await Process.run('tasklist', []);
      final out = tl.stdout as String;
      return !out.contains('yt-dlp.exe') && !out.contains('ffmpeg.exe');
    }
    var gone = await noOrphan();
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (!gone && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      gone = await noOrphan();
    }
    expect(gone, isTrue, reason: 'orphan engine process still present');
  }, timeout: const Timeout(Duration(minutes: 5)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');

  test('retry reruns a canceled task', () async {
    final (serverSlow, urlSlow) = await _startThrottledServer(
        path: '/holder.mp4', megabytes: 60, chunkDelayMs: 500);
    final (serverFast, urlFast) =
        await _startThrottledServer(path: '/small.mp4', megabytes: 1);
    addTearDown(() async {
      await serverSlow.close(force: true);
      await serverFast.close(force: true);
    });

    final controller = container.read(downloadQueueProvider.notifier);
    controller.setConcurrency(1);
    // 长任务占住唯一并发槽，让 retry-me 保持排队 → 取消排队任务无竞态
    final long = await controller.enqueue(
        url: urlSlow, title: 'slot-holder', preset: QualityPreset.best);
    final c = await controller.enqueue(
        url: urlFast, title: 'retry-me', preset: QualityPreset.best);
    await waitStatus(container, long, {TaskStatus.downloading},
        const Duration(minutes: 2));

    await controller.cancel(c);
    expect(
        await waitStatus(
            container, c, {TaskStatus.canceled}, const Duration(seconds: 15)),
        TaskStatus.canceled);

    // 重试后仍排队（槽被占），释放槽后自动开始下载
    controller.retry(c);
    await waitStatus(container, c, {TaskStatus.queued},
        const Duration(seconds: 15));
    await controller.cancel(long);
    expect(
        await waitStatus(container, c,
            {TaskStatus.downloading, TaskStatus.completed},
            const Duration(minutes: 3)),
        isNot(TaskStatus.canceled));
    // 收尾：若仍在下载则取消；小文件可能已完成
    await controller.cancel(c);
    await waitStatus(container, c, {TaskStatus.canceled, TaskStatus.completed},
        const Duration(seconds: 30));
  }, timeout: const Timeout(Duration(minutes: 8)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');
}
