// test/ui/window_close_gate_test.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/features/shell/window_close_gate.dart';
import 'package:video_downloader/features/shell/window_lifecycle.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

/// 内存假实现：记录窗口/托盘调用，并捕获注册的监听器供测试手动触发事件。
class FakeWindowLifecycle implements WindowLifecycle {
  bool initCalled = false;
  WindowListener? _windowListener;
  TrayListener? _trayListener;
  final List<String> calls = [];
  String? lastToolTip;
  Menu? lastMenu;

  WindowListener? get windowListener => _windowListener;
  TrayListener? get trayListener => _trayListener;

  @override
  Future<void> init() async {
    initCalled = true;
    calls.add('init');
  }

  @override
  void addWindowListener(WindowListener l) => _windowListener = l;

  @override
  void removeWindowListener(WindowListener l) {
    if (_windowListener == l) _windowListener = null;
  }

  @override
  void addTrayListener(TrayListener l) => _trayListener = l;

  @override
  void removeTrayListener(TrayListener l) {
    if (_trayListener == l) _trayListener = null;
  }

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> focus() async => calls.add('focus');

  @override
  Future<void> destroy() async => calls.add('destroy');

  @override
  Future<void> setTrayToolTip(String toolTip) async => lastToolTip = toolTip;

  @override
  Future<void> setTrayMenu(Menu menu) async => lastMenu = menu;

  @override
  Future<void> popUpContextMenu() async => calls.add('popUpContextMenu');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(FakeWindowLifecycle lc, SharedPreferences prefs) => ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          windowLifecycleProvider.overrideWithValue(lc),
        ],
        child: FluentApp(
          locale: const Locale('zh'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const WindowCloseGate(child: SizedBox.shrink()),
        ),
      );

  testWidgets('init registers window & tray listeners and sets tray menu',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    expect(lc.initCalled, isTrue);
    expect(lc.windowListener, isNotNull);
    expect(lc.trayListener, isNotNull);
    expect(lc.lastToolTip, isNotEmpty);
    expect(lc.lastMenu!.getMenuItem('show'), isNotNull);
    expect(lc.lastMenu!.getMenuItem('quit'), isNotNull);
  });

  testWidgets('ask (default) shows dialog; choosing exit persists and destroys',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.windowListener!.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close_exit_option')), findsOneWidget);
    expect(find.byKey(const Key('close_tray_option')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close_exit_option')));
    await tester.pumpAndSettle();
    expect(lc.calls, contains('destroy'));
    expect(prefs.getInt('closeBehavior'), CloseBehavior.exit.index);
  });

  testWidgets('ask shows dialog; choosing tray persists and hides',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.windowListener!.onWindowClose();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('close_tray_option')));
    await tester.pumpAndSettle();
    expect(lc.calls, contains('hide'));
    expect(prefs.getInt('closeBehavior'), CloseBehavior.tray.index);
  });

  testWidgets('already decided exit destroys without showing dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({'closeBehavior': CloseBehavior.exit.index});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.windowListener!.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close_exit_option')), findsNothing);
    expect(lc.calls, contains('destroy'));
  });

  testWidgets('already decided tray hides without showing dialog', (tester) async {
    SharedPreferences.setMockInitialValues({'closeBehavior': CloseBehavior.tray.index});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.windowListener!.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close_exit_option')), findsNothing);
    expect(lc.calls, contains('hide'));
  });

  testWidgets('tray icon click restores (show + focus) the window',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.trayListener!.onTrayIconMouseDown();
    await tester.pumpAndSettle();
    expect(lc.calls, contains('show'));
    expect(lc.calls, contains('focus'));
  });

  testWidgets('tray right-click pops up the context menu with show & quit',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.trayListener!.onTrayIconRightMouseDown();
    await tester.pumpAndSettle();
    expect(lc.calls, contains('popUpContextMenu'));
    // 菜单项：显示 + 退出
    expect(lc.lastMenu!.getMenuItem('show'), isNotNull);
    expect(lc.lastMenu!.getMenuItem('quit'), isNotNull);
  });

  testWidgets('dismissing the dialog leaves the behavior as ask', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lc = FakeWindowLifecycle();
    await tester.pumpWidget(host(lc, prefs));
    await tester.pumpAndSettle();

    lc.windowListener!.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close_exit_option')), findsOneWidget);

    // 关闭对话框（Esc/遮罩）→ 无动作，仍为 ask
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(lc.calls, isNot(contains('destroy')));
    expect(lc.calls, isNot(contains('hide')));
    expect(prefs.getInt('closeBehavior'), isNull);
    expect(lc.windowListener, isNotNull); // 仍可再次触发
  });
}
