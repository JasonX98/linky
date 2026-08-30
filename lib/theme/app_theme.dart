// lib/theme/app_theme.dart
//
// 设计令牌：颜色 / 圆角 / 间距 / 字号，取值全部来自 UI 原型
// （Video-Downloader/{home,history,settings}.html）。
// 组件直接引用常量而不引入 InheritedWidget —— 单测可脱离 App 外壳
// 单独挂载某个页面（现有 test/ui 就是这么做的）。

import 'package:fluent_ui/fluent_ui.dart';

/// 颜色：与原型 hex 一一对应。
class AppColors {
  const AppColors._();

  // 背景层
  static const Color bgBase = Color(0xFF0B1120); // 主背景
  static const Color bgSurface = Color(0xFF0F172A); // 侧边栏 / 头部
  static const Color bgCard = Color(0xFF131C2E); // 卡片
  static const Color bgTrack = Color(0xFF1E2A40); // 进度条底 / 开关关闭态
  static const Color bgNavActive = Color(0xFF16233A); // 导航选中底

  // 描边
  static const Color border = Color(0x12FFFFFF); // white 7%，卡片/分隔线
  static const Color borderSoft = Color(0x0DFFFFFF); // white 5%，更弱的分隔线
  static const Color borderInput = Color(0xFF2A3A52); // 输入框描边

  // 主色
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentHover = Color(0xFF67E8F9);
  static const Color onAccent = Color(0xFF06222A); // 青底上的文字

  // 语义色
  static const Color success = Color(0xFF4ADE80);
  static const Color successText = Color(0xFF86EFAC);
  static const Color danger = Color(0xFFEF9B83);
  static const Color warning = Color(0xFFF09A70);

  // 文字层级
  static const Color textPrimary = Color(0xFFE6F1FF);
  static const Color textBody = Color(0xFFA9B8D0);
  static const Color textSecondary = Color(0xFF94A8C4);
  static const Color textMuted = Color(0xFF7C8CA8);
  static const Color textDim = Color(0xFF5A6B85);
}

/// 圆角：卡片 16 / 控件 12 / 小控件 8 / 图标块 10 / 徽标全圆。
class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double field = 12;
  static const double control = 8;
  static const double tile = 10;
  static const double pill = 999;
}

/// 间距与关键尺寸：侧边栏 232 / 头部 76 / 内容最大 1120 / 页面内边距 40。
class AppSize {
  const AppSize._();

  static const double sidebar = 232;
  static const double header = 76;
  static const double contentMax = 1120;
  static const double settingsNav = 180;
  static const double settingsBodyMax = 700;

  /// 设置项一行放不下"标题+控件"时的断点：低于此值改为上下堆叠
  static const double settingsRowBreakpoint = 420;

  /// 链接输入行放不下"输入框 + 130px 主按钮"时的断点：低于此值按钮换行到下方
  static const double urlRowBreakpoint = 420;
  static const double pagePadding = 40;
  static const double pagePaddingV = 36;
  static const double navItem = 44;
  static const double input = 50;
  static const double progress = 6;
}

/// 字号：标题 20 / 分区 15 / 正文 13 / 辅助 11~12 / 徽标 10。
class AppText {
  const AppText._();

  /// 页面标题（头部 20/600）
  static TextStyle title({Color color = AppColors.textPrimary}) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color);

  /// 分区标题（15/600）
  static TextStyle section({Color color = AppColors.textPrimary}) =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color);

  /// 卡片主文案（13/500）
  static TextStyle body({Color color = AppColors.textBody}) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color);

  /// 小标题 / 表单项（12）
  static TextStyle label(
          {Color color = AppColors.textSecondary, FontWeight? weight}) =>
      TextStyle(fontSize: 12, fontWeight: weight, color: color);

  /// 元信息（11）
  static TextStyle meta({Color color = AppColors.textMuted}) =>
      TextStyle(fontSize: 11, color: color);

  /// 徽标 / 角标（10）
  static TextStyle chip(
          {Color color = AppColors.textMuted, FontWeight? weight}) =>
      TextStyle(fontSize: 10, fontWeight: weight, color: color);

  /// 主色按钮文字（13/700）
  static TextStyle primary({Color color = AppColors.onAccent}) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color);
}

/// 应用元信息：侧边栏品牌区与"关于"分区共用。
class AppMeta {
  const AppMeta._();

  static const String name = 'Linky';
  static const String nameZh = '链可';
  static const String version = '1.0.0';
}

/// 青色强调色 swatch（fluent 的 accentColor 必须是 AccentColor）。
final AccentColor appAccent = AccentColor.swatch(const <String, Color>{
  'darkest': Color(0xFF0E7490),
  'darker': Color(0xFF0891B2),
  'dark': Color(0xFF06B6D4),
  'normal': AppColors.accent,
  'light': AppColors.accentHover,
  'lighter': Color(0xFFA5F3FC),
  'lightest': Color(0xFFCFFAFE),
});

/// 应用主题：深色 + 青色强调色。
FluentThemeData buildAppTheme() => FluentThemeData(
      brightness: Brightness.dark,
      accentColor: appAccent,
      scaffoldBackgroundColor: AppColors.bgBase,
      cardColor: AppColors.bgCard,
      menuColor: AppColors.bgSurface,
      micaBackgroundColor: AppColors.bgSurface,
      acrylicBackgroundColor: AppColors.bgSurface,
      activeColor: AppColors.accent,
      inactiveColor: AppColors.textMuted,
      inactiveBackgroundColor: AppColors.bgTrack,
      shadowColor: const Color(0x33000000),
    );
