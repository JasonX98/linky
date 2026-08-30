// lib/features/settings/settings_page.dart
//
// 设置页 = 头部（保存设置）+ 180px 二级分区导航 + 分区内容。
// 分区：常规 / 下载设置 / 关于与更新，一次只显示一个（与原型一致）。
// 所有表单控件的 key 与文案保持不变（browse_button / cookie_file_button /
// clear_cookie_button / preset_combo? / language_combo / check_update_button），
// 仅把 Slider 换成步进器、ComboBox 语言选择换成青色分段控件。

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/preset_label.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/engine_update_action.dart';
import 'package:video_downloader/features/settings/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';
import 'package:video_downloader/theme/widgets.dart';

/// 设置分区。
enum SettingsSection { general, download, about }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    this.directoryPicker,
  });

  /// 测试注入的目录选择器；null 时使用 file_selector 的真实选择器
  final Future<String?> Function()? directoryPicker;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsSection _section = SettingsSection.general;
  bool _saved = false;

  Future<void> _browse() async {
    final pick = widget.directoryPicker ?? getDirectoryPath;
    final dir = await pick();
    if (dir == null || dir.isEmpty) return;
    ref.read(settingsProvider.notifier).setDownloadDir(dir);
  }

  /// 设置在改动时即刻持久化，保存按钮只做一次轻反馈。
  void _save() {
    setState(() => _saved = true);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        AppHeader(
          title: s.settingsTitle,
          subtitle: s.settingsSubtitle,
          action: PrimaryButton(
            label: _saved ? s.saved : s.saveSettings,
            icon: _saved ? FluentIcons.check_mark : FluentIcons.save,
            onPressed: _save,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSize.contentMax),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.pagePadding,
                  vertical: AppSize.pagePaddingV,
                ),
                children: [
                  if (_saved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SavedBanner(text: s.savedBanner),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: AppSize.settingsNav,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 12, bottom: 12),
                              child: Text(
                                s.preferencesGroup,
                                style: AppText.chip(
                                    color: AppColors.textDim,
                                    weight: FontWeight.w600),
                              ),
                            ),
                            _SectionTab(
                              key: const Key('section_general_tab'),
                              icon: FluentIcons.settings,
                              label: s.sectionGeneral,
                              selected: _section == SettingsSection.general,
                              onTap: () =>
                                  setState(() => _section = SettingsSection.general),
                            ),
                            _SectionTab(
                              key: const Key('section_download_tab'),
                              icon: FluentIcons.folder_open,
                              label: s.sectionDownload,
                              selected: _section == SettingsSection.download,
                              onTap: () => setState(
                                  () => _section = SettingsSection.download),
                            ),
                            _SectionTab(
                              key: const Key('section_about_tab'),
                              icon: FluentIcons.info,
                              label: s.sectionAbout,
                              selected: _section == SettingsSection.about,
                              onTap: () =>
                                  setState(() => _section = SettingsSection.about),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: AppSize.settingsBodyMax),
                          child: switch (_section) {
                            SettingsSection.general => _general(),
                            SettingsSection.download => _download(),
                            SettingsSection.about => _about(),
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ——— 常规 ———

  Widget _general() {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: s.sectionGeneral, subtitle: s.sectionGeneralDesc),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _SettingRow(
                title: s.settingsLanguage,
                subtitle: s.languageDesc,
                child: SegmentedPicker<String>(
                  key: const Key('language_picker'),
                  value: settings.language,
                  options: const [
                    (value: 'zh', label: '中文'),
                    (value: 'en', label: 'English'),
                  ],
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setLanguage(v),
                ),
              ),
              _SettingRow(
                title: s.notifyOnComplete,
                subtitle: s.notifyOnCompleteDesc,
                child: AppToggleSwitch(
                  value: settings.notifyOnComplete,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setNotifyOnComplete(v),
                ),
              ),
              _SettingRow(
                title: s.settingsDefaultQuality,
                subtitle: s.qualityDesc,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in QualityPreset.values)
                      QualityChip(
                        label: presetLabel(context, q),
                        selected: q == settings.defaultPreset,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setDefaultPreset(q),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ——— 下载设置 ———

  Widget _download() {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final dirSet = settings.downloadDir?.isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: s.sectionDownload, subtitle: s.sectionDownloadDesc),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingBlock(
                title: s.settingsDownloadDir,
                subtitle: s.downloadDirDesc,
                child: Row(
                  children: [
                    Expanded(child: _PathField(
                      icon: FluentIcons.folder,
                      text: dirSet
                          ? settings.downloadDir!
                          : s.systemDownloadsFolder,
                      dim: !dirSet,
                    )),
                    const SizedBox(width: 8),
                    GhostButton(
                      key: const Key('browse_button'),
                      label: s.chooseFolder,
                      onPressed: _browse,
                    ),
                  ],
                ),
              ),
              _SettingRow(
                title: s.settingsConcurrency,
                subtitle: s.concurrencyDesc,
                child: NumberStepper(
                  key: const Key('concurrency_stepper'),
                  minusKey: const Key('concurrency_decrement'),
                  plusKey: const Key('concurrency_increment'),
                  value: settings.concurrency,
                  min: SettingsController.minConcurrency,
                  max: SettingsController.maxConcurrency,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setConcurrency(v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ——— 关于与更新 ———

  Widget _about() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: s.sectionAbout, subtitle: s.sectionAboutDesc),
        const SizedBox(height: 24),
        AppCard(
          key: const Key('about_card'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // logo 自带圆角与透明边，不要再 ClipRRect 二次裁切
                  Image.asset('assets/logo.png',
                      width: 56, height: 56, fit: BoxFit.contain),
                  const SizedBox(width: 16),
                  // Expanded：窄栏时让文字列收缩，否则 Row 会 RenderFlex 溢出
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${AppMeta.name} · ${AppMeta.nameZh}',
                            style: AppText.section()),
                        const SizedBox(height: 4),
                        Text(s.aboutVersionLine(AppMeta.version),
                            style: AppText.meta()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Divider(
                style: DividerThemeData(
                  thickness: 1,
                  decoration: BoxDecoration(color: AppColors.borderSoft),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CheckUpdateButton(key: Key('check_update_button')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      ref.watch(engineUpdateStatusProvider),
                      style: AppText.meta(),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 组件版本：yt-dlp / ffmpeg 各自一行，缺失时显示本地化占位
              ref.watch(engineVersionsProvider).when(
                    data: (v) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VersionLine(
                          label: s.aboutYtDlp,
                          value: v.ytDlp ?? s.aboutVersionUnknown,
                        ),
                        const SizedBox(height: 6),
                        _VersionLine(
                          label: s.ffmpegVersion,
                          value: v.ffmpeg ?? s.aboutVersionUnknown,
                        ),
                      ],
                    ),
                    loading: () => Text('…', style: AppText.meta()),
                    error: (_, _) => _VersionLine(
                      label: s.aboutYtDlp,
                      value: s.aboutVersionUnknown,
                    ),
                  ),
              const SizedBox(height: 20),
              Divider(
                style: DividerThemeData(
                  thickness: 1,
                  decoration: BoxDecoration(color: AppColors.borderSoft),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.disclaimerText, style: AppText.meta()),
              const SizedBox(height: 6),
              Text(s.licensesNote, style: AppText.meta()),
            ],
          ),
        ),
      ],
    );
  }
}

// ——— 复用小部件 ———

/// 分组卡中的一行：左标题+描述，右控件，行间 5% 分隔线。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// 窄栏（< [AppSize.settingsRowBreakpoint]）时改为上下堆叠，避免右侧控件
  /// 与标题挤在同一行导致 RenderFlex 溢出。
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSoft)),
        ),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < AppSize.settingsRowBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labels(),
                const SizedBox(height: 12),
                child,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _labels()),
              const SizedBox(width: 24),
              child,
            ],
          );
        }),
      );

  Widget _labels() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppText.label(
                  color: AppColors.textPrimary, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppText.meta()),
        ],
      );
}

/// 控件独占一行的设置项（路径选择等），标题上方、控件下方。
class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSoft)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.label(
                        color: AppColors.textPrimary, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppText.meta()),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

/// 只读路径框（与输入框同款描边 + 图标）。
class _PathField extends StatelessWidget {
  const _PathField({required this.icon, required this.text, this.dim = false});

  final IconData icon;
  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppText.meta(
                    color: dim ? AppColors.textMuted : AppColors.textBody),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// 二级分区导航项：选中时左侧 2px 青色 + 深色底。
class _SectionTab extends StatefulWidget {
  const _SectionTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SectionTab> createState() => _SectionTabState();
}

class _SectionTabState extends State<_SectionTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.bgNavActive
                : (_hover ? const Color(0x0AFFFFFF) : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 15,
                  color: selected ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppText.label(
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                    weight: selected ? FontWeight.w600 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 保存成功提示条。
class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(FluentIcons.check_mark,
                size: 14, color: AppColors.success),
            const SizedBox(width: 8),
            Text(text, style: AppText.label(color: AppColors.successText)),
          ],
        ),
      );
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: AppText.meta()),
          Text(value, style: AppText.meta(color: AppColors.textBody)),
        ],
      );
}
