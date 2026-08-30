// test/engine/yt_dlp_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_parser.dart';

const _videoJson = '''
{"id":"dQw4w9WgXcQ","title":"Sample Video","uploader":"Test Channel",
 "duration":213,"thumbnail":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hq720.jpg",
 "webpage_url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","_type":"video",
 "formats":[],"ext":"mp4"}
''';

const _playlistJson = '''
{"_type":"playlist","title":"My Playlist","entries":[
  {"_type":"url","ie_key":"Youtube","id":"abc123","title":"Entry One",
   "url":"https://www.youtube.com/watch?v=abc123","duration":100},
  {"_type":"url","ie_key":"Youtube","id":"def456","title":"Entry Two",
   "url":"https://www.youtube.com/watch?v=def456"},
  {"_type":"url","ie_key":"Youtube","id":"ghi789","title":"Entry Three",
   "url":"https://www.youtube.com/watch?v=ghi789","duration":null}
 ]}
''';

void main() {
  test('parses single video json', () {
    final result = parseAnalysisJson(_videoJson);
    expect(result, isA<VideoResult>());
    final video = (result as VideoResult).meta;
    expect(video.id, 'dQw4w9WgXcQ');
    expect(video.title, 'Sample Video');
    expect(video.uploader, 'Test Channel');
    expect(video.durationSec, 213);
    expect(video.thumbnailUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hq720.jpg');
    expect(video.webUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  });

  test('parses playlist json with entries', () {
    final result = parseAnalysisJson(_playlistJson);
    expect(result, isA<PlaylistResult>());
    final pl = (result as PlaylistResult).meta;
    expect(pl.title, 'My Playlist');
    expect(pl.entries.length, 3);
    expect(pl.entries[0].id, 'abc123');
    expect(pl.entries[0].durationSec, 100);
    expect(pl.entries[1].durationSec, isNull);
  });

  test('missing title and url falls back to empty title', () {
    final result = parseAnalysisJson('{"_type":"video","id":"x"}');
    expect((result as VideoResult).meta.title, '');
  });

  test('missing title falls back to url filename', () {
    final result = parseAnalysisJson(
        '{"_type":"video","id":"x","webpage_url":"https://www.bilibili.com/video/BV1XVtc68E46?p=1"}');
    expect((result as VideoResult).meta.title, 'BV1XVtc68E46');
  });

  test('playlist entry without title/id falls back to url filename', () {
    final result = parseAnalysisJson(
        '{"_type":"playlist","title":"PL","entries":[{"url":"https://www.bilibili.com/video/BVabc123?p=2"}]}');
    final entry =
        (result as PlaylistResult).meta.entries.single;
    expect(entry.title, 'BVabc123');
    expect(entry.id, contains('BVabc123'));
  });

  test('entry with id but no title is also a fallback title', () {
    final result = parseAnalysisJson(
        '{"_type":"playlist","title":"PL","entries":[{"id":"BVx","url":"https://x/BVy"}]}');
    final entry = (result as PlaylistResult).meta.entries.single;
    expect(entry.titleIsFallback, isTrue);
    expect(entry.title, 'BVx');
  });

  test('missing duration yields null', () {
    final result =
        parseAnalysisJson('{"_type":"video","id":"x","title":"t","webpage_url":"u"}');
    expect((result as VideoResult).meta.durationSec, isNull);
  });

  group('parseProgressLine', () {
    test('parses PROGRESS template line', () {
      final p = parseProgressLine(
          'PROGRESS| 42.5%| 1.23MiB/s| 00:05');
      expect(p, isNotNull);
      expect(p!.fraction, closeTo(0.425, 0.0001));
      expect(p.speed, '1.23MiB/s');
      expect(p.etaSeconds, 5);
    });

    test('returns null for non-progress lines', () {
      expect(parseProgressLine('[download] Destination: x.mp4'), isNull);
      expect(parseProgressLine(''), isNull);
    });

    test('Unknown speed/eta become null', () {
      final p = parseProgressLine('PROGRESS| 10.0%| Unknown B/s| Unknown');
      expect(p!.speed, isNull);
      expect(p.etaSeconds, isNull);
    });

    test('fraction clamps to [0,1]', () {
      expect(parseProgressLine('PROGRESS| 120%| 1MiB/s| 00:01')!.fraction, 1.0);
    });
  });

  group('parseEtaSeconds', () {
    test('MM:SS', () => expect(parseEtaSeconds('01:05'), 65));
    test('HH:MM:SS', () => expect(parseEtaSeconds('01:00:00'), 3600));
    test('Unknown', () => expect(parseEtaSeconds('Unknown'), isNull));
  });

  group('classifyYtDlpError', () {
    test('video unavailable', () {
      final e = classifyYtDlpError(
          'ERROR: [youtube] abc: Video unavailable. This video is no longer available');
      expect(e.kind, EngineErrorKind.unavailable);
      expect(e.detail, contains('no longer available'));
    });
    test('network error', () {
      expect(
          classifyYtDlpError(
              'ERROR: unable to download video data: HTTP Error 403: Forbidden')
              .kind,
          EngineErrorKind.network);
    });
    test('geo restricted', () {
      expect(
          classifyYtDlpError(
                  'ERROR: [youtube] abc: This video is not available in your country.')
              .kind,
          EngineErrorKind.geo);
    });
    test('login required', () {
      expect(
          classifyYtDlpError(
                  'ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate for some users.')
              .kind,
          EngineErrorKind.login);
    });
    test('fallback keeps last stderr line as detail', () {
      final e = classifyYtDlpError('ERROR: [bilibili] 123: something weird happened');
      expect(e.kind, EngineErrorKind.unknown);
      expect(e.detail, 'ERROR: [bilibili] 123: something weird happened');
    });
    test('new network keywords', () {
      expect(classifyYtDlpError('ERROR: connection reset by peer').kind,
          EngineErrorKind.network);
      expect(classifyYtDlpError('ERROR: HTTP Error 429: Too Many Requests').kind,
          EngineErrorKind.network);
    });
    test('new login keywords', () {
      expect(
          classifyYtDlpError('ERROR: Sign in to confirm you are not a bot').kind,
          EngineErrorKind.login);
    });
    test('additional expanded signals', () {
      expect(classifyYtDlpError('ERROR: remote end closed connection').kind,
          EngineErrorKind.network);
      expect(classifyYtDlpError('ERROR: HTTP Error 413: Request Entity Too Large')
              .kind,
          EngineErrorKind.network);
      expect(
          classifyYtDlpError('ERROR: [youtube] abc: Temporarily unavailable')
              .kind,
          EngineErrorKind.network);
      expect(classifyYtDlpError('ERROR: YouTube says cookies are required').kind,
          EngineErrorKind.login);
      expect(classifyYtDlpError('ERROR: [youtube] abc: This live event has ended')
          .kind,
          EngineErrorKind.unavailable);
    });
  });
}
