// test/features/settings/settings_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/engine/engine_update.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';
import 'package:video_downloader/features/download/queue_controller.dart';
import 'package:video_downloader/features/download/download_task.dart';

/// 仅用于测试：覆写 hasActive，不依赖真实队列状态。
class _FakeQueue extends DownloadQueueController {
  _FakeQueue(this._active);
  final bool _active;
  @override
  bool get hasActive => _active;
  @override
  List<DownloadTask> build() => const [];
}

/// 仅用于测试：完全覆写四个检查/应用方法，避免真实 locator/launcher/zip 文件 I/O。
class _CtrlService extends EngineUpdateService {
  _CtrlService({this.ytUpdate, this.ffUpdate, this.ytApplyError});

  final String? ytUpdate;
  final String? ffUpdate;
  final DownloadException? ytApplyError;

  @override
  Future<EngineVersion?> checkForUpdate() async =>
      ytUpdate == null ? null : EngineVersion.tryParse(ytUpdate!);
  @override
  Future<void> applyUpdate(EngineVersion v) async {
    if (ytApplyError != null) throw ytApplyError!;
  }

  @override
  Future<EngineVersion?> checkFfmpegUpdate() async =>
      ffUpdate == null ? null : EngineVersion.tryParse(ffUpdate!);
  @override
  Future<void> applyFfmpegUpdate(EngineVersion v) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> make(
      Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('defaults: concurrency 3, best preset, language follows system', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final SettingsState s = c.read(settingsProvider);
    expect(s.concurrency, 3);
    expect(s.defaultPreset, QualityPreset.best);
    expect(s.language, isIn(['zh', 'en']));
    expect(s.downloadDir, isNull);
  });

  test('setters persist to prefs and update state', () async {
    final (c, prefs) = await make({});
    final ctl = c.read(settingsProvider.notifier);
    ctl.setConcurrency(5);
    ctl.setDefaultPreset(QualityPreset.p720);
    ctl.setDownloadDir(r'D:\Videos');
    ctl.setLanguage('en');
    await Future<void>.delayed(Duration.zero);

    final s = c.read(settingsProvider);
    expect(s.concurrency, 5);
    expect(s.defaultPreset, QualityPreset.p720);
    expect(s.downloadDir, r'D:\Videos');
    expect(s.language, 'en');
    expect(prefs.getInt('concurrency'), 5);
    expect(prefs.getInt('defaultPreset'), QualityPreset.p720.index);
    expect(prefs.getString('downloadDir'), r'D:\Videos');
    expect(prefs.getString('language'), 'en');
  });

  test('setCookieFile persists and clears', () async {
    final (c, prefs) = await make({});
    final ctl = c.read(settingsProvider.notifier);
    ctl.setCookieFile(r'C:\cookies\net.txt');
    expect(c.read(settingsProvider).cookieFile, r'C:\cookies\net.txt');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('cookieFile'), r'C:\cookies\net.txt');

    ctl.setCookieFile(null);
    expect(c.read(settingsProvider).cookieFile, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('cookieFile'), isNull);
  });

  test('concurrency clamps to 1..5 and loads persisted values', () async {
    // defaultPreset 持久化为 QualityPreset.index；p480.index = 3
    final (c, _) = await make({'concurrency': 9, 'defaultPreset': 3});
    final s = c.read(settingsProvider);
    expect(s.concurrency, 3.clamp(1, 5)); // 越界回落默认 3
    expect(s.defaultPreset, QualityPreset.p480);
    c.read(settingsProvider.notifier).setConcurrency(0);
    expect(c.read(settingsProvider).concurrency, 1);
  });

  group('checkEngineUpdates', () {
    Future<ProviderContainer> makeWith(
        Map<String, Object> initial, bool queueActive, _CtrlService service) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        engineServiceProvider.overrideWithValue(service),
        downloadQueueProvider.overrideWith(() => _FakeQueue(queueActive)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('returns both upToDate when no newer versions', () async {
      final service = _CtrlService();
      final c = await makeWith({}, false, service);
      final r = await c.read(settingsProvider.notifier).checkEngineUpdates();
      expect(r.ytDlp, ComponentUpdateOutcome.upToDate);
      expect(r.ffmpeg, ComponentUpdateOutcome.upToDate);
    });

    test('applies yt-dlp update when newer and idle; ffmpeg stays up-to-date',
        () async {
      final service = _CtrlService(ytUpdate: '2026.09.01');
      final c = await makeWith({}, false, service);
      final r = await c.read(settingsProvider.notifier).checkEngineUpdates();
      expect(r.ytDlp, ComponentUpdateOutcome.updated);
      expect(r.ytDlpVersion, '2026.09.01');
      expect(r.ffmpeg, ComponentUpdateOutcome.upToDate);
    });

    test('applies yt-dlp and ffmpeg updates when both are newer', () async {
      final service = _CtrlService(ytUpdate: '2026.09.01', ffUpdate: '9.0.1');
      final c = await makeWith({}, false, service);
      final r = await c.read(settingsProvider.notifier).checkEngineUpdates();
      expect(r.ytDlp, ComponentUpdateOutcome.updated);
      expect(r.ytDlpVersion, '2026.09.01');
      expect(r.ffmpeg, ComponentUpdateOutcome.updated);
      expect(r.ffmpegVersion, '9.0.1');
    });

    test('reports busy for both when a download is active', () async {
      final service = _CtrlService(ytUpdate: '2026.09.01', ffUpdate: '9.0.1');
      final c = await makeWith({}, true, service);
      final r = await c.read(settingsProvider.notifier).checkEngineUpdates();
      expect(r.ytDlp, ComponentUpdateOutcome.busy);
      expect(r.ffmpeg, ComponentUpdateOutcome.busy);
    });

    test('reports failed for yt-dlp with detail when apply throws', () async {
      final service = _CtrlService(
        ytUpdate: '2026.09.01',
        ytApplyError:
            const DownloadException(EngineErrorKind.network, 'HTTP 500'),
      );
      final c = await makeWith({}, false, service);
      final r = await c.read(settingsProvider.notifier).checkEngineUpdates();
      expect(r.ytDlp, ComponentUpdateOutcome.failed);
      expect(r.ytDlpError, contains('HTTP 500'));
      expect(r.ffmpeg, ComponentUpdateOutcome.upToDate);
    });

  });
}
