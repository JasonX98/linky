// test/ui/settings_page_test.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/providers.dart';
import 'package:video_downloader/features/settings/settings_page.dart';
import 'package:video_downloader/engine/engine_update.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/queue_controller.dart';
import 'package:video_downloader/features/download/download_task.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 仅用于测试：覆写 hasActive，不依赖真实队列状态。
class _FakeQueue extends DownloadQueueController {
  _FakeQueue(this._active);
  final bool _active;
  @override
  bool get hasActive => _active;
  @override
  List<DownloadTask> build() => const [];
}

/// 仅用于测试：完全覆写四个检查/应用方法，避免真实 locator/launcher/zip 文件 I/O。
/// 通过 `ytUpdate`/`ffUpdate` 控制是否报告更新，`ytApplyError`/`ffApplyError` 触发失败。
class _PageService extends EngineUpdateService {
  _PageService({this.ytUpdate, this.ffUpdate, this.ytApplyError});

  final String? ytUpdate;
  final String? ffUpdate;
  final DownloadException? ytApplyError;

  @override
  Future<EngineVersion?> checkForUpdate() async =>
      ytUpdate == null ? null : EngineVersion.tryParse(ytUpdate!);
  @override
  Future<void> applyUpdate(EngineVersion v) async {
    if (ytApplyError != null) throw ytApplyError!;
  }

  @override
  Future<EngineVersion?> checkFfmpegUpdate() async =>
      ffUpdate == null ? null : EngineVersion.tryParse(ffUpdate!);
  @override
  Future<void> applyFfmpegUpdate(EngineVersion v) async {}
}

late SharedPreferences prefs;
Future<String?> Function()? picker;

// locale 必须由 settingsProvider 驱动（与 App 相同的接线），
// SettingsPage 作为 home 直接挂载，避免拖入下载/历史页的依赖
class _LocaleHost extends ConsumerWidget {
  const _LocaleHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    return FluentApp(
      locale: Locale(lang),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: SettingsPage(
        directoryPicker: picker,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 固定 zh，避免依赖宿主系统 locale
    SharedPreferences.setMockInitialValues({'language': 'zh'});
    prefs = await SharedPreferences.getInstance();
    picker = null;
  });

