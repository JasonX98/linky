// lib/features/history/history_page.dart
//
// 历史记录页：drift watch 流驱动列表。布局对齐原型 —— 标题区（条数徽标 +
// 最近更新 + 清空记录）、状态筛选 tab、表头、表格式行、空态。
// 行内操作键位（open_file_<id> / open_dir_<id> / redownload_<id> /
// delete_<id>）与空态文案保持不变。

import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_parser.dart';
import 'package:video_downloader/features/download/error_display.dart';
import 'package:video_downloader/features/download/format.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/download/preset_label.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 历史筛选：全部 / 已完成 / 失败（对应数据库 status 字段）。
enum HistoryFilter { all, completed, failed }

/// 行尾操作列宽度：4 个 32px 图标按钮（打开文件/目录仅在有 filePath 时出现，
/// 列宽固定以保证各行列对齐）。
const double _actionColWidth = 128;

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.all;

  bool _match(DownloadHistoryEntry row) => switch (_filter) {
        HistoryFilter.all => true,
        HistoryFilter.completed => row.status == 'completed',
        HistoryFilter.failed => row.status == 'failed',
      };

  Future<void> _clearAll() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => ContentDialog(
            title: Text(s.clearHistoryTitle),
            content: Text(s.clearHistoryConfirm),
            actions: [
              Button(
                child: Text(s.cancel),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              FilledButton(
                child: Text(s.delete),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await ref.read(historyRepositoryProvider).removeAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = ref.watch(historyRepositoryProvider);
    return Column(
      children: [
        AppHeader(title: s.historyTitle, subtitle: s.historySubtitle),
        Expanded(
          child: StreamBuilder<List<DownloadHistoryEntry>>(
            stream: repo.watchRecent(),
            builder: (context, snap) {
              final all = snap.data ?? const <DownloadHistoryEntry>[];
              final rows = all.where(_match).toList(growable: false);
              if (all.isEmpty) {
                return EmptyState(
                    icon: FluentIcons.history, message: s.historyEmpty);
              }
              final last = all
                  .map((r) => r.completedAt ?? r.createdAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b);
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSize.contentMax),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSize.pagePadding,
                      vertical: AppSize.pagePaddingV,
                    ),
                    children: [
                      SectionHeader(
                        title: s.allRecords,
                        subtitle: s.lastUpdated(formatHistoryTime(context, last)),
                        count: s.recordCount(all.length),
                        trailing: GhostButton(
                          label: s.clearHistory,
                          icon: FluentIcons.delete,
                          onPressed: _clearAll,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _filterTabs(all),
                      const SizedBox(height: 4),
                      _table(rows),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterTabs(List<DownloadHistoryEntry> all) {
    final s = S.of(context);
    int count(bool Function(DownloadHistoryEntry) test) =>
        all.where(test).length;
    final tabs = <({HistoryFilter value, String label, int count})>[
      (value: HistoryFilter.all, label: s.filterAll, count: all.length),
      (
        value: HistoryFilter.completed,
        label: s.statusCompleted,
        count: count((r) => r.status == 'completed')
      ),
      (
        value: HistoryFilter.failed,
        label: s.statusFailed,
        count: count((r) => r.status == 'failed')
      ),
    ];
    return Row(
      children: [
        for (final t in tabs)
          FilterTab(
            key: Key('filter_${t.value.name}_tab'),
            label: t.label,
            count: t.count,
            selected: _filter == t.value,
            onTap: () => setState(() => _filter = t.value),
          ),
      ],
    );
  }

  Widget _table(List<DownloadHistoryEntry> rows) {
    final s = S.of(context);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: EmptyState(
            icon: FluentIcons.filter, message: s.historyFilterEmpty),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.colFileName, style: AppText.chip()),
                ),
                SizedBox(width: 130, child: Text(s.colFormat, style: AppText.chip())),
                SizedBox(width: 130, child: Text(s.colTime, style: AppText.chip())),
                SizedBox(width: 92, child: Text(s.colStatus, style: AppText.chip())),
                const SizedBox(width: _actionColWidth),
              ],
            ),
          ),
          for (final row in rows) _historyRow(row),
        ],
      ),
    );
  }

  Widget _historyRow(DownloadHistoryEntry row) {
    final s = S.of(context);
    final hasFile = row.filePath != null;
    final style = _statusStyle(row.status);
    final dir = hasFile ? p.dirname(row.filePath!) : '';
    return Container(
      key: Key('history_row_${row.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                IconTile(
                  icon: _iconFor(row),
                  color: style.color,
                  size: 36,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title.isEmpty ? s.unknownTitle : row.title,
                        style: AppText.label(
                            color: AppColors.textBody,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dir.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(dir,
                            style: AppText.chip(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      // 失败行弱化展示错误原因：历史只存 raw summary，
                      // 用 classify 反推 kind 后走统一 ErrorMessage（core 友好
                      // + raw 弱化副行）
                      if (row.status == 'failed' &&
                          row.errorSummary?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        ErrorMessage(
                          kind: classifyYtDlpError(row.errorSummary!).kind,
                          detail: row.errorSummary!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(_formatPreset(row.formatLabel),
                style: AppText.meta(color: AppColors.textBody),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 130,
            child: Text(
              formatHistoryTime(context, row.completedAt ?? row.createdAt),
              style: AppText.meta(),
            ),
          ),
          SizedBox(
            width: 92,
            child: Row(
              children: [
                StatusDot(color: style.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(style.label(s),
                      style: AppText.meta(color: style.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _actionColWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasFile)
                  _RowAction(
                    key: Key('open_file_${row.id}'),
                    icon: FluentIcons.document,
                    tooltip: s.openFile,
                    onPressed: () => unawaited(Process.run(
                            'explorer.exe', [row.filePath!])
                        .then((_) {}, onError: (_) {})),
                  ),
                if (hasFile)
                  _RowAction(
                    key: Key('open_dir_${row.id}'),
                    icon: FluentIcons.folder_open,
                    tooltip: s.openFolder,
                    onPressed: () => unawaited(Process.run(
                            'explorer.exe', [p.dirname(row.filePath!)])
                        .then((_) {}, onError: (_) {})),
                  ),
                _RowAction(
                  key: Key('redownload_${row.id}'),
                  icon: FluentIcons.redo,
                  tooltip: s.retry,
                  onPressed: () => unawaited(ref
                      .read(downloadQueueProvider.notifier)
                      .enqueue(
                          url: row.url,
                          title: row.title,
                          preset: QualityPreset.values.firstWhere(
                              (q) => q.name == row.formatLabel,
                              orElse: () => QualityPreset.best))),
                ),
                _RowAction(
                  key: Key('delete_${row.id}'),
                  icon: FluentIcons.delete,
                  tooltip: s.delete,
                  onPressed: () => unawaited(ref
                      .read(historyRepositoryProvider)
                      .deleteById(row.id)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DownloadHistoryEntry row) => switch (row.status) {
        'completed' => FluentIcons.video,
        'failed' => FluentIcons.error,
        _ => FluentIcons.cancel,
      };

  _StatusStyle _statusStyle(String status) => switch (status) {
        'completed' =>
          _StatusStyle(color: AppColors.success, label: (s) => s.statusCompleted),
        'failed' => _StatusStyle(color: AppColors.danger, label: (s) => s.statusFailed),
        _ => _StatusStyle(color: AppColors.textMuted, label: (s) => s.statusCanceled),
      };

  /// 数据库存的是 preset 名（best/p1080/...），取不到时原样显示。
  String _formatPreset(String label) {
    for (final q in QualityPreset.values) {
      if (q.name == label) return presetLabel(context, q);
    }
    return label;
  }
}

class _StatusStyle {
  const _StatusStyle({required this.color, required this.label});

  final Color color;
  final String Function(S) label;
}

/// 行内图标操作按钮。
class _RowAction extends StatelessWidget {
  const _RowAction({
    required Key key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  }) : super(key: key);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 16, color: AppColors.textMuted),
          onPressed: onPressed,
          style: const ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      );
}
