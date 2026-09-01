// lib/features/shell/window_lifecycle.dart
//
// 窗口 / 系统托盘的抽象控制层。
//
// 生产环境由 [DesktopWindowLifecycle] 包装 window_manager + tray_manager 两个
// 原生插件；测试里通过 [windowLifecycleProvider] 覆写为内存假实现，从而在
// flutter test 中既不会打到 MissingPluginException，也能断言 hide/destroy/show
// 等调用。所有平台通道调用都集中在这里，UI（WindowCloseGate）不直接触碰插件。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口/托盘的抽象控制接口。
///
/// [WindowListener] / [TrayListener] 来自 window_manager / tray_manager 的
/// mixin；抽象成 add/remove 的形式，便于测试记录注册情况并手动触发事件。
abstract class WindowLifecycle {
  /// 初始化：确保窗口管理器就绪、拦截关闭事件、设置托盘图标。幂等且 best-effort。
  Future<void> init();

  void addWindowListener(WindowListener listener);
  void removeWindowListener(WindowListener listener);
  void addTrayListener(TrayListener listener);
  void removeTrayListener(TrayListener listener);

  /// 隐藏主窗口（进入系统托盘）。
  Future<void> hide();

  /// 显示并聚焦主窗口（从托盘恢复）。
  Future<void> show();

  Future<void> focus();

  /// 彻底退出应用。
  Future<void> destroy();

  /// 设置托盘悬停提示（保持在 [init] 之后调用）。
  Future<void> setTrayToolTip(String toolTip);

  /// 设置托盘右键菜单（保持在 [init] 之后调用）。
  Future<void> setTrayMenu(Menu menu);

  /// 弹出托盘右键菜单（在 [onTrayIconRightMouseDown] 时调用）。
  Future<void> popUpContextMenu();
}

/// 生产实现：包装 window_manager + tray_manager。
class DesktopWindowLifecycle implements WindowLifecycle {
  DesktopWindowLifecycle();

  /// 托盘图标资源路径（相对 flutter_assets，window_manager 插件会拼上 exe
  /// 同级的 data/flutter_assets）。图标为多尺寸 .ico（含 16px），Windows 托盘
  /// 用 LoadImage(IMAGE_ICON) 加载并缩放到小图标尺寸。
  static const String _trayIconAsset = 'assets/tray_icon.ico';

  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // 确保原生窗口可用（获取顶层窗口句柄），并拦截右上角关闭按钮：
    // 点击叉号后由 onWindowClose 回调决定 hide/destroy，而不是让窗口直接关闭。
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await trayManager.setIcon(_trayIconAsset);
  }

  @override
  void addWindowListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeWindowListener(WindowListener listener) =>
      windowManager.removeListener(listener);

  @override
  void addTrayListener(TrayListener listener) =>
      trayManager.addListener(listener);

  @override
  void removeTrayListener(TrayListener listener) =>
      trayManager.removeListener(listener);

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  Future<void> setTrayToolTip(String toolTip) =>
      trayManager.setToolTip(toolTip);

  @override
  Future<void> setTrayMenu(Menu menu) => trayManager.setContextMenu(menu);

  @override
  Future<void> popUpContextMenu() => trayManager.popUpContextMenu();
}

/// 全局窗口/托盘控制（生产为 [DesktopWindowLifecycle]；测试覆写为假实现）。
final windowLifecycleProvider = Provider<WindowLifecycle>(
  (ref) => DesktopWindowLifecycle(),
);
