// lib/features/download/download_page.dart
//
// 下载页 = 头部 + 链接输入卡 + 解析结果（单视频预览 / 播放列表勾选）+ 任务列表。
// 交互键位（url_field / analyze_button / enqueue_button / entry_list /
// check_<url> / cancel_<id> / retry_<id> / open_<id>）全部保留，仅重做视觉。

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/analysis_controller.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/features/download/error_display.dart';
import 'package:video_downloader/features/download/format.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/download/preset_label.dart';
import 'package:video_downloader/features/settings/engine_update_action.dart';
import 'package:video_downloader/features/shell/app_shell.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';
import 'package:video_downloader/theme/widgets.dart';

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
  bool _hasText = false;

  Set<String> _allUrls(PlaylistMeta meta) =>
      {for (final e in meta.entries) e.url};

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final has = _urlCtrl.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

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
        title: video.title.isEmpty ? S.of(context).unknownTitle : video.title,
        preset: _preset,
        uploader: video.uploader,
        durationSec: video.durationSec);
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
    final concurrency = ref.watch(settingsProvider).concurrency;
    return Column(
      children: [
        AppHeader(
          title: s.downloadTitle,
          subtitle: s.downloadSubtitle,
          action: const CheckUpdateButton(),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.pagePadding,
                  vertical: AppSize.pagePaddingV,
                ),
                children: [
                  _urlCard(analysis),
                  if (analysis is AnalysisPlaylist) ...[
                    const SizedBox(height: 24),
                    _playlistCard(analysis.meta),
                  ] else if (analysis is AnalysisVideo) ...[
                    const SizedBox(height: 24),
                    _previewCard(analysis.meta),
                  ],
                  const SizedBox(height: 32),
                  SectionHeader(
                    title: s.activeTasks,
                    subtitle: s.concurrencyLabel(concurrency),
                    count: s.taskCount(tasks.length),
                    trailing: HyperlinkButton(
                      onPressed: () => ref
                          .read(appShellIndexProvider.notifier)
                          .state = 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.viewAllHistory,
                              style: AppText.label(color: AppColors.accent)),
                          const SizedBox(width: 4),
                          const Icon(FluentIcons.arrow_up_right,
                              size: 12, color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: EmptyState(
                          icon: FluentIcons.cloud_download,
                          message: s.noActiveTasks),
                    )
                  else
                    for (final t in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _taskCard(t),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ——— 链接输入卡 ———

  Widget _urlCard(AnalysisState analysis) {
    final s = S.of(context);
    final analyzing = analysis is AnalysisLoading;
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: FluentIcons.link,
                size: 24,
                iconSize: 14,
                radius: 6,
              ),
              const SizedBox(width: 8),
              Text(s.newTask,
                  style: AppText.label(
                      color: AppColors.textBody, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 24),
          Text(s.videoUrl, style: AppText.label()),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            // 窄栏时把 130px 的主按钮换到输入框下方，否则按钮的固定宽度会
            // 把 Row 撑爆（RenderFlex 右溢出）
            final stacked = c.maxWidth < AppSize.urlRowBreakpoint;
            final field = SizedBox(
              height: AppSize.input,
              child: TextBox(
                key: const Key('url_field'),
                controller: _urlCtrl,
                placeholder: s.urlPlaceholder,
                placeholderStyle: AppText.label(color: AppColors.textDim),
                style: AppText.body(color: AppColors.textPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                highlightColor: Colors.transparent,
                unfocusedColor: Colors.transparent,
                decoration:
                    WidgetStateProperty.resolveWith<BoxDecoration>((states) {
                  final focused = states.contains(WidgetState.focused);
                  return BoxDecoration(
                    color: AppColors.bgBase,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                    border: Border.all(
                      color: focused ? AppColors.accent : AppColors.borderInput,
                    ),
                  );
                }),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 12),
                  child: Icon(FluentIcons.globe,
                      size: 17, color: AppColors.textMuted),
                ),
                suffix: _hasText
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(FluentIcons.clear, size: 12),
                          onPressed: _urlCtrl.clear,
                          style: const ButtonStyle(
                            backgroundColor:
                                WidgetStatePropertyAll(Colors.transparent),
                          ),
                        ),
                      )
                    : null,
                onSubmitted: (_) => _analyze(),
              ),
            );
            return Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                // 纵向时用固定高度（Expanded 在 Column 里会抢纵向空间），
                // 横向时才 Expanded 占满剩余宽度
                stacked ? field : Expanded(child: field),
                SizedBox(width: stacked ? 0 : 12, height: stacked ? 12 : 0),
                PrimaryButton(
                  key: const Key('analyze_button'),
                  label: analyzing ? s.analyzing : s.analyze,
                  icon: FluentIcons.lightbulb,
                  // null → 交给父级约束（堆叠时由 CrossAxisAlignment.stretch 撑满）
                  width: stacked ? null : 130,
                  height: AppSize.input,
                  onPressed: analyzing ? null : _analyze,
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          _statusLine(analysis),
        ],
      ),
    );
  }

  Widget _statusLine(AnalysisState analysis) {
    final s = S.of(context);
    final Widget content;
    Color color = AppColors.textSecondary;
    IconData icon = FluentIcons.info;
    switch (analysis) {
      case AnalysisIdle():
        content = Text(s.parseHint, style: AppText.meta());
      case AnalysisLoading():
        content =
            Text(s.analyzing, style: AppText.meta(color: AppColors.accent));
        color = AppColors.accent;
        icon = FluentIcons.sync;
      case AnalysisError():
        // 错误文案统一走 ErrorMessage：core 本地化友好文案，raw 仅作弱化副行。
        // 全页仅此一处渲染，避免同一 raw 文案在树上出现多次。
        content = ErrorMessage(kind: analysis.kind, detail: analysis.message);
        color = AppColors.danger;
        icon = FluentIcons.error;
      case AnalysisVideo():
      case AnalysisPlaylist():
        content = Text(s.parseSuccess,
            style: AppText.meta(color: AppColors.successText));
        color = AppColors.success;
        icon = FluentIcons.check_mark;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(child: content),
      ],
    );
  }

  // ——— 单视频预览卡 ———

  Widget _previewCard(VideoMeta video) {
    final s = S.of(context);
    final duration = formatClock(video.durationSec ?? 0);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
            ),
            child: Row(
              children: [
                const StatusDot(color: AppColors.success, size: 8),
                const SizedBox(width: 8),
                Text(s.parseReady, style: AppText.label(
                    color: AppColors.textBody, weight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s.readyBadge,
                      style: AppText.chip(
                          color: AppColors.successText,
                          weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 560;
              final thumb = _thumbnail(video, wide);
              final info = _previewInfo(video, duration);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 20),
                    Expanded(child: info),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [thumb, const SizedBox(height: 16), info],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(VideoMeta video, bool wide) {
    final s = S.of(context);
    return Container(
      width: wide ? 220 : double.infinity,
      height: wide ? 124 : 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.field),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F3A44), Color(0xFF0F172A), Color(0xFF0B1120)],
        ),
      ),
      child: video.thumbnailUrl == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.play, size: 34, color: AppColors.accent),
                const SizedBox(height: 8),
                Text(s.previewPlaceholder, style: AppText.meta(
                    color: const Color(0xFF9FD9E6))),
              ],
            )
          : Image.network(
              video.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(FluentIcons.play, size: 34, color: AppColors.accent),
              ),
            ),
    );
  }

  Widget _previewInfo(VideoMeta video, String duration) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.title.isEmpty ? s.unknownTitle : video.title,
          style: AppText.section(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          s.videoMeta(video.uploader ?? s.unknownUploader, duration),
          style: AppText.meta(),
        ),
        const SizedBox(height: 20),
        Text(s.qualityLabel, style: AppText.meta()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in QualityPreset.values)
              QualityChip(
                label: presetLabel(context, p),
                selected: p == _preset,
                onTap: () => setState(() => _preset = p),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryButton(
            key: const Key('enqueue_button'),
            label: s.addToDownload,
            icon: FluentIcons.download,
            onPressed: _enqueue,
          ),
        ),
      ],
    );
  }

  // ——— 播放列表 ———

  Widget _playlistCard(PlaylistMeta meta) {
    final s = S.of(context);
    final selected = _selectedUrls ?? _allUrls(meta);
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(
                  icon: FluentIcons.video,
                  size: 32,
                  iconSize: 16,
                  radius: 6),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.playlistNotice(meta.title ?? '', meta.entries.length),
                  style: AppText.label(
                      color: AppColors.textBody, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 列表高度有界：外层整页可滚动，条目多时列表内部滚动
          SizedBox(
            height: 300,
            child: ListView.builder(
              key: const Key('entry_list'),
              itemCount: meta.entries.length,
              itemBuilder: (context, i) {
                final e = meta.entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _entryRow(e, i, selected.contains(e.url)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GhostButton(
                key: const Key('selectAll_button'),
                label: s.selectAll,
                onPressed: _selectAll,
              ),
              const SizedBox(width: 8),
              GhostButton(
                key: const Key('invertSelection_button'),
                label: s.invertSelection,
                onPressed: _invertSelection,
              ),
              const Spacer(),
              Text(
                s.selectedCount(selected.length, meta.entries.length),
                style: AppText.meta(),
              ),
              const SizedBox(width: 16),
              PrimaryButton(
                key: const Key('enqueue_button'),
                label: s.addToDownload,
                icon: FluentIcons.download,
                onPressed: selected.isEmpty ? null : _enqueuePlaylist,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entryRow(PlaylistEntry e, int index, bool checked) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Checkbox(
            key: Key('check_${e.url}'),
            checked: checked,
            onChanged: (v) => _toggleEntry(e.url, v ?? false),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.titleIsFallback ? s.episodeNumber(index + 1) : e.title,
              style: AppText.label(color: AppColors.textBody),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (e.durationSec != null) ...[
            const SizedBox(width: 10),
            Text(formatClock(e.durationSec!), style: AppText.meta()),
          ],
        ],
      ),
    );
  }

  // ——— 任务卡 ———

  Widget _taskCard(DownloadTask t) {
    final s = S.of(context);
    final style = _taskStyle(t);
    final canCancel =
        t.status == TaskStatus.queued || t.status == TaskStatus.downloading;
    final canRetry =
        t.status == TaskStatus.failed || t.status == TaskStatus.canceled;
    // 正在下载/取消中的任务不允许删除（防止丢进度）
    final canDelete = t.status != TaskStatus.downloading &&
        t.status != TaskStatus.canceling;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: style.icon, color: style.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.title,
                        style: AppText.label(
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(style.trailing(context, t),
                        style: AppText.label(
                            color: style.color, weight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                _taskMeta(t),
                const SizedBox(height: 12),
                AppProgressBar(
                  value: style.progress(t),
                  color: style.color,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canCancel)
                _IconAction(
                  key: Key('cancel_${t.id}'),
                  icon: FluentIcons.cancel,
                  tooltip: s.cancel,
                  onPressed: () => unawaited(ref
                      .read(downloadQueueProvider.notifier)
                      .cancel(t.id)),
                ),
              if (canRetry)
                _IconAction(
                  key: Key('retry_${t.id}'),
                  icon: FluentIcons.redo,
                  tooltip: s.retry,
                  onPressed: () =>
                      ref.read(downloadQueueProvider.notifier).retry(t.id),
                ),
              if (t.status == TaskStatus.completed)
                _IconAction(
                  key: Key('open_${t.id}'),
                  icon: FluentIcons.folder_open,
                  tooltip: s.openFolder,
                  onPressed: () => unawaited(ref
                      .read(downloadQueueProvider.notifier)
                      .openFolder(t.id)),
                ),
              // 删除按钮：所有非活动状态可点，下载中/取消中禁用
              _IconAction(
                key: Key('delete_${t.id}'),
                icon: FluentIcons.delete,
                tooltip: s.delete,
                onPressed: canDelete
                    ? () => ref.read(downloadQueueProvider.notifier).remove(t.id)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 元信息行：画质 + 速度/剩余（下载中）、输出路径（完成）、错误原因（失败）。
  /// 状态文案统一由右上角的 [trailing] 承担，此处不再重复，避免同一文案在树上
  /// 出现两次（`find.text` 会因此报 multiple widgets）。
  Widget _taskMeta(DownloadTask t) {
    final s = S.of(context);
    final p = t.progress;
    switch (t.status) {
      case TaskStatus.queued:
      case TaskStatus.canceling:
      case TaskStatus.canceled:
        return Text(presetLabel(context, t.preset), style: AppText.meta());
      case TaskStatus.downloading:
        final parts = <String>[presetLabel(context, t.preset)];
        final eta = p?.etaSeconds;
        final speed = p?.speed;
        if (eta != null) parts.add(s.etaLabel(eta));
        if (speed != null) parts.add(speed);
        return Text(parts.join(' · '),
            style: AppText.meta(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis);
      case TaskStatus.completed:
        return Text('${presetLabel(context, t.preset)} · ${s.statusDone(t.filePath ?? '')}',
            style: AppText.meta(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis);
      case TaskStatus.failed:
        return Row(
          children: [
            Text('${presetLabel(context, t.preset)} · ',
                style: AppText.meta()),
            Expanded(
              child: ErrorMessage(
                kind: t.errorKind ?? EngineErrorKind.unknown,
                detail: t.errorDetail ?? '',
              ),
            ),
          ],
        );
    }
  }

  _TaskStyle _taskStyle(DownloadTask t) => switch (t.status) {
        TaskStatus.queued => _TaskStyle(
            icon: FluentIcons.history,
            color: AppColors.textMuted,
            progress: (_) => 0,
            trailing: (context, _) => S.of(context).statusQueued,
          ),
        TaskStatus.downloading => _TaskStyle(
            icon: FluentIcons.video,
            color: AppColors.accent,
            progress: (task) => task.progress?.fraction ?? 0,
            trailing: (context, task) =>
                '${((task.progress?.fraction ?? 0) * 100).toStringAsFixed(1)}%',
          ),
        TaskStatus.canceling => _TaskStyle(
            icon: FluentIcons.video,
            color: AppColors.textMuted,
            progress: (task) => task.progress?.fraction ?? 0,
            trailing: (context, _) => S.of(context).statusCanceling,
          ),
        TaskStatus.completed => _TaskStyle(
            icon: FluentIcons.check_mark,
            color: AppColors.success,
            progress: (_) => 1,
            trailing: (context, _) => S.of(context).statusCompleted,
          ),
        TaskStatus.failed => _TaskStyle(
            icon: FluentIcons.error,
            color: AppColors.danger,
            progress: (_) => 0,
            trailing: (context, _) => S.of(context).statusFailed,
          ),
        TaskStatus.canceled => _TaskStyle(
            icon: FluentIcons.cancel,
            color: AppColors.textMuted,
            progress: (_) => 0,
            trailing: (context, _) => S.of(context).statusCanceled,
          ),
      };

  @override
  void dispose() {
    _urlCtrl.removeListener(_onUrlChanged);
    _urlCtrl.dispose();
    super.dispose();
  }
}

/// 任务行的图标 / 主色 / 进度 / 右上状态文案。
class _TaskStyle {
  const _TaskStyle({
    required this.icon,
    required this.color,
    required this.progress,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final double Function(DownloadTask) progress;
  final String Function(BuildContext, DownloadTask) trailing;
}

/// 任务行右侧的纯图标操作按钮（取消 / 重试 / 打开文件夹 / 删除）。
/// [onPressed] 为 null 时按钮禁用（用于下载中不可删除的场景）。
class _IconAction extends StatelessWidget {
  const _IconAction({
    required Key key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  }) : super(key: key);

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 17, color: AppColors.textMuted),
          onPressed: onPressed,
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textDim;
              }
              return AppColors.textMuted;
            }),
          ),
        ),
      );
}
