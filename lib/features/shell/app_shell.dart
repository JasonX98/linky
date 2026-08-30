// lib/features/shell/app_shell.dart
//
// 外壳 = 常驻侧边栏 + 内容区。不使用 fluent 的 NavigationView：
// Windows 端窗口本身是 WS_OVERLAPPEDWINDOW（自带原生标题栏），
// NavigationView 的 TitleBar 会额外多出一条，与原型（头部在内容区）不符。
// 页面头部由各页自行渲染，便于每页定制右侧操作区。
// 当前页索引放在 provider 里，供"查看全部历史"这类跨页跳转写入。

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/features/download/download_page.dart';
import 'package:video_downloader/features/history/history_page.dart';
import 'package:video_downloader/features/settings/settings_page.dart';
import 'package:video_downloader/features/shell/sidebar.dart';
import 'package:video_downloader/theme/app_theme.dart';

/// 当前页索引：0 下载 / 1 历史 / 2 设置。
final appShellIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(appShellIndexProvider);
    return Container(
      color: AppColors.bgBase,
      child: Row(
        children: [
          Sidebar(
            selected: index,
            onChanged: (i) =>
                ref.read(appShellIndexProvider.notifier).state = i,
          ),
          Expanded(child: _page(index)),
        ],
      ),
    );
  }

  Widget _page(int index) => switch (index) {
        0 => const DownloadPage(),
        1 => const HistoryPage(),
        _ => const SettingsPage(),
      };
}
