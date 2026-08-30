// test/ui/download_page_test.dart
import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/features/download/analysis_controller.dart';
import 'package:video_downloader/features/download/error_display.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/main.dart';

class FakeUiHistoryRepository implements HistoryRepository {
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
      [];

  @override
  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) =>
      const Stream.empty();

  @override
  Future<void> deleteById(int id) async {}

  @override
  Future<int> removeAll() async => 0;
}

class FakeUiService extends YtDlpService {
  FakeUiService({this.playlist = false, this.pendingDownload = false});
  final bool playlist;
  final bool pendingDownload;
  final Map<String, Completer<String>> pending = {};

  @override
  Future<AnalysisResult> probe(String url, {String? cookieFile}) async {
    if (playlist) {
      return PlaylistResult(const PlaylistMeta(title: 'PL', entries: [
        PlaylistEntry(id: 'a', title: 'A', url: 'u1', durationSec: 61),
        PlaylistEntry(id: 'b', title: 'B', url: 'u2', durationSec: 62),
        PlaylistEntry(id: 'c', title: 'C', url: 'u3', durationSec: 63),
      ]));
    }
    return VideoResult(VideoMeta(
        id: '1', title: '测试视频', uploader: 'UP主', durationSec: 61,
        webUrl: url));
  }

  @override
  Future<String> download(DownloadRequest request,
      {void Function(DownloadProgress)? onProgress}) async {
    if (pendingDownload) {
      final c = Completer<String>();
      pending[request.taskId!] = c;
      onProgress?.call(const DownloadProgress(
          fraction: 0.4, speed: '1MiB/s', etaSeconds: 30));
      return c.future;
    }
    onProgress?.call(const DownloadProgress(fraction: 1.0));
    return 'C:\\tmp\\测试视频.mp4';
  }

  @override
  Future<void> cancel(String taskId) async {
    // 必须覆盖：模拟真实 kill 后下载以非零码结束，
    // 否则挂起的 download future 永不完成，任务卡在 canceling
    pending.remove(taskId)?.completeError(
        const DownloadException(EngineErrorKind.unknown, '已取消'));
  }
}

// locale 必须由 settingsProvider 驱动 → pump 真实 App（读 settings.language）
Widget wrap(FakeUiService service) => ProviderScope(
      overrides: [
        ytDlpServiceProvider.overrideWithValue(service),
        sharedPrefsProvider.overrideWithValue(prefs),
        downloadsDirProvider.overrideWithValue(() async => 'C:\\tmp'),
        historyRepositoryProvider
            .overrideWith((ref) => FakeUiHistoryRepository()),
      ],
      child: const App(),
    );

/// 分析层固定为 unknown 裸异常：`e.toString()` 保留 raw，UI 不得裸显为
/// 主文案（core 须为友好文案，raw 仅作 detail 弱化行）
class _ErrorAnalysisController extends AnalysisController {
  @override
  AnalysisState build() => const AnalysisError('Some: raw stack text');
}

Widget wrapError() => ProviderScope(
      overrides: [
        ytDlpServiceProvider.overrideWithValue(FakeUiService()),
        sharedPrefsProvider.overrideWithValue(prefs),
        downloadsDirProvider.overrideWithValue(() async => 'C:\\tmp'),
        historyRepositoryProvider
            .overrideWith((ref) => FakeUiHistoryRepository()),
        analysisProvider.overrideWith(() => _ErrorAnalysisController()),
      ],
      child: const App(),
    );

