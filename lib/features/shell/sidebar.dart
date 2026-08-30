// lib/features/shell/sidebar.dart
//
// 232px 常驻侧边栏：品牌区（76px）+ 导航项（44px，选中态左侧 3px 青色指示条）
// + 底部版本 chip。导航文案复用 S.navDownload / navHistory / navSettings，
// 保证中英文切换与既有测试的文本查找都成立。

import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_downloader/l10n/app_localizations.dart';
import 'package:video_downloader/theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = <({IconData icon, String label})>[
      (icon: FluentIcons.cloud_download, label: s.navDownload),
      (icon: FluentIcons.history, label: s.navHistory),
      (icon: FluentIcons.settings, label: s.navSettings),
    ];
    return Container(
      width: AppSize.sidebar,
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavItem(
                      icon: items[i].icon,
                      label: items[i].label,
                      selected: i == selected,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(FluentIcons.tag, size: 12, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s.versionLabel} · v${AppMeta.version}',
                      style: AppText.chip(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 品牌区：渐变图标块 + Linky / 链可。
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Container(
        height: AppSize.header,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
                ),
              ),
              child: const Icon(FluentIcons.download,
                  size: 18, color: AppColors.onAccent),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppMeta.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(AppMeta.nameZh, style: AppText.chip()),
              ],
            ),
          ],
        ),
      );
}

/// 导航项：选中时底色 #16233A + 左侧指示条，未选中悬停浅底。
class _NavItem extends StatefulWidget {
  const _NavItem({
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
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
            height: AppSize.navItem,
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.bgNavActive
                  : (_hover ? const Color(0x0AFFFFFF) : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                // 选中指示条：3×22，右侧圆角
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Icon(widget.icon,
                    size: 18,
                    color: widget.selected
                        ? AppColors.accent
                        : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppText.label(
                      color: widget.selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      weight: widget.selected ? FontWeight.w600 : null,
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
