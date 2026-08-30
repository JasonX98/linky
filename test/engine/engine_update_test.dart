// test/engine/engine_update_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/engine_update.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/process_launcher.dart';

/// 测试用：按指定首行返回进程输出（默认走 stderr，stdout 可空）。
class _FakeAppProcess implements AppProcess {
  _FakeAppProcess(this._stderrLine, [this._stdoutLine]);
  final String? _stderrLine;
  final String? _stdoutLine;
  @override
  Stream<String> get stdout => _stdoutLine == null
      ? const Stream<String>.empty()
      : Stream.value(_stdoutLine);
  @override
  Stream<String> get stderr => _stderrLine == null
      ? const Stream<String>.empty()
      : Stream.value(_stderrLine);
  @override
  Future<int> get exitCode => Future.value(0);
  @override
  void kill() {}
  @override
  int get pid => 1;
  @override
  Future<void> killTree() async {}
}

class _FakeLauncher implements ProcessLauncher {
  _FakeLauncher(this._stderrLine, [this._stdoutLine]);
  final String? _stderrLine;
  final String? _stdoutLine;
  @override
  Future<AppProcess> start(String executable, List<String> arguments,
          {Map<String, String>? environment}) async =>
      _FakeAppProcess(_stderrLine, _stdoutLine);
}

/// 测试用：直接给定 ffmpeg 路径（不校验文件存在）。
class _FakeLocator extends EngineLocator {
  _FakeLocator(this._ffmpegPath);
  final String? _ffmpegPath;
  @override
  ResolvedEngine resolve() =>
      ResolvedEngine(ytDlpPath: r'C:\fake\yt-dlp.exe', ffmpegPath: _ffmpegPath);
}