late SharedPreferences prefs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 固定 zh，避免依赖宿主系统 locale（未设置时 SettingsController 回退系统语言）
    SharedPreferences.setMockInitialValues({'language': 'zh'});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    // 下载页改为整页滚动后，加高视口让所有元素可点击，避免测试受视口高度影响
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1400, 800)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('analyze then enqueue lands a completed task', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService()));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('测试视频'), findsWidgets);

    await tester.tap(find.byKey(const Key('enqueue_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('完成：C:\\tmp\\测试视频.mp4'), findsOneWidget);
    expect(find.byKey(const Key('open_t0')), findsOneWidget);
  });

  testWidgets('playlist url shows selection controls', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService(playlist: true)));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/pl');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('检测到播放列表「PL」'), findsOneWidget);
    for (final u in ['u1', 'u2', 'u3']) {
      expect(find.byKey(Key('check_$u')), findsOneWidget);
    }
    // 默认全选；条目行展示时长；条目列表有界可滚动（不 shrinkWrap）
    expect(find.text('已选 3/3 个条目'), findsOneWidget);
    expect(find.text('61 秒'), findsOneWidget);
    final entryList = tester.widget<ListView>(
        find.byKey(const Key('entry_list')));
    expect(entryList.shrinkWrap, isFalse);

    await tester.tap(find.byKey(const Key('check_u1')).first);
    await tester.pumpAndSettle();
    expect(find.text('已选 2/3 个条目'), findsOneWidget);
    await tester.tap(find.byKey(const Key('check_u2')).first);
    await tester.tap(find.byKey(const Key('check_u3')).first);
    await tester.pumpAndSettle();
    // 无选中 → 批量按钮禁用
    expect(find.text('已选 0/3 个条目'), findsOneWidget);
    final enqueue = tester.widget<FilledButton>(
        find.byKey(const Key('enqueue_button')));
    expect(enqueue.onPressed, isNull);
  });

  testWidgets('playlist batch enqueues selected entries', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService(playlist: true)));
    await tester.enterText(find.byKey(const Key('url_field')), 'u');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();

    // 默认全选 3 条，取消第 3 条后批量入队 → 仅 2 个任务（t0/t1，t2 未创建）
    await tester.tap(find.byKey(const Key('check_u3')).first);
    await tester.pumpAndSettle();
    expect(find.text('已选 2/3 个条目'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enqueue_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open_t0')), findsOneWidget);
    expect(find.byKey(const Key('open_t1')), findsOneWidget);
    expect(find.byKey(const Key('open_t2')), findsNothing);
    // 批量入队后与单视频流一致：复位分析 + 清空输入
    expect(find.byKey(const Key('check_u1')), findsNothing);
    expect(find.text('已选 2/3 个条目'), findsNothing);
  });

  testWidgets('cancel downloads task lands canceled', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService(pendingDownload: true)));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enqueue_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('40.0%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel_t0')));
    await tester.pumpAndSettle();
    expect(find.text('已取消'), findsOneWidget);
    expect(find.byKey(const Key('retry_t0')), findsOneWidget);
  });

  testWidgets('english locale switches chrome strings', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final enPrefs = await SharedPreferences.getInstance();
    // NavigationView 在 auto 模式下 <1008px 为 compact（仅图标），
    // 放大表面至 expanded 断点以上才能看到导航文字标签
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ytDlpServiceProvider.overrideWithValue(FakeUiService()),
        sharedPrefsProvider.overrideWithValue(enPrefs),
        downloadsDirProvider.overrideWithValue(() async => r'C:\tmp'),
        historyRepositoryProvider
            .overrideWith((ref) => FakeUiHistoryRepository()),
      ],
      child: const App(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsWidgets); // 导航项
    expect(find.text('下载'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    // 画质下拉必须本地化：引擎枚举自带的 zh label 不得漏到 en 界面
    expect(find.text('Best quality'), findsOneWidget);
    expect(find.text('最佳画质'), findsNothing);
  });

  testWidgets('unknown error shows friendly core, never raw', (tester) async {
    await tester.pumpWidget(wrapError());
    await tester.pumpAndSettle();
    // core 恒为本地化友好文案（zh 下 downloadFailed），绝不为空也不裸显 raw
    expect(find.text('下载失败'), findsOneWidget);
    // raw 仅作为独立的弱化副行存在，从不做为主文案
    final raw = tester.widget<Text>(find.text('Some: raw stack text'));
    expect(raw.maxLines, 2);
  });

  test('displayError unknown + empty detail returns non-empty generic core',
      () {
    final s = lookupS(const Locale('zh'));
    final e = displayErrorWith(s, EngineErrorKind.unknown, '');
    expect(e.core.trim(), isNotEmpty);
    expect(e.detail, isNull);
  });

  test('displayError unknown + raw detail keeps raw as secondary line', () {
    final s = lookupS(const Locale('zh'));
    final e = displayErrorWith(s, EngineErrorKind.unknown, 'Some: raw stack text');
    expect(e.core.trim(), isNotEmpty);
    expect(e.detail, 'Some: raw stack text');
  });

  test('displayError drops detail that equals core', () {
    final s = lookupS(const Locale('zh'));
    final e = displayErrorWith(
        s, EngineErrorKind.network, '网络错误：请检查网络连接后重试');
    expect(e.core, '网络错误：请检查网络连接后重试');
    expect(e.detail, isNull);
  });
}
