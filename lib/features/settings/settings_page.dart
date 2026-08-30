// lib/features/settings/settings_page.dart
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/preset_label.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    this.directoryPicker,
    this.cookieFilePicker,
  });

  /// 测试注入的目录选择器；null 时使用 file_selector 的真实选择器
  final Future<String?> Function()? directoryPicker;

  /// 测试注入的 cookie 文件选择器；null 时使用 file_selector 的真实 openFile
  final Future<String?> Function()? cookieFilePicker;

  Future<void> _browse(BuildContext context, WidgetRef ref) async {
    final pick = directoryPicker ?? getDirectoryPath;
    final dir = await pick();
    if (dir == null || dir.isEmpty) return;
    ref.read(settingsProvider.notifier).setDownloadDir(dir);
  }

  Future<void> _pickCookieFile(BuildContext context, WidgetRef ref) async {
    final String? path;
    final pick = cookieFilePicker;
    if (pick != null) {
      path = await pick();
    } else {
      const group = XTypeGroup(
        label: 'Netscape cookie',
        extensions: ['txt', 'cookie', 'cookies'],
      );
      final file = await openFile(acceptedTypeGroups: const [group]);
      path = file?.path;
    }
    if (path == null || path.isEmpty) return;
    ref.read(settingsProvider.notifier).setCookieFile(path);
  }

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    ref.read(engineUpdateCheckingProvider.notifier).state = true;
    ref.read(engineUpdateStatusProvider.notifier).state = s.updateChecking;
    try {
      final result =
          await ref.read(settingsProvider.notifier).checkEngineUpdates(force: true);
      final parts = <String>[
        ..._componentFrags('yt-dlp', result.ytDlp, result.ytDlpVersion,
            result.ytDlpError, s),
        ..._componentFrags('ffmpeg', result.ffmpeg, result.ffmpegVersion,
            result.ffmpegError, s),
      ];
      ref.read(engineUpdateStatusProvider.notifier).state =
          parts.isEmpty ? s.updateUpToDate : parts.join('\n');
    } finally {
      ref.read(engineUpdateCheckingProvider.notifier).state = false;
    }
  }

  /// 把单个组件的更新结果转成 0~1 条文案（upToDate 返回空 → 仅当全部组件都最新时显示"已是最新"）。
  List<String> _componentFrags(
      String component,
      ComponentUpdateOutcome outcome,
      String? version,
      String? error,
      S s) {
    switch (outcome) {
      case ComponentUpdateOutcome.upToDate:
        return const [];
      case ComponentUpdateOutcome.updated:
        return [s.updateUpdated(component, version ?? '')];
      case ComponentUpdateOutcome.busy:
        return [s.updateBusy(component)];
      case ComponentUpdateOutcome.failed:
        return [s.updateFailed(component, error ?? '')];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    return ScaffoldPage(
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(s.settingsDownloadDir),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(
                  (settings.downloadDir?.isNotEmpty == true)
                      ? settings.downloadDir!
                      : s.systemDownloadsFolder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Button(
                key: const Key('browse_button'),
                onPressed: () => _browse(context, ref),
                child: Text(s.browse),
              ),
            ]),
            const SizedBox(height: 12),
            Text(s.settingsCookieFile),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(
                  (settings.cookieFile?.isNotEmpty == true)
                      ? settings.cookieFile!
                      : s.cookieFileNotSet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Button(
                key: const Key('cookie_file_button'),
                onPressed: () => _pickCookieFile(context, ref),
                child: Text(s.openFile),
              ),
              if (settings.cookieFile?.isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Button(
                  key: const Key('clear_cookie_button'),
                  onPressed: () => ref.read(settingsProvider.notifier).setCookieFile(null),
                  child: Text(s.clearCookieFile),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            Text(s.settingsConcurrency),
            Row(children: [
              Expanded(
                child: Slider(
                  key: const Key('concurrency_slider'),
                  min: SettingsController.minConcurrency.toDouble(),
                  max: SettingsController.maxConcurrency.toDouble(),
                  divisions: SettingsController.maxConcurrency -
                      SettingsController.minConcurrency,
                  value: settings.concurrency.toDouble(),
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setConcurrency(v.round()),
                ),
              ),
              const SizedBox(width: 8),
              Text('${settings.concurrency}'),
            ]),
            const SizedBox(height: 12),
            Text(s.settingsDefaultQuality),
            const SizedBox(height: 4),
            ComboBox<QualityPreset>(
              key: const Key('preset_combo'),
              value: settings.defaultPreset,
              items: [
                for (final p in QualityPreset.values)
                  ComboBoxItem(value: p, child: Text(presetLabel(context, p))),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setDefaultPreset(v);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(s.settingsLanguage),
            const SizedBox(height: 4),
            // 语言选项用各自母语名显示（语言选择器惯例，不随界面语言本地化）
            ComboBox<String>(
              key: const Key('language_combo'),
              value: settings.language,
              items: const [
                ComboBoxItem(value: 'zh', child: Text('中文')),
                ComboBoxItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setLanguage(v);
                }
              },
            ),
            const SizedBox(height: 24),
            Card(
              key: const Key('about_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.aboutTitle,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ref.watch(engineVersionsProvider).when(
                      data: (v) => Text(
                          '${s.aboutYtDlp}: ${v.ytDlp ?? s.aboutVersionUnknown}'),
                      loading: () => const Text('…'),
                      error: (_, _) =>
                          Text('${s.aboutYtDlp}: ${s.aboutVersionUnknown}'),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(children: [
                      Button(
                        key: const Key('check_update_button'),
                        onPressed: ref.watch(engineUpdateCheckingProvider)
                            ? null
                            : () => _checkUpdate(context, ref),
                        child: Text(s.settingsCheckUpdate),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ref.watch(engineUpdateStatusProvider),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(s.disclaimerText),
                    const SizedBox(height: 4),
                    Text(s.licensesNote),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
