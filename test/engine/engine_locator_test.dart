// test/engine/engine_locator_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/models.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('engine_locator_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('resolves bundled layout under base dir', () {
    final bin = p.join(temp.path, 'data', 'flutter_assets', 'assets', 'bin');
    Directory(bin).createSync(recursive: true);
    File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('');
    File(p.join(bin, 'ffmpeg.exe')).writeAsStringSync('');

    final engine = EngineLocator(baseDirOverride: temp.path).resolve();
    expect(engine.ytDlpPath, p.join(bin, 'yt-dlp.exe'));
    expect(engine.ffmpegPath, p.join(bin, 'ffmpeg.exe'));
  });

  test('ffmpegPath null when ffmpeg missing', () {
    final bin = p.join(temp.path, 'data', 'flutter_assets', 'assets', 'bin');
    Directory(bin).createSync(recursive: true);
    File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('');

    final engine = EngineLocator(baseDirOverride: temp.path).resolve();
    expect(engine.ffmpegPath, isNull);
  });

  test('throws EngineMissingException when yt-dlp.exe absent', () {
    expect(
      () => EngineLocator(baseDirOverride: temp.path).resolve(),
      throwsA(isA<EngineMissingException>()),
    );
  });

  test('env var YTDLP_ENGINE_DIR points at engine dir directly', () {
    File(p.join(temp.path, 'yt-dlp.exe')).writeAsStringSync('');
    final engine = EngineLocator(
      env: (key) => key == 'YTDLP_ENGINE_DIR' ? temp.path : null,
    ).resolve();
    expect(engine.ytDlpPath, p.join(temp.path, 'yt-dlp.exe'));
  });

  test('baseDirOverride takes precedence over env var', () {
    final bin = p.join(temp.path, 'data', 'flutter_assets', 'assets', 'bin');
    Directory(bin).createSync(recursive: true);
    File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('');

    final engine = EngineLocator(
      baseDirOverride: temp.path,
      env: (key) => key == 'YTDLP_ENGINE_DIR' ? r'C:\elsewhere' : null,
    ).resolve();
    expect(engine.ytDlpPath, p.join(bin, 'yt-dlp.exe'));
  });
}
