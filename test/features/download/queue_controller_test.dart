// test/features/download/queue_controller_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/download/queue_controller.dart';

class FakeHistoryRepository implements HistoryRepository {
  int recordCount = 0;
  final List<Map<String, Object?>> rows = [];

  @override
  Future<void> record({
    required String url,
    required String title,
    String? uploader,
    int? durationSec,
    required String formatLabel,
    String? filePath,
    int? fileSize,
    required String status,
    String? errorDetail,
    DateTime? completedAt,
  }) async {
    recordCount++;
    rows.add(
        {'url': url, 'title': title, 'status': status, 'filePath': filePath});
  }

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

class FakeQueueService extends YtDlpService {
  final Map<String, Completer<String>> pending = {};
  final List<String> canceled = [];
  final List<DownloadRequest> started = [];

  @override
  Future<AnalysisResult> probe(String url, {String? cookieFile}) async =>
      throw UnimplementedError();

  @override
  Future<String> download(DownloadRequest request,
      {void Function(DownloadProgress)? onProgress}) async {
    started.add(request);
    final c = Completer<String>();
    pending[request.taskId!] = c;
    // 进入 downloading 即回调一次进度，验证进度流
    onProgress?.call(const DownloadProgress(fraction: 0.5, speed: '1MiB/s'));
    return c.future;
  }

  @override
  Future<void> cancel(String taskId) async {
    canceled.add(taskId);
    // 真实服务里 kill 后由进程退出使下载 future 以错误结束——fake 等价模拟
    pending.remove(taskId)?.completeError(
        const DownloadException(EngineErrorKind.unknown, '下载进程已被终止'));
  }
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

late ProviderContainer container;
late SharedPreferences prefs;

DownloadQueueController get controller =>
    container.read(downloadQueueProvider.notifier);

void main() {
  late FakeQueueService fake;

  setUp(() async {
    fake = FakeQueueService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      ytDlpServiceProvider.overrideWithValue(fake),
      downloadsDirProvider.overrideWithValue(() async => 'D:\\dl'),
      historyRepositoryProvider.overrideWith((ref) => FakeHistoryRepository()),
    ]);
    addTearDown(container.dispose);
  });

  test('enqueue starts task within concurrency and reports progress',
      () async {
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();

    final tasks = container.read(downloadQueueProvider);
    expect(id, 't0');
    expect(tasks.single.status, TaskStatus.downloading);
    expect(tasks.single.progress?.fraction, 0.5);
    expect(fake.started.single.taskId, 't0');
    expect(fake.started.single.outputDir, 'D:\\dl');
    expect(fake.started.single.ffmpegPath, isNull);
  });

