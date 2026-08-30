// lib/features/download/download_page.dart
import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/analysis_controller.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/features/download/error_display.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/download/preset_label.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  final _urlCtrl = TextEditingController();
  QualityPreset _preset = QualityPreset.best;
  /// null = 默认全选（分析成功后的初始状态）
  Set<String>? _selectedUrls;

  Set<String> _allUrls(PlaylistMeta meta) =>
      {for (final e in meta.entries) e.url};

  Future<void> _analyze() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    _selectedUrls = null;
    await ref.read(analysisProvider.notifier).analyze(url);
  }

  Future<void> _enqueue() async {
    final analysis = ref.read(analysisProvider);
    if (analysis is! AnalysisVideo) return;
    final video = analysis.meta;
    final url = video.webUrl.isNotEmpty ? video.webUrl : _urlCtrl.text.trim();
    await ref.read(downloadQueueProvider.notifier).enqueue(
        url: url,
        title: video.title.isEmpty
            ? S.of(context).unknownTitle
            : video.title,
        preset: _preset,
        uploader: video.uploader, durationSec: video.durationSec);
    if (!mounted) return;
    ref.read(analysisProvider.notifier).reset();
    _urlCtrl.clear();
  }

  void _toggleEntry(String url, bool checked) {
    final analysis = ref.read(analysisProvider);
    if (analysis is! AnalysisPlaylist) return;
    final current = _selectedUrls ?? _allUrls(analysis.meta);
    final next = {...current};
    if (checked) {
      next.add(url);
    } else {
      next.remove(url);
    }
    setState(() => _selectedUrls = next);
  }

  void _selectAll() {
    final analysis = ref.read(analysisProvider);
    if (analysis is! AnalysisPlaylist) return;
    setState(() => _selectedUrls = _allUrls(analysis.meta));
  }

  void _invertSelection() {
    final analysis = ref.read(analysisProvider);
    if (analysis is! AnalysisPlaylist) return;
    final current = _selectedUrls ?? _allUrls(analysis.meta);
    setState(() {
      _selectedUrls = {
        for (final e in analysis.meta.entries)
          if (!current.contains(e.url)) e.url
      };
    });
  }

  Future<void> _enqueuePlaylist() async {
    final analysis = ref.read(analysisProvider);
    if (analysis is! AnalysisPlaylist) return;
    final selected = _selectedUrls ?? _allUrls(analysis.meta);
    if (selected.isEmpty) return;
    final queue = ref.read(downloadQueueProvider.notifier);
    final s = S.of(context);
    var order = 0;
    for (final e in analysis.meta.entries) {
      order++;
      if (!selected.contains(e.url)) continue;
      await queue.enqueue(
          url: e.url,
          title: e.titleIsFallback ? s.episodeNumber(order) : e.title,
          preset: _preset,
          durationSec: e.durationSec);
    }
    if (!mounted) return;
    ref.read(analysisProvider.notifier).reset();
    _urlCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final analysis = ref.watch(analysisProvider);
    final tasks = ref.watch(downloadQueueProvider);
    final analyzing = analysis is AnalysisLoading;
    return ScaffoldPage(
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextBox(
                  key: const Key('url_field'),
                  controller: _urlCtrl,
                  placeholder: s.urlPlaceholder,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('analyze_button'),
                onPressed: analyzing ? null : _analyze,
                child: Text(analyzing ? s.analyzing : s.analyze),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              s.downloadCookieHint,
              style: TextStyle(
                fontSize: 12,
                color: FluentTheme.of(context).typography.body?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            _analysisView(analysis),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.taskList),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, i) => _taskRow(tasks[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisView(AnalysisState analysis) {
    if (analysis is AnalysisIdle) return const SizedBox.shrink();
    if (analysis is AnalysisLoading) return const ProgressBar();
    if (analysis is AnalysisError) {
      return InfoBar(
          severity: InfoBarSeverity.warning,
          title: ErrorMessage(kind: analysis.kind, detail: analysis.message));
    }
    final s = S.of(context);
    if (analysis is AnalysisPlaylist) {
      // Flexible 而非 Expanded：与任务列表共享剩余空间，条目多时列表内部滚动
      return Flexible(child: _playlistView(analysis.meta));
    }
    final video = (analysis as AnalysisVideo).meta;
    return Card(
      child: Row(children: [
        SizedBox(
          width: 120,
          height: 68,
          child: video.thumbnailUrl == null
              ? const Center(child: Icon(FluentIcons.video))
              : Image.network(video.thumbnailUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(FluentIcons.video))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(video.title.isEmpty ? s.unknownTitle : video.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                  '${video.uploader ?? s.unknownUploader} · ${s.durationSeconds(video.durationSec ?? 0)}'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ComboBox<QualityPreset>(
          value: _preset,
          items: [
            for (final p in QualityPreset.values)
              ComboBoxItem(value: p, child: Text(presetLabel(context, p))),
          ],
          onChanged: (v) => setState(() => _preset = v ?? _preset),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('enqueue_button'),
          onPressed: _enqueue,
          child: Text(s.addToDownload),
        ),
      ]),
    );
  }

  Widget _playlistView(PlaylistMeta meta) {
    final s = S.of(context);
    final selected = _selectedUrls ?? _allUrls(meta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
            severity: InfoBarSeverity.info,
            title: Text(s.playlistNotice(meta.title ?? '', meta.entries.length))),
        const SizedBox(height: 8),
        // 高度自适应：空间充裕时长到 420，紧张时收缩并在列表内滚动
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.builder(
              key: const Key('entry_list'),
              itemCount: meta.entries.length,
              itemBuilder: (context, i) {
                final e = meta.entries[i];
                return Card(
                  child: Row(children: [
                    Checkbox(
                      key: Key('check_${e.url}'),
                      checked: selected.contains(e.url),
                      onChanged: (v) => _toggleEntry(e.url, v ?? false),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.titleIsFallback
                            ? s.episodeNumber(i + 1)
                            : e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e.durationSec != null) ...[
                      const SizedBox(width: 8),
                      Text(s.durationSeconds(e.durationSec!)),
                    ],
                  ]),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Button(
            key: const Key('selectAll_button'),
            onPressed: _selectAll,
            child: Text(s.selectAll),
          ),
          const SizedBox(width: 8),
          Button(
            key: const Key('invertSelection_button'),
            onPressed: _invertSelection,
            child: Text(s.invertSelection),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                s.selectedCount(selected.length, meta.entries.length),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('enqueue_button'),
            onPressed: selected.isEmpty ? null : _enqueuePlaylist,
            child: Text(s.addToDownload),
          ),
        ]),
      ],
    );
  }

  Widget _taskRow(DownloadTask t) {
    final s = S.of(context);
    final canCancel =
        t.status == TaskStatus.queued || t.status == TaskStatus.downloading;
    final canRetry =
        t.status == TaskStatus.failed || t.status == TaskStatus.canceled;
    return Card(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              _statusLine(t),
            ],
          ),
        ),
        if (canCancel)
          Button(
            key: Key('cancel_${t.id}'),
            onPressed: () =>
                unawaited(ref.read(downloadQueueProvider.notifier).cancel(t.id)),
            child: Text(s.cancel),
          ),
        if (canRetry)
          Button(
            key: Key('retry_${t.id}'),
            onPressed: () => ref.read(downloadQueueProvider.notifier).retry(t.id),
            child: Text(s.retry),
          ),
        if (t.status == TaskStatus.completed)
          Button(
            key: Key('open_${t.id}'),
            onPressed: () => unawaited(
                ref.read(downloadQueueProvider.notifier).openFolder(t.id)),
            child: Text(s.openFolder),
          ),
      ]),
    );
  }

  Widget _statusLine(DownloadTask t) {
    final s = S.of(context);
    switch (t.status) {
      case TaskStatus.queued:
        return Text(s.statusQueued);
      case TaskStatus.downloading:
        final p = t.progress;
        final speed = p?.speed;
        final eta = p?.etaSeconds;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressBar(value: (p?.fraction ?? 0) * 100),
            const SizedBox(height: 2),
            Text(p == null
                ? s.statusDownloading
                : '${(p.fraction * 100).toStringAsFixed(1)}%'
                    '${speed != null ? '  ${s.speedLabel} $speed' : ''}'
                    '${eta != null ? '  ${s.etaLabel(eta)}' : ''}'),
          ],
        );
      case TaskStatus.canceling:
        return Text(s.statusCanceling);
      case TaskStatus.completed:
        return Text(s.statusDone(t.filePath ?? ''));
      case TaskStatus.failed:
        return ErrorMessage(
            kind: t.errorKind ?? EngineErrorKind.unknown,
            detail: t.errorDetail ?? '');
      case TaskStatus.canceled:
        return Text(s.statusCanceled);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }
}
