// lib/features/shell/app_shell.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_downloader/features/download/download_page.dart';
import 'package:video_downloader/features/history/history_page.dart';
import 'package:video_downloader/features/settings/settings_page.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return NavigationView(
      titleBar: const TitleBar(title: Text('Video Downloader')),
      pane: NavigationPane(
        selected: _index,
        onChanged: (i) => setState(() => _index = i),
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.download),
            title: Text(s.navDownload),
            body: const DownloadPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.history),
            title: Text(s.navHistory),
            body: const HistoryPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: Text(s.navSettings),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}