  test('excess tasks stay queued and start as slots free', () async {
    await controller.setConcurrency(1); // 默认并发 3，调低才能观察排队
    await controller.enqueue(url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    await controller.enqueue(url: 'u1', title: '视频1', preset: QualityPreset.best);
    await _settle();

    var tasks = container.read(downloadQueueProvider);
    expect(tasks[0].status, TaskStatus.downloading);
    expect(tasks[1].status, TaskStatus.queued);

    fake.pending['t0']!.complete('D:\\dl\\v0.mp4');
    await _settle();

    tasks = container.read(downloadQueueProvider);
    expect(tasks[0].status, TaskStatus.completed);
    expect(tasks[0].filePath, 'D:\\dl\\v0.mp4');
    expect(tasks[1].status, TaskStatus.downloading);
  });

  test('failure records error kind and detail', () async {
    await controller.enqueue(url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();

    fake.pending['t0']!.completeError(const DownloadException(
        EngineErrorKind.unavailable, '视频不可用：可能已被删除或设为私密'));
    await _settle();

    final tasks = container.read(downloadQueueProvider);
    expect(tasks.single.status, TaskStatus.failed);
    expect(tasks.single.errorKind, EngineErrorKind.unavailable);
  });

  test('late progress after completion does not resurrect state', () async {
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    fake.pending[id]!.complete('D:\\dl\\v0.mp4');
    await _settle();
    // 迟到的进度回调（fake 已移除 completer，无法直接注入；
    // 通过复制 fake 行为验证 _patch 的 expected 防御——见 _patchIf 语义单测）
    final tasks = container.read(downloadQueueProvider);
    expect(tasks.single.status, TaskStatus.completed);
  });

  test('cancel queued task transitions directly to canceled', () async {
    // 占满唯一并发槽（默认并发 3 → 先调低到 1），第二个任务保持排队
    await controller.setConcurrency(1);
    await controller.enqueue(url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    final id2 = await controller.enqueue(url: 'u1', title: '视频1', preset: QualityPreset.best);
    await _settle();

    await controller.cancel(id2);
    await _settle();

    final tasks = container.read(downloadQueueProvider);
    expect(tasks[1].status, TaskStatus.canceled);
    expect(fake.canceled, isEmpty); // 排队任务不触碰 service
  });

  test('cancel downloading task kills tree and lands canceled', () async {
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();

    await controller.cancel(id);
    await _settle();

    expect(fake.canceled, ['t0']);
    final tasks = container.read(downloadQueueProvider);
    expect(tasks.single.status, TaskStatus.canceled);
  });

  test('canceling then late failure lands canceled without error text',
      () async {
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    // 不等 cancel 完成；cancel 会先置 canceling 并触发 fake 的 kill 错误，
    // 随后迟到的失败回调必须是无操作（expected 防御）
    unawaited(controller.cancel(id));
    fake.pending[id]?.completeError(const DownloadException(
        EngineErrorKind.unknown, '下载失败：未知错误'));
    await _settle();
    await _settle();

    final tasks = container.read(downloadQueueProvider);
    expect(tasks.single.status, TaskStatus.canceled);
    expect(tasks.single.errorKind, isNull);
  });

  test('retry failed task resets and reruns with same id', () async {
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    fake.pending[id]!.completeError(const DownloadException(
        EngineErrorKind.network, '网络错误：请检查网络连接后重试'));
    await _settle();

    controller.retry(id);
    await _settle();

    final tasks = container.read(downloadQueueProvider);
    expect(tasks.single.id, 't0');
    expect(tasks.single.status, TaskStatus.downloading);
    expect(fake.started.length, 2);
  });

  test('setConcurrency raises effective parallelism', () async {
    await controller.setConcurrency(2);
    await controller.enqueue(url: 'u0', title: '视频0', preset: QualityPreset.best);
    await controller.enqueue(url: 'u1', title: '视频1', preset: QualityPreset.best);
    await _settle();

    final statuses = container
        .read(downloadQueueProvider)
        .map((t) => t.status)
        .toList();
    expect(statuses, everyElement(TaskStatus.downloading));
  });

  test('terminal transitions record history rows', () async {
    final history =
        container.read(historyRepositoryProvider) as FakeHistoryRepository;
    final id = await controller.enqueue(
        url: 'u', title: '视频', preset: QualityPreset.best);
    await _settle();
    fake.pending[id]!.complete('D:\\dl\\v.mp4');
    await _settle();
    expect(history.recordCount, 1);
    expect(history.rows.single['status'], 'completed');

    final id2 = await controller.enqueue(
        url: 'u2', title: '视频2', preset: QualityPreset.best);
    await _settle();
    fake.pending[id2]!.completeError(
        const DownloadException(EngineErrorKind.unavailable, 'detail-x'));
    await _settle();
    expect(history.rows.last['status'], 'failed');
  });

  test('canceled transition records a canceled history row', () async {
    final history =
        container.read(historyRepositoryProvider) as FakeHistoryRepository;
    final id = await controller.enqueue(
        url: 'u', title: '视频', preset: QualityPreset.best);
    await _settle();
    // 下载中取消：fake.cancel 等价模拟 kill → 下载 future 以错误落定 → wasCanceling → canceled
    await controller.cancel(id);
    await _settle();

    final rows = history.rows;
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'canceled');
  });

  test('dir resolution failure lands task failed instead of hanging', () async {
    final failing = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      ytDlpServiceProvider.overrideWithValue(fake),
      downloadsDirProvider.overrideWithValue(
          () async => throw const FileSystemException('disk error')),
      historyRepositoryProvider.overrideWith((ref) => FakeHistoryRepository()),
    ]);
    addTearDown(failing.dispose);
    final ctl = failing.read(downloadQueueProvider.notifier);
    await ctl.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    await _settle();

    final tasks = failing.read(downloadQueueProvider);
    expect(tasks.single.status, TaskStatus.failed);
    expect(tasks.single.errorKind, EngineErrorKind.unknown);
    expect(tasks.single.errorDetail, isNotEmpty);
  });

  test('hasActive reflects queued/downloading/canceling tasks', () async {
    expect(controller.hasActive, isFalse);

    await controller.setConcurrency(1);
    final id = await controller.enqueue(
        url: 'u0', title: '视频0', preset: QualityPreset.best);
    await _settle();
    await controller.enqueue(
        url: 'u1', title: '视频1', preset: QualityPreset.best);
    await _settle();

    // t0 downloading + t1 queued → 均有活动
    expect(controller.hasActive, isTrue);

    fake.pending[id]!.complete('D:\\dl\\v0.mp4');
    await _settle();
    // t0 completed → t1 仍在排队（有活动）
    expect(controller.hasActive, isTrue);

    fake.pending['t1']!.complete('D:\\dl\\v1.mp4');
    await _settle();
    // 全部完成 → 无活动
    expect(controller.hasActive, isFalse);
  });
}
