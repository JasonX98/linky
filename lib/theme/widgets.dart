// lib/theme/widgets.dart
//
// 原型风格的通用组件。约定：
// - 一律直接引用 AppColors / AppText 常量，不依赖主题或 InheritedWidget，
//   便于单测脱离 App 外壳单独挂载某个页面；
// - 需要被测试按类型查找的控件（FilledButton / Button）保持原类型，
//   但 key 只挂在外层封装上：若内外层共用同一个 key，find.byKey 会同时命中
//   两个 Element 而报 "ambiguously found multiple matching widgets"。

import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_downloader/theme/app_theme.dart';

/// 卡片容器：卡片底色 + 7% 描边 + 16 圆角。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.card,
    this.color = AppColors.bgCard,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(padding: padding, child: child),
      );
}

/// 页面头部（76px）：标题 + 副标题 + 右侧操作区。
/// 注：命名避开 fluent_ui 自带的 PageHeader（ScaffoldPage 的头部槽位）。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        height: AppSize.header,
      padding: const EdgeInsets.symmetric(horizontal: AppSize.pagePadding),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // 头部是固定 76px：标题/副标题必须单行截断，否则窄窗口下文字换行
          // 会把 Column 撑高并纵向溢出
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SubtitleLine(text: subtitle, top: 3),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
}

/// 分区标题：15/600 标题 + 可选的副标题、计数徽标、右侧操作。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible + 单行截断：窄栏时标题让位给右侧操作，避免横向溢出
                    Flexible(
                      child: Text(
                        title,
                        style: AppText.section(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count case final c?) ...[
                      const SizedBox(width: 8),
                      _CountBadge(text: c),
                    ],
                  ],
                ),
                SubtitleLine(text: subtitle, top: 5, meta: true),
              ],
            ),
          ),
          if (trailing case final t?) ...[
            const SizedBox(width: 16),
            t,
          ],
        ],
      );
}

/// 副标题行：text 为 null 时自动收缩为零高度，避免在列表里写 `if (x != null)`
/// 触发 use_null_aware_elements 告警。
class SubtitleLine extends StatelessWidget {
  const SubtitleLine({
    super.key,
    required this.text,
    this.top = 0,
    this.meta = false,
  });

  final String? text;
  final double top;

  /// true 时用更小的 11px 元信息字号（分区副标题）
  final bool meta;

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        t,
        style: meta ? AppText.meta() : AppText.label(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.bgTrack,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(text, style: AppText.chip(color: AppColors.textMuted)),
      );
}

/// 主按钮：青底深字。底层是 fluent [FilledButton]，key 由外层封装持有。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.width,
    this.height = 42,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width, height: height),
        child: FilledButton(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.accent.withValues(alpha: 0.35);
              }
              if (states.contains(WidgetState.hovered)) {
                return AppColors.accentHover;
              }
              if (states.contains(WidgetState.pressed)) {
                return AppColors.accent.withValues(alpha: 0.85);
              }
              return AppColors.accent;
            }),
            foregroundColor: const WidgetStatePropertyAll(AppColors.onAccent),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.primary(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

/// 次级按钮：描边 + 悬停浅底。底层是 fluent [Button]。
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 36,
    this.color = AppColors.textBody,
    this.hoverColor = AppColors.danger,
    this.hoverBorderColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final Color color;

  /// 悬停时的前景色（危险操作传 [AppColors.danger]）
  final Color hoverColor;

  /// 悬停时的描边色（默认跟随 [hoverColor] 的半透明）
  final Color? hoverBorderColor;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints.tightFor(height: height),
        child: Button(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            shape: WidgetStateProperty.resolveWith((states) {
              final border = states.contains(WidgetState.hovered)
                  ? (hoverBorderColor ?? hoverColor.withValues(alpha: 0.4))
                  : AppColors.border;
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(color: border),
              );
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.hovered)
                    ? const Color(0x0DFFFFFF)
                    : Colors.transparent),
            foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                    ? hoverColor
                    : color),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppText.label(color: color)),
            ],
          ),
        ),
      );
}

/// 方形图标块：低透明度主色底 + 主色图标（任务卡 48 / 历史行 36）。
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.accent,
    this.size = 48,
    this.iconSize = 22,
    this.radius = AppRadius.control,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, size: iconSize, color: color),
      );
}

