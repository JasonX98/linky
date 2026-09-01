// lib/features/shell/window_close_gate.dart
//
// 拦截右上角原生关闭按钮（X）并决定应用的关闭行为：
//
// - 首次点击（行为仍为 CloseBehavior.ask）：弹出选择对话框，用户从
//   「直接退出」/「退出到托盘」中二选一；选择被持久化后立即执行对应动作。
// - 之后的点击：直接按持久化的行为执行（exit → destroy，tray → show/hide）。
//
// 同时承担系统托盘职责：托盘图标点击恢复主窗口，右键菜单提供
// 「打开主窗口」「退出」。
//
// 所有对 window_manager / tray_manager 的调用都经由 windowLifecycleProvider，
// 使其在 flutter test 里可用假实现替换。

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/features/shell/window_lifecycle.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 放在 [FluentApp] 的 home 上、包裹实际内容（AppShell）的常驻外壳。
///
/// 生命早期注册窗口/托盘监听并初始化拦截；不渲染任何可见内容，仅透传 [child]。
class WindowCloseGate extends ConsumerStatefulWidget {
  const WindowCloseGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowCloseGate> createState() => _WindowCloseGateState();
}

class _WindowCloseGateState extends ConsumerState<WindowCloseGate>
    with WindowListener, TrayListener {
  bool _trayReady = false;
  bool _promptOpen = false;

  /// 在 [initState]（dispose 前）捕获窗口/托盘控制实例。dispose 里不能再读
  /// provider（ref 已被释放），因此用 [late] 字段保存而非 getter。
  late final WindowLifecycle _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = ref.read(windowLifecycleProvider)
      ..addWindowListener(this)
      ..addTrayListener(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trayReady) return;
    _trayReady = true;
    unawaited(_prepareTray());
  }

  @override
  void dispose() {
    // 尽快解绑监听，避免平台通道在应用退出前反复回调。
    _lifecycle.removeWindowListener(this);
    _lifecycle.removeTrayListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      // 语言切换时刷新托盘菜单文案，避免残留上次语言。
      if (prev?.language != next.language) _refreshTrayMenu();
    });
    return widget.child;
  }

  // ——— 初始化 ———

  Future<void> _prepareTray() async {
    final s = S.of(context);
    try {
      await _lifecycle.init();
      await _lifecycle.setTrayToolTip(s.trayToolTip);
      await _lifecycle.setTrayMenu(_buildTrayMenu(s));
    } catch (_) {
      // 托盘/窗口初始化失败不影响主界面，降级为默认关闭（窗口直接退出）。
    }
  }

  /// 以当前语言刷新托盘悬停提示与右键菜单。
  void _refreshTrayMenu() {
    if (!mounted) return;
    final s = S.of(context);
    unawaited(() async {
      try {
        await _lifecycle.setTrayToolTip(s.trayToolTip);
        await _lifecycle.setTrayMenu(_buildTrayMenu(s));
      } catch (_) {}
    }());
  }

  Menu _buildTrayMenu(S s) => Menu(items: [
        MenuItem(
          key: 'show',
          label: s.trayMenuShow,
          onClick: (_) => unawaited(_showAndFocus()),
        ),
        MenuItem(
          key: 'quit',
          label: s.trayMenuQuit,
          onClick: (_) => unawaited(_destroy()),
        ),
      ]);

  // ——— 窗口关闭 ———

  @override
  void onWindowClose() {
    final behavior = ref.read(settingsProvider).closeBehavior;
    unawaited(switch (behavior) {
      CloseBehavior.exit => _destroy(),
      CloseBehavior.tray => _hideToTray(),
      CloseBehavior.ask => _promptChoice(),
    });
  }

  /// 未决策时弹出选择对话框：选择持久化后立即执行对应动作。
  Future<void> _promptChoice() async {
    if (_promptOpen || !mounted) return;
    _promptOpen = true;
    try {
      final s = S.of(context);
      final choice = await showDialog<CloseBehavior>(
        context: context,
        barrierDismissible: true,
        builder: (_) => CloseBehaviorDialog(
          title: s.closeDialogTitle,
          message: s.closeDialogMessage,
          exitLabel: s.closeExit,
          exitDesc: s.closeExitDesc,
          trayLabel: s.closeTray,
          trayDesc: s.closeTrayDesc,
        ),
      );
      if (choice == null) return; // 用户取消：停留在未决策状态
      ref.read(settingsProvider.notifier).setCloseBehavior(choice);
      switch (choice) {
        case CloseBehavior.exit:
          await _destroy();
        case CloseBehavior.tray:
          await _hideToTray();
        case CloseBehavior.ask:
          break; // 对话框只会返回 exit / tray
      }
    } finally {
      _promptOpen = false;
    }
  }

  Future<void> _hideToTray() async {
    try {
      await _lifecycle.hide();
    } catch (_) {}
  }

  Future<void> _destroy() async {
    try {
      await _lifecycle.destroy();
    } catch (_) {}
  }

  // ——— 恢复 / 托盘菜单 ———

  @override
  void onTrayIconMouseDown() {
    unawaited(_showAndFocus());
  }

  /// 右键托盘图标时弹出已设置的上下文菜单。
  @override
  void onTrayIconRightMouseDown() {
    unawaited(_popUpTrayMenu());
  }

  Future<void> _popUpTrayMenu() async {
    try {
      await _lifecycle.popUpContextMenu();
    } catch (_) {}
  }

  Future<void> _showAndFocus() async {
    try {
      await _lifecycle.show();
      await _lifecycle.focus();
    } catch (_) {}
  }
}

/// 首次关闭时的选择对话框：直接退出 / 退出到系统托盘。
///
/// 点击某项即 `Navigator.pop` 返回对应的 [CloseBehavior]；取消（点遮罩或 Esc）
/// 返回 null。仅渲染一种行为时也可用于设置页预览。
class CloseBehaviorDialog extends StatelessWidget {
  const CloseBehaviorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.exitLabel,
    required this.exitDesc,
    required this.trayLabel,
    required this.trayDesc,
  });

  final String title;
  final String message;
  final String exitLabel;
  final String exitDesc;
  final String trayLabel;
  final String trayDesc;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.section()),
              const SizedBox(height: 8),
              Text(message, style: AppText.body()),
              const SizedBox(height: 24),
              _ChoiceOption(
                key: const Key('close_exit_option'),
                icon: FluentIcons.power_button,
                label: exitLabel,
                desc: exitDesc,
                onTap: () => Navigator.pop(context, CloseBehavior.exit),
              ),
              const SizedBox(height: 10),
              _ChoiceOption(
                key: const Key('close_tray_option'),
                icon: FluentIcons.chrome_minimize,
                label: trayLabel,
                desc: trayDesc,
                onTap: () => Navigator.pop(context, CloseBehavior.tray),
              ),
            ],
          ),
        ),
      );
}

/// 对话框里的一个选项：左侧图标 + 标题/说明 + 右侧箭头，整行可点。
class _ChoiceOption extends StatefulWidget {
  const _ChoiceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  @override
  State<_ChoiceOption> createState() => _ChoiceOptionState();
}

class _ChoiceOptionState extends State<_ChoiceOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hover
                  ? const Color(0x0DFFFFFF)
                  : AppColors.bgBase,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(
                color: _hover
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                IconTile(icon: widget.icon, size: 34, iconSize: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: AppText.label(
                          color: AppColors.textPrimary,
                          weight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.desc,
                        style: AppText.meta(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  FluentIcons.chevron_right,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
}
