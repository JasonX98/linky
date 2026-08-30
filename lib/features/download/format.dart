// lib/features/download/format.dart
//
// 展示层格式化：时长 / 时间。不引入 intl，纯手工补零。

import 'package:flutter/widgets.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

/// 秒 → `mm:ss`（超过 1 小时时为 `h:mm:ss`）。
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// 时间戳 → `今天 HH:mm` / `昨天 HH:mm` / `yyyy/MM/dd`。
String formatHistoryTime(BuildContext context, DateTime t) {
  final s = S.of(context);
  final now = DateTime.now();
  final hhmm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return s.todayAt(hhmm);
  if (diff == 1) return s.yesterdayAt(hhmm);
  return '${t.year}/${t.month.toString().padLeft(2, '0')}'
      '/${t.day.toString().padLeft(2, '0')}';
}
