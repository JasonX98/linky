// test/ui/history_page_test.dart
import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/history/history_page.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'download_page_test.dart' show FakeUiService;

DownloadHistoryEntry entry({
  required int id,
  required String title,
  required String status,
  String url = 'https://example.com/v',
  String formatLabel = 'best',
  String? filePath,
  String? errorSummary,
  required DateTime createdAt,
  DateTime? completedAt,
}) {
  return DownloadHistoryEntry(
    id: id,
    url: url,
    title: title,
    formatLabel: formatLabel,
    filePath: filePath,
    status: status,
    errorSummary: errorSummary,
    createdAt: createdAt,
    completedAt: completedAt,
  );
}

/// 内存假仓库：watchRecent 先发当前快照再跟随变更，deleteById 就地删除并重发
class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository([List<DownloadHistoryEntry>? initial])
      : rows = [...?initial];

  final List<DownloadHistoryEntry> rows;
  final _ctrl =
      StreamController<List<DownloadHistoryEntry>>.broadcast();

  @override
  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) async* {
    yield List.unmodifiable(rows);
    yield* _ctrl.stream;
  }

  @override
  Future<void> deleteById(int id) async {
    rows.removeWhere((r) => r.id == id);
    _ctrl.add(List.unmodifiable(rows));
  }

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
  }) async {}

  @override
  Future<List<DownloadHistoryEntry>> recentEntries({int limit = 200}) async =>
      List.unmodifiable(rows);

  @override
  Future<int> removeAll() async {
    final n = rows.length;
    rows.clear();
    _ctrl.add(List.unmodifiable(rows));
    return n;
  }
}

// 固定 zh，断言本地化徽标/空态文案
late SharedPreferences prefs;

Widget wrap(List<DownloadHistoryEntry> rows) => ProviderScope(
      overrides: [
        // pendingDownload：重下载任务停在 downloading，队列状态确定性可断言
        ytDlpServiceProvider
            .overrideWithValue(FakeUiService(pendingDownload: true)),
        // 真实 DownloadQueueController 依赖 settings/下载目录，须注入测试替身
        sharedPrefsProvider.overrideWithValue(prefs),
        downloadsDirProvider.overrideWithValue(() async => r'C:\tmp'),
        historyRepositoryProvider
            .overrideWith((ref) => FakeHistoryRepository(rows)),
      ],
      child: FluentApp(
        locale: const Locale('zh'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const HistoryPage(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'language': 'zh'});
    prefs = await SharedPreferences.getInstance();
  });

  final completed = entry(
    id: 1,
    title: '视频A',
    status: 'completed',
    filePath: r'C:\dl\a.mp4',
    createdAt: DateTime(2026, 1, 2, 3, 4),
    completedAt: DateTime(2026, 1, 2, 3, 4),
  );
  final failed = entry(
    id: 2,
    title: '视频B',
    status: 'failed',
    errorSummary: '网络错误：请检查网络连接后重试',
    createdAt: DateTime(2026, 1, 3, 5, 6),
  );

  testWidgets('renders titles, localized badges, time and conditional actions',
      (tester) async {
    await tester.pumpWidget(wrap([completed, failed]));
    await tester.pumpAndSettle();

    expect(find.text('视频A'), findsOneWidget);
    expect(find.text('视频B'), findsOneWidget);
    // 状态徽标本地化（completed/failed/canceled）
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    // 完成时间 yyyy-MM-dd HH:mm；failed 无 completedAt 回退 createdAt
    expect(find.text('2026-01-02 03:04'), findsOneWidget);
    expect(find.text('2026-01-03 05:06'), findsOneWidget);
    // failed 行弱化展示错误详情
    expect(find.text('网络错误：请检查网络连接后重试'), findsOneWidget);
    // 有 filePath 才渲染打开文件/目录；redownload/delete 始终渲染
    expect(find.byKey(const Key('open_file_1')), findsOneWidget);
    expect(find.byKey(const Key('open_dir_1')), findsOneWidget);
    expect(find.byKey(const Key('open_file_2')), findsNothing);
    expect(find.byKey(const Key('open_dir_2')), findsNothing);
    expect(find.byKey(const Key('redownload_1')), findsOneWidget);
    expect(find.byKey(const Key('redownload_2')), findsOneWidget);
    expect(find.byKey(const Key('delete_1')), findsOneWidget);
    expect(find.byKey(const Key('delete_2')), findsOneWidget);
  });

  testWidgets('empty history shows placeholder', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();
    expect(find.text('暂无下载记录'), findsOneWidget);
  });

  testWidgets('tap delete_<id> removes the row', (tester) async {
    await tester.pumpWidget(wrap([completed]));
    await tester.pumpAndSettle();
    expect(find.text('视频A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_1')));
    await tester.pumpAndSettle();
    expect(find.text('视频A'), findsNothing);
    expect(find.text('暂无下载记录'), findsOneWidget);
  });

  testWidgets('tap redownload_<id> enqueues same url/title/preset',
      (tester) async {
    final p720 = entry(
      id: 7,
      title: '视频X',
      status: 'failed',
      url: 'https://example.com/x',
      formatLabel: 'p720',
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(wrap([p720]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('redownload_7')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('redownload_7'))));
    final task = container.read(downloadQueueProvider).single;
    expect(task.url, 'https://example.com/x');
    expect(task.title, '视频X');
    expect(task.preset, QualityPreset.p720);
  });
}
