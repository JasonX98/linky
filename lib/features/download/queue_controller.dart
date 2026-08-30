// lib/features/download/queue_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/features/download/providers.dart';

class DownloadQueueController extends Notifier<List<DownloadTask>> {
  int _seq = 0;

  @override
  List<DownloadTask> build() {
    ref.watch(ytDlpServiceProvider);
    ref.listen(settingsProvider, (p, n) {
      if (p?.concurrency != n.concurrency) _startNext();
    });
    return const [];
  }

  YtDlpService get _service => ref.read(ytDlpServiceProvider);

  int get _concurrency => ref.read(settingsProvider).concurrency;

  /// 是否仍有活动任务（排队/下载中/取消中）——供自愈/更新的后台流程判断空闲。
  bool get hasActive => state.any((t) => t.isActive);

  int get runningCount => state
      .where((t) =>
          t.status == TaskStatus.downloading ||
          t.status == TaskStatus.canceling)
      .length;

  Future<String> enqueue({
    required String url,
    required String title,
    required QualityPreset preset,
    String? uploader,
    int? durationSec,
  }) async {
    final id = 't${_seq++}';
    _upsert(DownloadTask(
        id: id, url: url, title: title, preset: preset,
        status: TaskStatus.queued,
        uploader: uploader, durationSec: durationSec));
    _startNext();
    return id;
  }

  Future<void> setConcurrency(int value) {
    // 委托设置层持久化并 clamp；并发变化由 build 中的 ref.listen 触发补位
    ref.read(settingsProvider.notifier).setConcurrency(value);
    return Future<void>.value();
  }

  Future<void> cancel(String id) async {
    final task = _find(id);
    if (task == null) return;
    if (task.status == TaskStatus.queued) {
      _patch(id,
          expected: const {TaskStatus.queued},
          status: TaskStatus.canceled);
      final canceled = _find(id);
      if (canceled != null) unawaited(_recordTerminal(canceled));
      return;
    }
    if (task.status == TaskStatus.downloading) {
      _patch(id,
          expected: const {TaskStatus.downloading},
          status: TaskStatus.canceling);
      await _service.cancel(id);
    }
  }

  void retry(String id) {
    final task = _find(id);
    if (task == null) return;
    if (task.status != TaskStatus.failed &&
        task.status != TaskStatus.canceled) {
      return;
    }
    _patch(id,
        expected: const {TaskStatus.failed, TaskStatus.canceled},
        status: TaskStatus.queued,
        clearProgress: true,
        clearFilePath: true,
        clearError: true);
    _startNext();
  }

  Future<void> openFolder(String id) async {
    final task = _find(id);
    final path = task?.filePath;
    if (task == null || path == null || task.status != TaskStatus.completed) {
      return;
    }
    // /select, 形式在含空格路径下会被参数切分破坏，改为直接打开所在文件夹
    await Process.run('explorer.exe', [p.dirname(path)])
        .then((_) {}, onError: (_) {});
  }

  void _startNext() {
    var running = runningCount;
    while (running < _concurrency) {
      final next = _nextQueued();
      if (next == null) break;
      _begin(next);
      running++;
    }
  }

  DownloadTask? _nextQueued() {
    for (final t in state) {
      if (t.status == TaskStatus.queued) return t;
    }
    return null;
  }

  void _begin(DownloadTask task) {
    _patch(task.id,
        expected: const {TaskStatus.queued},
        status: TaskStatus.downloading);
    unawaited(_run(task));
  }

  Future<void> _run(DownloadTask task) async {
    try {
      // 目录解析置于 try 内：provider 失败落入 catch → 任务落地 failed，
      // finally 仍释放并发槽（Task 4 评审裁定）
      final dir = await ref.read(downloadsDirProvider)();
      final cookieFile = ref.read(settingsProvider).cookieFile;
      final path = await _service.download(
        DownloadRequest(
          url: task.url,
          preset: task.preset,
          outputDir: dir,
          taskId: task.id,
          cookieFile: cookieFile,
        ),
        onProgress: (p) => _patch(task.id,
            expected: const {TaskStatus.downloading}, progress: p),
      );
      _patch(task.id,
          expected: const {TaskStatus.downloading, TaskStatus.canceling},
          status: TaskStatus.completed,
          filePath: path);
      final done = _find(task.id);
      if (done != null) unawaited(_recordTerminal(done));
    } catch (e) {
      final wasCanceling =
          _find(task.id)?.status == TaskStatus.canceling;
      _patch(task.id,
          expected: const {TaskStatus.downloading, TaskStatus.canceling},
          status: wasCanceling ? TaskStatus.canceled : TaskStatus.failed,
          errorKind: wasCanceling ? null : (e is DownloadException ? e.kind : EngineErrorKind.unknown),
          errorDetail: wasCanceling ? null : (e is DownloadException ? e.detail : e.toString()));
      final ended = _find(task.id);
      if (ended != null) unawaited(_recordTerminal(ended));
    } finally {
      scheduleMicrotask(_startNext);
    }
  }

  Future<void> _recordTerminal(DownloadTask t) async {
    try {
      await ref.read(historyRepositoryProvider).record(
          url: t.url, title: t.title, uploader: t.uploader,
          durationSec: t.durationSec, formatLabel: t.preset.name,
          filePath: t.filePath, status: t.status.name,
          errorDetail: t.errorDetail, completedAt: DateTime.now());
    } catch (_) {
      // 历史落库失败不影响任务状态
    }
  }

  DownloadTask? _find(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _upsert(DownloadTask task) {
    state = [...state, task];
  }

  void _patch(
    String id, {
    Set<TaskStatus>? expected,
    TaskStatus? status,
    DownloadProgress? progress,
    String? filePath,
    EngineErrorKind? errorKind,
    String? errorDetail,
    bool clearProgress = false,
    bool clearFilePath = false,
    bool clearError = false,
  }) {
    final current = _find(id);
    if (current == null) return;
    if (expected != null && !expected.contains(current.status)) return;
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(
              status: status,
              progress: progress,
              filePath: filePath,
              errorKind: errorKind,
              errorDetail: errorDetail,
              clearProgress: clearProgress,
              clearFilePath: clearFilePath,
              clearError: clearError)
        else
          t,
    ];
  }
}
