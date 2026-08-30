// test/features/download/analysis_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/core/providers.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/features/download/analysis_controller.dart';
import 'package:video_downloader/features/download/providers.dart';

class FakeProbeService extends YtDlpService {
  FakeProbeService({this.result, this.error, this.generic = false});
  final AnalysisResult? result;
  final DownloadException? error;
  final bool generic;

  @override
  Future<AnalysisResult> probe(String url, {String? cookieFile}) async {
    if (generic) throw const SocketLike();
    if (error != null) throw error!;
    return result!;
  }
}

class SocketLike implements Exception {
  const SocketLike();
}

late SharedPreferences prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer(YtDlpService service) {
    final c = ProviderContainer(overrides: [
      ytDlpServiceProvider.overrideWithValue(service),
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('idle by default and reset returns to idle', () {
    final c = makeContainer(FakeProbeService());
    expect(c.read(analysisProvider), isA<AnalysisIdle>());
    c.read(analysisProvider.notifier).reset();
    expect(c.read(analysisProvider), isA<AnalysisIdle>());
  });

  test('analyze video lands in AnalysisVideo', () async {
    final c = makeContainer(FakeProbeService(result: VideoResult(
        const VideoMeta(id: '1', title: '测试视频', webUrl: 'u'))));
    await c.read(analysisProvider.notifier).analyze('u');
    final s = c.read(analysisProvider);
    expect(s, isA<AnalysisVideo>());
    expect((s as AnalysisVideo).meta.title, '测试视频');
  });

  test('analyze playlist lands in AnalysisPlaylist', () async {
    final c = makeContainer(FakeProbeService(result: PlaylistResult(
        const PlaylistMeta(title: 'PL', entries: []))));
    await c.read(analysisProvider.notifier).analyze('u');
    expect(c.read(analysisProvider), isA<AnalysisPlaylist>());
  });

  test('download exception surfaces error kind and keeps detail', () async {
    final c = makeContainer(FakeProbeService(
        error: const DownloadException(
            EngineErrorKind.network, '网络错误：请检查网络连接后重试')));
    await c.read(analysisProvider.notifier).analyze('u');
    final s = c.read(analysisProvider);
    expect(s, isA<AnalysisError>());
    expect((s as AnalysisError).kind, EngineErrorKind.network);
    expect(s.message, '网络错误：请检查网络连接后重试');
  });

  test('generic exception surfaces generic message with unknown kind',
      () async {
    final c = makeContainer(FakeProbeService(generic: true));
    await c.read(analysisProvider.notifier).analyze('u');
    final s = c.read(analysisProvider) as AnalysisError;
    expect(s.kind, EngineErrorKind.unknown);
    expect(s.message, contains('SocketLike')); // message 保留原始 detail
  });
}