void main() {
  group('EngineVersion', () {
    test('parses date and minor formats', () {
      expect(EngineVersion.tryParse('2026.08.19')!.toString(), '2026.08.19');
      expect(EngineVersion.tryParse('2026.08.19.1')!.toString(), '2026.08.19.1');
      expect(EngineVersion.tryParse('2026.8.19'), isNotNull);
      expect(EngineVersion.tryParse('not-a-version'), isNull);
      expect(EngineVersion.tryParse(''), isNull);
    });
    test('orders correctly', () {
      expect(EngineVersion.tryParse('2026.8.19')!.isNewerThan(EngineVersion.tryParse('2026.8.18')!), isTrue);
      expect(EngineVersion.tryParse('2026.8.19')!.isNewerThan(EngineVersion.tryParse('2026.8.19')!), isFalse);
      expect(EngineVersion.tryParse('2026.8.19.1')!.isNewerThan(EngineVersion.tryParse('2026.8.19')!), isTrue);
      expect(EngineVersion.tryParse('2025.12.31')!.isNewerThan(EngineVersion.tryParse('2026.1.1')!), isFalse);
    });
  });

  group('EngineUpdateService', () {
    test('checkForUpdate returns latest when newer', () async {
      final service = EngineUpdateService(
          fetchLatestTag: () async => '2026.09.01',
          readLocalVersion: () async => '2026.08.19');
      final v = await service.checkForUpdate();
      expect(v, isNotNull);
      expect(v!.toString(), '2026.09.01');
    });
    test('checkForUpdate returns null when up to date', () async {
      final service = EngineUpdateService(
          fetchLatestTag: () async => '2020.01.01',
          readLocalVersion: () async => '2026.08.19');
      expect(await service.checkForUpdate(), isNull);
    });

    test('applyUpdate downloads, verifies, and atomically replaces', () async {
      final dir = await Directory.systemTemp.createTemp('eng_upd');
      addTearDown(() => dir.delete(recursive: true));
      // EngineLocator(baseDirOverride: dir.path) 解析到捆绑布局下的 bin 目录
      final bin =
          p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
      Directory(bin).createSync(recursive: true);
      final exe = p.join(bin, 'yt-dlp.exe');
      File(exe).writeAsStringSync('OLD');

      final service = EngineUpdateService(
        locator: EngineLocator(baseDirOverride: dir.path),
        downloader: (dest) async => File(dest).writeAsStringSync('NEW'),
        verifier: (path) async {},
      );
      await service.applyUpdate(EngineVersion.tryParse('2026.09.01')!);

      expect(File(exe).readAsStringSync(), 'NEW');
      expect(File(p.join(bin, 'yt-dlp.exe.bak')).existsSync(), isFalse);
    });

    test('applyUpdate cleans up stale .new/.bak on verify failure and reports friendly message', () async {
      final dir = await Directory.systemTemp.createTemp('eng_upd_fail');
      addTearDown(() => dir.delete(recursive: true));
      final bin =
          p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
      Directory(bin).createSync(recursive: true);
      final exe = p.join(bin, 'yt-dlp.exe');
      File(exe).writeAsStringSync('OLD');
      // 预置一个陈旧的 .new，模拟上次崩溃遗留——applyUpdate 必须清除它。
      File(p.join(bin, 'yt-dlp.exe.new')).writeAsStringSync('STALE');

      final service = EngineUpdateService(
        locator: EngineLocator(baseDirOverride: dir.path),
        downloader: (dest) async => File(dest).writeAsStringSync('NEW'),
        verifier: (path) async => throw StateError('bad binary'),
      );

      await expectLater(
        service.applyUpdate(EngineVersion.tryParse('2026.09.01')!),
        throwsA(isA<DownloadException>().having((e) => e.detail,
            'detail', contains('更新失败'))),
      );

      expect(File(exe).readAsStringSync(), 'OLD');
      expect(File(p.join(bin, 'yt-dlp.exe.new')).existsSync(), isFalse);
      expect(File(p.join(bin, 'yt-dlp.exe.bak')).existsSync(), isFalse);
    });

    test('ensureEngine re-downloads when missing', () async {
      final dir = await Directory.systemTemp.createTemp('eng_self');
      addTearDown(() => dir.delete(recursive: true));
      // 空 bin，无 yt-dlp.exe → resolve 抛 EngineMissingException → ensureEngine 下载
      final bin =
          p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
      await Directory(bin).create(recursive: true);
      final service = EngineUpdateService(
        locator: EngineLocator(baseDirOverride: dir.path),
        downloader: (dest) async => File(dest).writeAsStringSync('DL'),
      );
      await service.ensureEngine();
      expect(File(p.join(bin, 'yt-dlp.exe')).readAsStringSync(), 'DL');
    });

    test('ensureEngine is a no-op when engine already present', () async {
      final dir = await Directory.systemTemp.createTemp('eng_present');
      addTearDown(() => dir.delete(recursive: true));
      final bin =
          p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
      Directory(bin).createSync(recursive: true);
      File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('EXISTS');

      var downloads = 0;
      final service = EngineUpdateService(
        locator: EngineLocator(baseDirOverride: dir.path),
        downloader: (dest) async {
          downloads++;
          File(dest).writeAsStringSync('DL');
        },
      );
      await service.ensureEngine();
      expect(downloads, 0);
    });
  });

  group('ffmpegVersion', () {
    test('parses version from ffmpeg stderr first line', () async {
      final service = EngineUpdateService(
        locator: _FakeLocator(r'C:\fake\ffmpeg.exe'),
        launcher: _FakeLauncher('ffmpeg version 7.0.0-essentials_build ...'),
      );
      expect(await service.ffmpegVersion(), '7.0.0');
    });

    test('falls back to stdout when stderr is empty', () async {
      final service = EngineUpdateService(
        locator: _FakeLocator(r'C:\fake\ffmpeg.exe'),
        launcher: _FakeLauncher(null, 'ffmpeg version 6.1.1'),
      );
      expect(await service.ffmpegVersion(), '6.1.1');
    });

    test('returns null when ffmpeg missing', () async {
      final service = EngineUpdateService(locator: _FakeLocator(null));
      expect(await service.ffmpegVersion(), isNull);
    });
  });

  group('ffmpeg update', () {
    test('checkFfmpegUpdate returns newer version when remote is newer',
        () async {
      final service = EngineUpdateService(
        locator: _FakeLocator(r'C:\fake\ffmpeg.exe'),
        launcher: _FakeLauncher('ffmpeg version 9.0.1'),
        fetchFfmpegLatestVersion: () async => '9.0.1',
      );
      // 本地=远端 → 无更新
      expect(await service.checkFfmpegUpdate(), isNull);
    });

    test('checkFfmpegUpdate returns remote when it is newer', () async {
      final service = EngineUpdateService(
        locator: _FakeLocator(r'C:\fake\ffmpeg.exe'),
        launcher: _FakeLauncher('ffmpeg version 8.0.0'),
        fetchFfmpegLatestVersion: () async => '9.0.1',
      );
      final v = await service.checkFfmpegUpdate();
      expect(v, isNotNull);
      expect(v!.toString(), '9.0.1');
    });

    test('applyFfmpegUpdate extracts and swaps ffmpeg + ffprobe from zip',
        () async {
      final dir = await Directory.systemTemp.createTemp('eng-ffmpeg-');
      addTearDown(() => dir.delete(recursive: true));
      final binDir =
          p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
      Directory(binDir).createSync(recursive: true);
      File(p.join(binDir, 'yt-dlp.exe')).writeAsStringSync('YT');
      File(p.join(binDir, 'ffmpeg.exe')).writeAsStringSync('OLD-FF');
      File(p.join(binDir, 'ffprobe.exe')).writeAsStringSync('OLD-P');

      final zipBytes = ZipEncoder().encode(Archive()
        ..addFile(
            ArchiveFile('ffmpeg-9.0.1/bin/ffmpeg.exe', 4, [0, 1, 2, 3]))
        ..addFile(
            ArchiveFile('ffmpeg-9.0.1/bin/ffprobe.exe', 4, [4, 5, 6, 7])));
      var zipDownloaded = false;
      final service = EngineUpdateService(
        locator: EngineLocator(baseDirOverride: dir.path),
        ffmpegDownloader: (zipPath) async {
          zipDownloaded = true;
          File(zipPath).writeAsBytesSync(zipBytes);
        },
      );

      await service.applyFfmpegUpdate(EngineVersion.tryParse('9.0.1')!);

      expect(zipDownloaded, isTrue);
      expect(File(p.join(binDir, 'ffmpeg.exe')).readAsBytesSync(), [0, 1, 2, 3]);
      expect(File(p.join(binDir, 'ffprobe.exe')).readAsBytesSync(), [4, 5, 6, 7]);
      // .bak 已清理
      expect(File(p.join(binDir, 'ffmpeg.exe.bak')).existsSync(), isFalse);
      expect(File(p.join(binDir, 'ffprobe.exe.bak')).existsSync(), isFalse);
    });
  });
}
