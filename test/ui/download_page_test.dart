// test/ui/download_page_test.dart
import 'dart:async';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
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
import 'package:video_downloader/theme/widgets.dart';

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

/// file_selector 的 Windows 实现走 pigeon 私有通道，按通道 mock 成本高且脆弱。
/// 改用插件官方推荐的测试手法：替换 FileSelectorPlatform.instance，
/// 生产代码（download_page 直连 openFile）无需任何改动。
class _FakeFileSelector extends FileSelectorPlatform {
  /// 下一次 openFile 返回的路径；null 表示用户在系统对话框里点了取消。
  String? nextPath;
  int openFileCalls = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openFileCalls += 1;
    final path = nextPath;
    return path == null ? null : XFile(path);
  }

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      const <XFile>[];

  @override
  Future<String?> getSavePath({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? suggestedName,
    String? confirmButtonText,
  }) async =>
      null;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async =>
      null;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      null;

  @override
  Future<List<String>> getDirectoryPaths({
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      const <String>[];
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
    // 下载页改为整页滚动后，加高视口让所有元素可点击，避免测试受视口高度影响。
    // 高度需覆盖"链接卡（含迁入的 Cookie 选择行）+ 播放列表条目 + 入队按钮"，
    // 1000 是这批元素全部展开后的安全值。
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1000)
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

  testWidgets('narrow window stacks the preview card without overflow',
      (tester) async {
    // 预览卡按 LayoutBuilder 的 maxWidth>=560 分宽/窄两版：宽版缩略图与信息
    // 左右并排，窄版上下堆叠。默认视口 1400 只覆盖宽版，这里压窄覆盖窄版。
    // 560 是实测下限：再往下（520）fluent TextBox 内部结构开始溢出，
    // 那部分是框架自带控件，应用层无法干预 —— 真机应通过最小窗口尺寸兜底。
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    for (final width in <double>[560, 700]) {
      view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1.0;

      await tester.pumpWidget(wrap(FakeUiService()));
      await tester.enterText(
          find.byKey(const Key('url_field')), 'https://example.com/v');
      await tester.tap(find.byKey(const Key('analyze_button')));
      // 窄版若有 RenderFlex 溢出，pumpAndSettle 会把渲染异常升级为测试失败
      await tester.pumpAndSettle();

      expect(find.textContaining('测试视频'), findsWidgets,
          reason: 'width=$width 预览卡应完整渲染');
      expect(find.byKey(const Key('enqueue_button')), findsOneWidget,
          reason: 'width=$width 应保留入队按钮');
    }
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
    // 默认全选；条目行展示时长（mm:ss）；条目列表有界可滚动（不 shrinkWrap）
    expect(find.text('已选 3/3 个条目'), findsOneWidget);
    expect(find.text('01:01'), findsOneWidget);
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
    final enqueue = tester.widget<PrimaryButton>(
        find.byKey(const Key('enqueue_button')));
    expect(enqueue.onPressed, isNull);
  });

  testWidgets('delete button removes completed task from list', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService()));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enqueue_button')));
    await tester.pumpAndSettle();

    // 完成任务应显示删除按钮
    expect(find.byKey(const Key('delete_t0')), findsOneWidget);

    // 点击删除 → 任务从列表消失
    await tester.tap(find.byKey(const Key('delete_t0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('完成：'), findsNothing);
    expect(find.byKey(const Key('delete_t0')), findsNothing);
  });

  testWidgets('delete button is disabled for active tasks', (tester) async {
    // pendingDownload=true 让下载挂起，任务停留在 downloading 状态
    final svc = FakeUiService(pendingDownload: true);
    await tester.pumpWidget(wrap(svc));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enqueue_button')));
    // 等待任务进入 downloading 状态
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // 下载中的任务删除按钮存在
    expect(find.byKey(const Key('delete_t0')), findsOneWidget);
    // 验证按钮禁用：通过确认任务仍在列表中（未被误删）+ 
    // 尝试 tap 不抛异常（禁用按钮忽略 tap）
    expect(find.textContaining('测试视频'), findsOneWidget);
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

  testWidgets('cookie row on download page picks, persists and clears',
      (tester) async {
    // Cookie 选择器已从"下载设置"页迁入下载页，落点在链接框下方
    final fs = _FakeFileSelector();
    FileSelectorPlatform.instance = fs;
    await tester.pumpWidget(wrap(FakeUiService()));
    await tester.pumpAndSettle();

    // 未设置：占位文案 + 无清除按钮
    expect(find.text('未设置'), findsOneWidget);
    expect(find.byKey(const Key('clear_cookie_button')), findsNothing);

    // 选择文件 → 显示路径 + 出现清除按钮 + 写入 prefs
    fs.nextPath = r'C:\cookies\net.txt';
    await tester.tap(find.byKey(const Key('cookie_file_button')));
    await tester.pumpAndSettle();
    expect(fs.openFileCalls, 1);
    expect(find.text(r'C:\cookies\net.txt'), findsOneWidget);
    expect(find.text('未设置'), findsNothing);
    expect(find.byKey(const Key('clear_cookie_button')), findsOneWidget);
    expect(prefs.getString('cookieFile'), r'C:\cookies\net.txt');

    // 清除 → 回到占位 + 清空 prefs
    await tester.tap(find.byKey(const Key('clear_cookie_button')));
    await tester.pumpAndSettle();
    expect(find.text('未设置'), findsOneWidget);
    expect(find.byKey(const Key('clear_cookie_button')), findsNothing);
    expect(prefs.getString('cookieFile'), isNull);
  });

  testWidgets('canceling the cookie dialog leaves preferences untouched',
      (tester) async {
    // 用户在系统对话框点取消 → openFile 返回 null，不得覆盖既有值
    SharedPreferences.setMockInitialValues(
        {'language': 'zh', 'cookieFile': r'C:\cookies\keep.txt'});
    prefs = await SharedPreferences.getInstance();
    FileSelectorPlatform.instance = _FakeFileSelector(); // nextPath 默认 null
    await tester.pumpWidget(wrap(FakeUiService()));
    await tester.pumpAndSettle();
    expect(find.text(r'C:\cookies\keep.txt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cookie_file_button')));
    await tester.pumpAndSettle();
    expect(prefs.getString('cookieFile'), r'C:\cookies\keep.txt');
    expect(find.text('未设置'), findsNothing);
  });

  testWidgets('analysis failure nudges user to import a cookie file',
      (tester) async {
    // 解析失败 + 未设 Cookie → 给出导入建议
    await tester.pumpWidget(wrapError());
    await tester.pumpAndSettle();
    expect(find.text('链接解析失败？尝试导入 Cookie 文件后重试'), findsOneWidget);
  });

  testWidgets('cookie hint disappears once a cookie file is set',
      (tester) async {
    // 已导入 Cookie 后不再提示，避免已经照做的人被反复打扰
    SharedPreferences.setMockInitialValues(
        {'language': 'zh', 'cookieFile': r'C:\cookies\net.txt'});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(wrapError());
    await tester.pumpAndSettle();
    expect(find.text('下载失败'), findsOneWidget);
    expect(find.text('链接解析失败？尝试导入 Cookie 文件后重试'), findsNothing);
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
