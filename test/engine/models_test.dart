import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/models.dart';

void main() {
  group('QualityPreset.formatSelector', () {
    test('maps to yt-dlp selectors', () {
      expect(QualityPreset.best.formatSelector, 'bv*+ba/b');
      expect(QualityPreset.p1080.formatSelector,
          'bv*[height<=1080]+ba/b[height<=1080]');
      expect(QualityPreset.p720.formatSelector,
          'bv*[height<=720]+ba/b[height<=720]');
      expect(QualityPreset.p480.formatSelector,
          'bv*[height<=480]+ba/b[height<=480]');
    });
  });

  test('DownloadProgress holds fraction and optional fields', () {
    const p = DownloadProgress(fraction: 0.5, speed: '1.00MiB/s', etaSeconds: 10);
    expect(p.fraction, 0.5);
    expect(p.speed, '1.00MiB/s');
    expect(p.etaSeconds, 10);
  });

  test('DownloadException exposes kind and detail', () {
    const e = DownloadException(EngineErrorKind.network, 'raw output');
    expect(e.kind, EngineErrorKind.network);
    expect(e.detail, 'raw output');
    expect(e.toString(), contains('DownloadException'));
    expect(e.toString(), contains('raw output'));
  });
}