/// 进度条：6px 圆角，底色 [AppColors.bgTrack]。
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.accent,
    this.height = AppSize.progress,
  });

  /// 0.0 ~ 1.0
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ProgressBar(
        value: value * 100,
        strokeWidth: height,
        backgroundColor: AppColors.bgTrack,
        activeColor: color,
      );
}

/// 开关：36×20 胶囊，开时青色。
class AppToggleSwitch extends StatelessWidget {
  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.bgTrack,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.bgBase,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

/// 步进器：− 值 +（并发数等小范围整数）。
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 5,
    this.minusKey,
    this.plusKey,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// 递减按钮的 key（供测试定位）
  final Key? minusKey;

  /// 递增按钮的 key（供测试定位）
  final Key? plusKey;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: minusKey,
            icon: FluentIcons.remove,
            enabled: value > min,
            onPressed: () => onChanged(value - 1),
          ),
          Container(
            width: 40,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text('$value', style: AppText.label(
                color: AppColors.textBody, weight: FontWeight.w600)),
          ),
          _StepButton(
            key: plusKey,
            icon: FluentIcons.add,
            enabled: value < max,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 12,
              color: enabled ? AppColors.textBody : AppColors.textDim),
          onPressed: enabled ? onPressed : null,
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      );
}

/// 空态：居中图标 + 弱化文案。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(message, style: AppText.label(color: AppColors.textMuted)),
          ],
        ),
      );
}

/// 状态圆点（6px）：完成绿 / 失败橙 / 进行中青。
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// 筛选标签：底部 2px 指示条（历史页 全部/已完成/失败）。
class FilterTab extends StatelessWidget {
  const FilterTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.label(
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text('$count', style: AppText.chip(color: AppColors.textDim)),
                ],
              ],
            ),
          ),
        ),
      );
}

/// 画质 chip：选中时青色描边 + 10% 底。
class QualityChip extends StatelessWidget {
  const QualityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppText.label(
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      );
}

/// 分段选择（语言切换等）：青色高亮当前项。
class SegmentedPicker<T> extends StatelessWidget {
  const SegmentedPicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => onChanged(o.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: o.value == value
                          ? AppColors.accent
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppRadius.control - 2),
                    ),
                    child: Text(
                      o.label,
                      style: AppText.label(
                        color: o.value == value
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                        weight: o.value == value ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Lucide 风格的「打开文件夹」图标（folder-open）。
///
/// 与原型 HTML 中 `icon="lucide:folder-open"` 视觉一致：
/// 圆角描边风格，前侧翻盖打开形态。
/// 用法替代此前的 [FluentIcons.folder_open]。
class FolderOpenIcon extends StatelessWidget {
  const FolderOpenIcon({
    super.key,
    this.size = 17,
    this.color = const Color(0xFF94A3B8),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FolderOpenPainter(color),
          size: Size(size, size),
        ),
      );
}

class _FolderOpenPainter extends CustomPainter {
  _FolderOpenPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // 后层（翻盖）
    final back = Path()
      ..moveTo(2, 10)
      ..lineTo(3.45, 5.64)
      ..cubicTo(3.79, 4.68, 4.54, 4.0, 5.35, 4.0)
      ..lineTo(10.0, 4.0)
      ..lineTo(12.0, 8.0)
      ..lineTo(19.15, 8.0)
      ..cubicTo(19.96, 8.0, 20.71, 8.68, 21.05, 9.57)
      ..lineTo(22.0, 13.0);
    canvas.drawPath(back, paint);

    // 前层（主体文件夹）
    final front = Path()
      ..moveTo(6.0, 14.0)
      ..lineTo(7.45, 9.64)
      ..cubicTo(7.79, 8.68, 8.54, 8.0, 9.35, 8.0)
      ..lineTo(18.5, 8.0)
      ..cubicTo(19.31, 8.0, 20.06, 8.69, 20.4, 9.57)
      ..lineTo(21.85, 14.0)
      ..cubicTo(22.23, 15.15, 21.47, 16.28, 20.35, 16.72)
      ..lineTo(18.95, 17.29)
      ..cubicTo(18.37, 17.52, 17.73, 17.61, 17.1, 17.55)
      ..lineTo(8.05, 16.55)
      ..cubicTo(7.08, 16.46, 6.25, 15.87, 5.85, 15.0)
      ..close();
    canvas.drawPath(front, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FolderOpenPainter old) => old.color != color;
}
