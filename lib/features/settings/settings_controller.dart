// lib/features/settings/settings_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/providers.dart';

/// 单个组件（yt-dlp / ffmpeg）的更新结果。
enum ComponentUpdateOutcome { upToDate, updated, busy, failed }

/// "检查更新"的结果：按组件分别给出结果，UI 据此分组件选本地化文案。
class EngineUpdateResult {
  const EngineUpdateResult({
    required this.ytDlp,
    required this.ffmpeg,
    this.ytDlpVersion,
    this.ffmpegVersion,
    this.ytDlpError,
    this.ffmpegError,
  });

  final ComponentUpdateOutcome ytDlp;
  final ComponentUpdateOutcome ffmpeg;

  /// `updated` 时的版本号（用于 `已更新到 {version}`）。
  final String? ytDlpVersion;
  final String? ffmpegVersion;

  /// `failed` 时的友好错误详情（来自 `DownloadException.detail`）。
  final String? ytDlpError;
  final String? ffmpegError;
}

class SettingsState {
  const SettingsState({
    this.downloadDir,
    this.cookieFile,
    this.concurrency = 3,
    this.defaultPreset = QualityPreset.best,
    required this.language,
    this.notifyOnComplete = true,
  });

  final String? downloadDir;

  /// 全局 Cookie 文件路径（Netscape 格式，供 yt-dlp --cookies 使用）；null 表示未设置。
  final String? cookieFile;
  final int concurrency;
  final QualityPreset defaultPreset;
  final String language;

  /// 下载完成后是否提示。当前仅作为偏好持久化（尚未接入系统通知），
  /// 控件与存储先落地，避免后续接通知时再改状态结构。
  final bool notifyOnComplete;

  SettingsState copyWith({
    String? downloadDir,
    bool clearDownloadDir = false,
    String? cookieFile,
    bool clearCookieFile = false,
    int? concurrency,
    QualityPreset? defaultPreset,
    String? language,
    bool? notifyOnComplete,
  }) =>
      SettingsState(
        downloadDir:
            clearDownloadDir ? null : (downloadDir ?? this.downloadDir),
        cookieFile: clearCookieFile ? null : (cookieFile ?? this.cookieFile),
        concurrency: concurrency ?? this.concurrency,
        defaultPreset: defaultPreset ?? this.defaultPreset,
        language: language ?? this.language,
        notifyOnComplete: notifyOnComplete ?? this.notifyOnComplete,
      );
}

class SettingsController extends Notifier<SettingsState> {
  static const int minConcurrency = 1;
  static const int maxConcurrency = 5;

  /// 节流间隔：距离上次后台检查 <24h 则跳过（force 可绕过）。
  static const Duration engineCheckInterval = Duration(hours: 24);

