// lib/features/history/history_page.dart
import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_parser.dart';
import 'package:video_downloader/features/download/error_display.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

/// 历史记录页：drift watch 流驱动列表，行内四操作
/// （打开文件/打开目录/重新下载/删除），空态本地化文案
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final repo = ref.watch(historyRepositoryProvider);
    return ScaffoldPage(
      content: StreamBuilder<List<DownloadHistoryEntry>>(
        stream: repo.watchRecent(),
        builder: (context, snap) {
          final rows = snap.data ?? const <DownloadHistoryEntry>[];
          if (rows.isEmpty) {
            return Center(child: Text(s.historyEmpty));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) => _row(context, ref, rows[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, DownloadHistoryEntry row) {
    final s = S.of(context);
    final hasFile = row.filePath != null;
    return Card(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.title.isEmpty ? s.unknownTitle : row.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text(_statusBadge(s, row.status)),
                const SizedBox(width: 8),
                Text(_formatTime(row.completedAt ?? row.createdAt)),
              ]),
              if (row.status == 'failed' &&
                  row.errorSummary?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                // 历史只存 raw summary 无 kind：用 classify 反推 kind 再走统一
                // displayError/ErrorMessage，保证 core 友好 + detail 弱化副行
                ErrorMessage(
                  kind: classifyYtDlpError(row.errorSummary!).kind,
                  detail: row.errorSummary!,
                ),
              ],
            ],
          ),
        ),
        if (hasFile) ...[
          Button(
            key: Key('open_file_${row.id}'),
            // cmd start 的引号转义不可靠（第一个引号参数会被当窗口标题），
            // explorer <文件> 按系统关联程序打开且正确处理空格路径
                onPressed: () => unawaited(Process.run('explorer.exe', [row.filePath!])
                    .then((_) {}, onError: (_) {})),
            child: Text(s.openFile),
          ),
          const SizedBox(width: 8),
          Button(
            key: Key('open_dir_${row.id}'),
            onPressed: () => unawaited(Process.run(
                    'explorer.exe', [p.dirname(row.filePath!)])
                .then((_) {}, onError: (_) {})),
            child: Text(s.openFolder),
          ),
          const SizedBox(width: 8),
        ],
        Button(
          key: Key('redownload_${row.id}'),
          onPressed: () => unawaited(ref
              .read(downloadQueueProvider.notifier)
              .enqueue(
                  url: row.url,
                  title: row.title,
                  preset: QualityPreset.values.firstWhere(
                      (p) => p.name == row.formatLabel,
                      orElse: () => QualityPreset.best))),
          child: Text(s.retry),
        ),
        const SizedBox(width: 8),
        Button(
          key: Key('delete_${row.id}'),
          onPressed: () => unawaited(
              ref.read(historyRepositoryProvider).deleteById(row.id)),
          child: Text(s.delete),
        ),
      ]),
    );
  }

  String _statusBadge(S s, String status) {
    switch (status) {
      case 'completed':
        return s.statusCompleted;
      case 'failed':
        return s.statusFailed;
      case 'canceled':
        return s.statusCanceled;
    }
    return status;
  }

  /// yyyy-MM-dd HH:mm 手工补零（不引入 intl 依赖）
  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}'
        ' ${two(t.hour)}:${two(t.minute)}';
  }
}
