// lib/features/download/preset_label.dart
import 'package:flutter/widgets.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/l10n/app_localizations.dart';

/// 画质档位 → 本地化标签；models.dart 的 zh label 仅为引擎内部/兜底
String presetLabel(BuildContext context, QualityPreset p) {
  final s = S.of(context);
  switch (p) {
    case QualityPreset.best:
      return s.qualityBest;
    case QualityPreset.p1080:
      return s.quality1080p;
    case QualityPreset.p720:
      return s.quality720p;
    case QualityPreset.p480:
      return s.quality480p;
  }
}
