@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/engine_update.dart';

// 更新管线确定性 e2e：本地 HTTP 服务器扮演 GitHub API（/releases/latest → 新 tag JSON）
// 与下载端点（假二进制字节）。注入 httpGet 做真实 Httpclient GET（带 User-Agent）
// 并重定向 github URL → 本地端点，使默认 fetchLatestTag（_fetchGitHubTag 解析）被真实执行；
// User-Agent 验证真实默认会携带该头（T2 复核）。downloader 注入真实 GET 下载到 bin；
// verifier 用 no-op（假字节非可执行）。本地版本经 readLocalVersion 注入。
// 默认跳过：运行 $env:RUN_E2E='1' 后执行 flutter test test/e2e --concurrency=1
bool get _e2eEnabled => Platform.environment['RUN_E2E'] == '1';

Future<(HttpServer, String, List<String>)> _startFakeGithub() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = <String>[];
  server.listen((req) async {
    try {
      captured.add(req.headers.value(HttpHeaders.userAgentHeader) ?? '');
      if (req.uri.path.endsWith('/releases/latest')) {
        req.response.headers.contentType = ContentType.json;
        req.response.write('{"tag_name":"2099.01.01"}');
        await req.response.close();
      } else if (req.uri.path == '/download/yt-dlp.exe') {
        req.response.headers.contentType = ContentType.binary;
        req.response.add(List<int>.filled(64, 0x42));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (_) {}
  });
  return (server, 'http://127.0.0.1:${server.port}', captured);
}

// 真实 Httpclient GET（带 User-Agent），把 github URL 重定向到本地 base
Future<String> _localGet(String base, String url) async {
  final localUrl = url.replaceFirst('https://api.github.com', base);
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(localUrl));
    req.headers.set(HttpHeaders.userAgentHeader, 'video_downloader/1.0 (yt-dlp updater)');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw StateError('HTTP ${resp.statusCode}');
    }
    return body;
  } finally {
    client.close();
  }
}

void main() {
  test('update pipeline: check, apply, self-heal against local fake GitHub',
      () async {
    final (server, base, captured) = await _startFakeGithub();
    addTearDown(() => server.close(force: true));

    final dir = await Directory.systemTemp.createTemp('eng_e2e');
    addTearDown(() => dir.delete(recursive: true));
    final bin = p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
    Directory(bin).createSync(recursive: true);
    final exe = p.join(bin, 'yt-dlp.exe');
    File(exe).writeAsStringSync('OLD');

    final service = EngineUpdateService(
      locator: EngineLocator(baseDirOverride: dir.path),
      readLocalVersion: () async => '2026.08.19',
      httpGet: (url) => _localGet(base, url),
      downloader: (dest) async {
        final client = HttpClient();
        try {
          final req = await client
              .getUrl(Uri.parse('$base/download/yt-dlp.exe'));
          final resp = await req.close();
          final bytes = await resp.fold<List<int>>(<int>[],
              (acc, chunk) => acc..addAll(chunk));
          File(dest).writeAsBytesSync(bytes);
        } finally {
          client.close();
        }
      },
      verifier: (path) async {},
    );

    final update = await service.checkForUpdate();
    expect(update, isNotNull);
    expect(update.toString(), '2099.01.01');

    await service.applyUpdate(update!);
    expect(File(exe).readAsBytesSync().length, 64);
    expect(File(p.join(bin, 'yt-dlp.exe.bak')).existsSync(), isFalse);

    expect(captured, isNotEmpty, reason: 'httpGet should hit local server');
    expect(captured.any((h) => h.contains('video_downloader')), isTrue,
        reason: 'User-Agent header missing: $captured');
  }, timeout: const Timeout(Duration(minutes: 3)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');

  test('self-heal downloads engine when missing', () async {
    final dir = await Directory.systemTemp.createTemp('eng_self_e2e');
    addTearDown(() => dir.delete(recursive: true));
    final bin = p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
    Directory(bin).createSync(recursive: true);

    final service = EngineUpdateService(
      locator: EngineLocator(baseDirOverride: dir.path),
      downloader: (dest) async =>
          File(dest).writeAsBytesSync(List<int>.filled(8, 0x51)),
      verifier: (path) async {},
    );
    await service.ensureEngine();
    expect(File(p.join(bin, 'yt-dlp.exe')).existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)),
      skip: _e2eEnabled ? null : 'set RUN_E2E=1 to run e2e');
}