  /// 上次引擎后台检查的时间戳（epoch 毫秒）。
  static const String lastEngineCheckKey = 'lastEngineCheck';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final storedConcurrency = prefs.getInt('concurrency');
    final storedPreset = prefs.getInt('defaultPreset');
    return SettingsState(
      downloadDir: prefs.getString('downloadDir'),
      cookieFile: prefs.getString('cookieFile'),
      concurrency: storedConcurrency != null &&
              storedConcurrency >= minConcurrency &&
              storedConcurrency <= maxConcurrency
          ? storedConcurrency
          : 3,
      defaultPreset: storedPreset != null &&
              storedPreset >= 0 &&
              storedPreset < QualityPreset.values.length
          ? QualityPreset.values[storedPreset]
          : QualityPreset.best,
      language: prefs.getString('language') ?? _systemLang(),
      notifyOnComplete: prefs.getBool('notifyOnComplete') ?? true,
    );
  }

  void setDownloadDir(String? dir) {
    state = state.copyWith(downloadDir: dir, clearDownloadDir: dir == null);
    final prefs = ref.read(sharedPrefsProvider);
    if (dir == null) {
      unawaited(prefs.remove('downloadDir'));
    } else {
      unawaited(prefs.setString('downloadDir', dir));
    }
  }

  void setCookieFile(String? path) {
    state = state.copyWith(cookieFile: path, clearCookieFile: path == null);
    final prefs = ref.read(sharedPrefsProvider);
    if (path == null) {
      unawaited(prefs.remove('cookieFile'));
    } else {
      unawaited(prefs.setString('cookieFile', path));
    }
  }

  void setConcurrency(int value) {
    final clamped = value.clamp(minConcurrency, maxConcurrency);
    state = state.copyWith(concurrency: clamped);
    unawaited(
        ref.read(sharedPrefsProvider).setInt('concurrency', clamped));
  }

  void setDefaultPreset(QualityPreset preset) {
    state = state.copyWith(defaultPreset: preset);
    unawaited(
        ref.read(sharedPrefsProvider).setInt('defaultPreset', preset.index));
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
    unawaited(ref.read(sharedPrefsProvider).setString('language', language));
  }

  void setNotifyOnComplete(bool value) {
    state = state.copyWith(notifyOnComplete: value);
    unawaited(
        ref.read(sharedPrefsProvider).setBool('notifyOnComplete', value));
  }

  static String _systemLang() =>
      Platform.localeName.toLowerCase().startsWith('zh') ? 'zh' : 'en';

  /// 是否处于 24h 节流窗口内（非 force 时跳过检查）。
  bool _withinThrottle() {
    final prefs = ref.read(sharedPrefsProvider);
    final last = prefs.getInt(lastEngineCheckKey);
    if (last == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed < engineCheckInterval.inMilliseconds;
  }

  /// 单一节流门：非 force 且距上次检查 <24h 时，返回"已是最新"且不发起网络/更新。
  /// 否则依次检查并应用 yt-dlp 与 ffmpeg（各自独立判新/应用），仅在队列空闲时才应用。
  /// 结果按组件给出（upToDate / updated / busy / failed）。启动与按钮共用此入口。
  Future<EngineUpdateResult> checkEngineUpdates({bool force = false}) async {
    if (!force && _withinThrottle()) {
      return const EngineUpdateResult(
          ytDlp: ComponentUpdateOutcome.upToDate,
          ffmpeg: ComponentUpdateOutcome.upToDate);
    }

    final svc = ref.read(engineServiceProvider);
    final busy = ref.read(downloadQueueProvider.notifier).hasActive;

    ComponentUpdateOutcome yt; String? ytV; String? ytErr;
    try {
      final u = await svc.checkForUpdate();
      if (u == null) {
        yt = ComponentUpdateOutcome.upToDate;
      } else if (busy) {
        yt = ComponentUpdateOutcome.busy;
      } else {
        await svc.applyUpdate(u);
        yt = ComponentUpdateOutcome.updated;
        ytV = u.toString();
      }
    } on DownloadException catch (e) {
      yt = ComponentUpdateOutcome.failed;
      ytErr = e.detail;
    } catch (e) {
      yt = ComponentUpdateOutcome.failed;
      ytErr = e.toString();
    }

    ComponentUpdateOutcome ff; String? ffV; String? ffErr;
    try {
      final u = await svc.checkFfmpegUpdate();
      if (u == null) {
        ff = ComponentUpdateOutcome.upToDate;
      } else if (busy) {
        ff = ComponentUpdateOutcome.busy;
      } else {
        await svc.applyFfmpegUpdate(u);
        ff = ComponentUpdateOutcome.updated;
        ffV = u.toString();
      }
    } on DownloadException catch (e) {
      ff = ComponentUpdateOutcome.failed;
      ffErr = e.detail;
    } catch (e) {
      ff = ComponentUpdateOutcome.failed;
      ffErr = e.toString();
    }

    unawaited(ref.read(sharedPrefsProvider)
        .setInt(lastEngineCheckKey, DateTime.now().millisecondsSinceEpoch));
    ref.invalidate(engineVersionsProvider);
    return EngineUpdateResult(
      ytDlp: yt,
      ffmpeg: ff,
      ytDlpVersion: ytV,
      ffmpegVersion: ffV,
      ytDlpError: ytErr,
      ffmpegError: ffErr,
    );
  }
}
