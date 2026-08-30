// test/ui/app_shell_test.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/main.dart';
import 'download_page_test.dart' show FakeUiService;
import 'history_page_test.dart' show FakeHistoryRepository;

late SharedPreferences lastPrefs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 固定 zh，避免依赖宿主系统 locale（未设置时 SettingsController 回退系统语言）
    SharedPreferences.setMockInitialValues({'language': 'zh'});
    lastPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('nav switches between pages', (tester) async {
    // NavigationView 在 auto 模式下 <1008px 为 compact（仅图标），
    // 测试默认 800x600 找不到文字标签，需放大表面至 expanded 断点以上
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // locale 必须由 settingsProvider 驱动 → pump 真实 App（读 settings.language）
    // HistoryPage watch historyRepositoryProvider，必须注入内存假仓库，
    // 否则会打开真实 drift 数据库
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ytDlpServiceProvider.overrideWithValue(FakeUiService()),
        sharedPrefsProvider.overrideWithValue(lastPrefs),
        historyRepositoryProvider.overrideWith((ref) => FakeHistoryRepository()),
      ],
      child: const App(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('url_field')), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无下载记录'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    // 设置窗格已是真实页面：显示设置表单而非占位文案
    expect(find.textContaining('设置将在下个版本提供'), findsNothing);
    expect(find.text('下载目录'), findsOneWidget);
  });
}