  Widget host() => ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          engineVersionsProvider.overrideWith(
              (ref) async => (ytDlp: '2026.08.19', ffmpeg: '7.0.0')),
        ],
        child: const _LocaleHost(),
      );

  Widget hostWith({
    required EngineUpdateService engineService,
    bool queueActive = false,
  }) =>
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          engineVersionsProvider.overrideWith(
              (ref) async => (ytDlp: '2026.08.19', ffmpeg: '7.0.0')),
          engineServiceProvider.overrideWithValue(engineService),
          downloadQueueProvider.overrideWith(() => _FakeQueue(queueActive)),
        ],
        child: const _LocaleHost(),
      );

  /// 切换到指定分区（原型式：一次只显示一个分区）。
  Future<void> openSection(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('sections switch one at a time', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    // 默认落在"常规"
    expect(find.text('语言'), findsOneWidget);
    expect(find.byKey(const Key('browse_button')), findsNothing);
    expect(find.byKey(const Key('check_update_button')), findsNothing);

    // 常规 → 下载设置：只剩下载相关项
    await openSection(tester, 'section_download_tab');
    expect(find.byKey(const Key('browse_button')), findsOneWidget);
    expect(find.byKey(const Key('check_update_button')), findsNothing);
    expect(find.text('语言'), findsNothing);

    // 下载设置 → 关于与更新
    await openSection(tester, 'section_about_tab');
    expect(find.byKey(const Key('check_update_button')), findsOneWidget);
    expect(find.byKey(const Key('browse_button')), findsNothing);
  });

  testWidgets('narrow window keeps every section within bounds', (tester) async {
    // 设置页测试直接挂 SettingsPage（无侧边栏），这里模拟真实窗口扣掉 232px
    // 侧边栏后的可用宽度（约 600 → 相当于 830px 窗口）。
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(600, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 三个分区逐一走查：路径行（路径框 + 按钮是 Row）、步进器、关于卡片
    // 任一处 RenderFlex 溢出都会被 pumpAndSettle 升级为测试失败
    await openSection(tester, 'section_general_tab');
    await openSection(tester, 'section_download_tab');
    expect(find.byKey(const Key('browse_button')), findsOneWidget);
    expect(find.byKey(const Key('concurrency_stepper')), findsOneWidget);
    await openSection(tester, 'section_about_tab');
    expect(find.byKey(const Key('check_update_button')), findsOneWidget);
  });

  testWidgets('browse picks directory, updates text and persists', (tester) async {
    picker = () async => r'D:\X';
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await openSection(tester, 'section_download_tab');
    // 未设置目录时显示系统下载文件夹占位
    expect(find.text('系统下载文件夹'), findsOneWidget);

    await tester.tap(find.byKey(const Key('browse_button')));
    await tester.pumpAndSettle();
    expect(find.text(r'D:\X'), findsOneWidget);
    expect(find.text('系统下载文件夹'), findsNothing);
    // pumpAndSettle 已排空 mock prefs 的写入微任务
    expect(prefs.getString('downloadDir'), r'D:\X');
  });

  testWidgets('stepper +/- updates concurrency and persists', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await openSection(tester, 'section_download_tab');
    // 默认并发 3
    expect(find.descendant(
      of: find.byKey(const Key('concurrency_stepper')),
      matching: find.text('3'),
    ), findsOneWidget);

    // 加到上限 5，再点一次应保持 5
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('concurrency_increment')));
      await tester.pumpAndSettle();
    }
    expect(find.descendant(
      of: find.byKey(const Key('concurrency_stepper')),
      matching: find.text('5'),
    ), findsOneWidget);
    expect(prefs.getInt('concurrency'), 5);

    // 减回 2
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('concurrency_decrement')));
      await tester.pumpAndSettle();
    }
    expect(find.descendant(
      of: find.byKey(const Key('concurrency_stepper')),
      matching: find.text('2'),
    ), findsOneWidget);
    expect(prefs.getInt('concurrency'), 2);
  });

  testWidgets('language picker switches UI to english instantly',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await openSection(tester, 'section_download_tab');
    expect(find.text('下载目录'), findsOneWidget);

    // 语言选择在"常规"分区
    await openSection(tester, 'section_general_tab');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // 本页文案即时变英文，无需重启（分区导航 + 分区标题）
    expect(
      find.descendant(
        of: find.byKey(const Key('section_general_tab')),
        matching: find.text('General'),
      ),
      findsOneWidget,
    );
    expect(find.text('下载目录'), findsNothing);
    await openSection(tester, 'section_download_tab');
    expect(find.text('Download directory'), findsOneWidget);
    expect(find.text('Concurrent downloads'), findsOneWidget);
  });

  testWidgets('about section shows yt-dlp and ffmpeg versions and disclaimer',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await openSection(tester, 'section_about_tab');
    expect(find.byKey(const Key('about_card')), findsOneWidget);
    // 版本行：标签与数值是两个 Text
    expect(find.text('yt-dlp 版本: '), findsOneWidget);
    expect(find.text('2026.08.19'), findsOneWidget);
    expect(find.text('FFmpeg 版本: '), findsOneWidget);
    expect(find.text('7.0.0'), findsOneWidget);
    expect(find.textContaining('仅供个人学习'), findsWidgets);
  });

  testWidgets('check update shows up-to-date status', (tester) async {
    final service = _PageService();
    await tester.pumpWidget(hostWith(engineService: service));
    await tester.pumpAndSettle();
    await openSection(tester, 'section_about_tab');

    await tester.tap(find.byKey(const Key('check_update_button')));
    await tester.pumpAndSettle();

    expect(find.text('已是最新版本'), findsOneWidget);
  });

  testWidgets('check update shows updated status per component', (tester) async {
    final service = _PageService(ytUpdate: '2026.09.01');
    await tester.pumpWidget(hostWith(engineService: service));
    await tester.pumpAndSettle();
    await openSection(tester, 'section_about_tab');

    await tester.tap(find.byKey(const Key('check_update_button')));
    // 注：检查过程很快，进行中态（“检查中…”+按钮禁用）不易稳定捕获，
    // 此处验证最终态：状态文案与按钮恢复可点击。
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('yt-dlp 已更新到 2026.09.01'), findsOneWidget);
    // 按钮恢复可点击（checking 已回到 false）
    final ghost = tester.widget<GhostButton>(find.descendant(
      of: find.byKey(const Key('check_update_button')),
      matching: find.byType(GhostButton),
    ));
    expect(ghost.onPressed, isNotNull);
  });

  testWidgets('check update shows busy per component when download active',
      (tester) async {
    final service = _PageService(ytUpdate: '2026.09.01', ffUpdate: '9.0.1');
    await tester.pumpWidget(hostWith(engineService: service, queueActive: true));
    await tester.pumpAndSettle();
    await openSection(tester, 'section_about_tab');

    await tester.tap(find.byKey(const Key('check_update_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('yt-dlp：请先停止下载任务后再更新'), findsOneWidget);
    expect(find.textContaining('ffmpeg：请先停止下载任务后再更新'), findsOneWidget);
  });

  testWidgets('check update shows failure detail on error', (tester) async {
    final service = _PageService(
      ytUpdate: '2026.09.01',
      ytApplyError: const DownloadException(EngineErrorKind.network, 'HTTP 500'),
    );
    await tester.pumpWidget(hostWith(engineService: service));
    await tester.pumpAndSettle();
    await openSection(tester, 'section_about_tab');

    await tester.tap(find.byKey(const Key('check_update_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('更新失败'), findsOneWidget);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
  });

  testWidgets('check update timeout i18n keys exist and are non-empty',
      (tester) async {
    // 用一个最小 localized widget 树加载 S，验证超时文案键可用
    await tester.pumpWidget(FluentApp(
      locale: const Locale('zh'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: const SizedBox.shrink(),
    ));
    await tester.pumpAndSettle();
    final s = S.of(tester.element(find.byType(SizedBox)));
    expect(s.updateTimeout, isNotEmpty);
    expect(s.updateTimeout, contains('超时'));

    // 切英文验证
    await tester.pumpWidget(FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: const SizedBox.shrink(),
    ));
    await tester.pumpAndSettle();
    final sEn = S.of(tester.element(find.byType(SizedBox)));
    expect(sEn.updateTimeout, isNotEmpty);
    expect(sEn.updateTimeout, contains('timed out'));
  });

  testWidgets('cookie selector no longer lives in settings', (tester) async {
    // Cookie 文件选择已迁至下载页（链接框下方），设置页不得再出现
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await openSection(tester, 'section_download_tab');
    expect(find.byKey(const Key('cookie_file_button')), findsNothing);
    expect(find.byKey(const Key('clear_cookie_button')), findsNothing);
  });

  testWidgets('proxy config toggles and persists', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    // 常规卡片默认代理关闭
    expect(prefs.getBool('proxyEnabled'), isNull);

    // 代理开关是第二个 AppToggleSwitch（第一个是"完成后通知"）
    final toggles = find.byType(AppToggleSwitch);
    expect(toggles, findsNWidgets(2));
    final proxyToggle = toggles.at(1);

    // 开启
    await tester.tap(proxyToggle);
    await tester.pumpAndSettle();
    expect(prefs.getBool('proxyEnabled'), isTrue);

    // 关闭
    await tester.tap(proxyToggle);
    await tester.pumpAndSettle();
    expect(prefs.getBool('proxyEnabled'), isFalse);
  });
}
