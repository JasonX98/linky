// lib/engine/engine_update.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/core/logger.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/process_launcher.dart';

/// 引擎版本号：日期/语义化数字段比较（缺段按 0 处理）。
class EngineVersion implements Comparable<EngineVersion> {
  EngineVersion(List<int> raw) : this._(List.unmodifiable(raw), null);
  EngineVersion._(this.parts, this._source);

  /// 数字段 [2026,8,19]（比较使用，缺段按 0）。
  /// 不可变：屏蔽调用方/mutable 列表在构造后的篡改。
  final List<int> parts;

  /// _source 保留 tryParse 的原始文本，使 toString 能还原上游带前导零的
  /// 位宽（如 `08` → '2026.08.19'）；比较始终用 int 的 parts。
  /// 直接 ctor 构造时为空，toString 退化为 parts.join('.')。
  final String? _source;

  /// 解析 `a.b.c[.d]`，任一字段非法/整体为空（含 null/空串/垃圾）返回 null。
  static EngineVersion? tryParse(String s) {
    final trimmed = s.trim();
    final parsed =
        trimmed.split('.').map((x) => int.tryParse(x.trim())).toList();
    if (parsed.isEmpty || parsed.any((p) => p == null)) return null;
    return EngineVersion._(parsed.cast<int>(), trimmed);
  }

  bool isNewerThan(EngineVersion other) {
    final max = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < max; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  @override
  int compareTo(EngineVersion other) =>
      isNewerThan(other) ? 1 : (other.isNewerThan(this) ? -1 : 0);

  // _source 优先渲染，保留上游零填充的原始位宽；无 _source（直接 ctor）时
  // 退化为 parts.join('.')。比较语义永不依赖字符串，仅用 int 的 parts。
  @override
  String toString() => _source ?? parts.join('.');
}

/// 版本检查服务：读取本地引擎版本、拉取远端最新 tag 并比较。
class EngineUpdateService {
  EngineUpdateService({
    EngineLocator? locator,
    ProcessLauncher? launcher,
    Future<String?> Function()? fetchLatestTag,
    Future<String?> Function()? readLocalVersion,
    Future<void> Function(String destPath)? downloader,
    Future<void> Function(String exePath)? verifier,
    Future<String> Function(String url)? httpGet,
    Future<String?> Function()? fetchFfmpegLatestVersion,
    Future<void> Function(String zipPath)? ffmpegDownloader,
    this.checkTimeout = const Duration(seconds: 10),
  })  : locator = locator ?? EngineLocator(),
        launcher = launcher ?? const SystemProcessLauncher() {
    this.fetchLatestTag = fetchLatestTag ?? _fetchGitHubTag;
    this.readLocalVersion = readLocalVersion ?? () => _readLocalVersion();
    this.downloader = downloader ?? _defaultDownload;
    this.verifier = verifier ?? _defaultVerifier;
    this.httpGet = httpGet ?? _defaultHttpGet;
    this.fetchFfmpegLatestVersion =
        fetchFfmpegLatestVersion ?? _fetchGyanFfmpegVersion;
    this.ffmpegDownloader = ffmpegDownloader ?? _defaultFfmpegDownload;
  }

  final EngineLocator locator;
  final ProcessLauncher launcher;
  final Duration checkTimeout;

  /// 注入或默认远端 tag 获取函数。
  late final Future<String?> Function() fetchLatestTag;

  /// 注入或默认本地版本行读取函数。
  late final Future<String?> Function() readLocalVersion;

  /// 注入或默认下载函数：把最新引擎写入 destPath（原子替换前的暂存文件）。
  late final Future<void> Function(String destPath) downloader;

  /// 注入或默认校验函数：确认已下载的引擎可运行（任务 4 可做更细校验）。
  late final Future<void> Function(String exePath) verifier;

  /// 注入或默认 HTTP GET 函数：拉取远端 tag 文本。
  late final Future<String> Function(String url) httpGet;

  /// 注入或默认 ffmpeg 远端最新版本获取函数（gyan.dev release-version）。
  late final Future<String?> Function() fetchFfmpegLatestVersion;

  /// 注入或默认 ffmpeg 下载函数：把 essentials zip 写入 zipPath。
  late final Future<void> Function(String zipPath) ffmpegDownloader;

  /// 运行 `yt-dlp --version`（经 launcher，env utf-8）取首行并解析。
  Future<EngineVersion?> version() async {
    final s = await _readLocalVersion();
    return s == null ? null : EngineVersion.tryParse(s);
  }

  /// 读取 ffmpeg 版本号：ffmpeg 将版本打印到 stderr 首行（形如
  /// `ffmpeg version 7.0.0-...`）。取 `version` 后的版本串；无可用 ffmpeg 时返回 null。
  Future<String?> ffmpegVersion() async {
    final engine = locator.resolve();
    final path = engine.ffmpegPath;
    if (path == null) return null;
    final proc = await launcher.start(path, ['-version'],
        environment: {'PYTHONIOENCODING': 'utf-8'});
    String? firstLine;
    try {
      firstLine = await proc.stderr.first;
    } on StateError {
      try {
        firstLine = await proc.stdout.first;
      } on StateError {
        firstLine = null;
      }
    } finally {
      proc.kill();
    }
    if (firstLine == null) return null;
    final m = RegExp(r'version\s+([\d.]+)').firstMatch(firstLine);
    return m?.group(1) ?? firstLine.trim();
  }

  /// 检查是否有更新：两者均解析成功且 latest.isNewerThan(local) 才返回最新，否则 null。
  Future<EngineVersion?> checkForUpdate() async {
    final localVersion = await readLocalVersion();
    // 无可用本地版本：直接短路，避免发起一次多余的远端 tag 请求。
    if (localVersion == null) return null;
    final latestTag = await fetchLatestTag();
    if (latestTag == null) return null;
    final local = EngineVersion.tryParse(localVersion);
    final latest = EngineVersion.tryParse(latestTag);
    if (local == null || latest == null) return null;
    return latest.isNewerThan(local) ? latest : null;
  }

  /// 原子替换：下载到 `dir/yt-dlp.exe.new` → 校验 → 现→bak → 新→现 → 删 bak。
  /// 校验/替换失败（in-use 等）抛带友好文案的 [DownloadException]，并清掉
  /// 遗留的 `.new`/`.bak`，不破坏后续运行。
  Future<void> applyUpdate(EngineVersion newVersion) async {
    final engine = locator.resolve();
    final current = engine.ytDlpPath;
    final dir = p.dirname(current);
    final newPath = p.join(dir, 'yt-dlp.exe.new');
    final bakPath = p.join(dir, 'yt-dlp.exe.bak');

    // 机会式清理：上次崩溃可能遗留 .new/.bak，先清空避免断送本次替换。
    await _deleteQuietly(newPath);
    await _deleteQuietly(bakPath);

    try {
      await downloader(newPath);
      await verifier(newPath);
    } catch (e) {
      await _deleteQuietly(newPath);
      await Logger.log('engine update: download/verify failed: $e');
      throw DownloadException(
          EngineErrorKind.unknown, '更新失败：请检查网络或依赖后重试（原因：$e）');
    }

    try {
      await File(current).rename(bakPath);
      await File(newPath).rename(current);
    } catch (e) {
      // 若现文件已被移走而新文件未就位，先把 bak 还原，再清场。
      if (File(bakPath).existsSync() && !File(current).existsSync()) {
        await _quietly(() async => File(bakPath).rename(current));
      }
      await _deleteQuietly(newPath);
      await _deleteQuietly(bakPath);
      await Logger.log('engine update: swap failed: $e');
      throw DownloadException(
          EngineErrorKind.unknown, '更新失败：请关闭其他实例或稍后重试（原因：$e）');
    }
    await _deleteQuietly(bakPath);
  }

  /// 检查 ffmpeg 是否有更新：比较本地 ffmpeg 版本与 gyan.dev 最新 release 版本。
  /// 无本地 ffmpeg 或解析失败时返回 null（视为不可更新）。
  Future<EngineVersion?> checkFfmpegUpdate() async {
    final local = await ffmpegVersion();
    if (local == null) return null;
    final latest = await fetchFfmpegLatestVersion();
    if (latest == null) return null;
    final localV = EngineVersion.tryParse(local);
    final latestV = EngineVersion.tryParse(latest);
    if (localV == null || latestV == null) return null;
    return latestV.isNewerThan(localV) ? latestV : null;
  }

  /// 更新 ffmpeg：下载 essentials zip → 解压 `ffmpeg.exe`/`ffprobe.exe` → 各自原子替换。
  /// 下载/解压/替换任一失败则抛带友好文案的异常，并清理残留，不破坏后续运行。
  Future<void> applyFfmpegUpdate(EngineVersion newVersion) async {
    final engine = locator.resolve();
    final ffmpegPath = engine.ffmpegPath;
    if (ffmpegPath == null) {
      throw DownloadException(EngineErrorKind.engineMissing, 'no ffmpeg engine');
    }
    final dir = p.dirname(ffmpegPath);
    final ffprobePath = p.join(dir, 'ffprobe.exe');
    final zipPath = p.join(
        Directory.systemTemp.path, 'ffmpeg_${DateTime.now().millisecondsSinceEpoch}.zip');
    try {
      await ffmpegDownloader(zipPath);
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      await _writeAtomically(archive, 'ffmpeg.exe', ffmpegPath);
      await _writeAtomically(archive, 'ffprobe.exe', ffprobePath);
    } on DownloadException {
      rethrow;
    } catch (e) {
      await Logger.log('engine update: ffmpeg download/extract failed: $e');
      throw DownloadException(
          EngineErrorKind.unknown, 'ffmpeg 更新失败：请检查网络或依赖后重试（原因：$e）');
    } finally {
      await _deleteQuietly(zipPath);
    }
  }

  /// 从 zip 解出指定 basename 的条目，原子写入 destPath（`*.new` → 现→`*.bak` → 新→现）。
  Future<void> _writeAtomically(
      Archive archive, String basename, String destPath) async {
    final newPath = '$destPath.new';
    final bakPath = '$destPath.bak';
    await _deleteQuietly(newPath);
    await _deleteQuietly(bakPath);

    final entry = archive.files.cast<ArchiveFile?>().firstWhere(
        (f) => f != null && p.basename(f.name) == basename,
        orElse: () => null);
    if (entry == null) {
      throw DownloadException(
          EngineErrorKind.parseFailed, '$basename missing in ffmpeg zip');
    }
    final data = entry.readBytes();
    if (data == null || data.isEmpty) {
      throw DownloadException(
          EngineErrorKind.parseFailed, '$basename empty in ffmpeg zip');
    }
    await File(newPath).writeAsBytes(data);

    try {
      if (File(destPath).existsSync()) {
        await File(destPath).rename(bakPath);
      }
      await File(newPath).rename(destPath);
    } catch (e) {
      if (File(bakPath).existsSync() && !File(destPath).existsSync()) {
        await _quietly(() async => File(bakPath).rename(destPath));
      }
      await _deleteQuietly(newPath);
      await _deleteQuietly(bakPath);
      await Logger.log('engine update: ffmpeg swap failed: $e');
      throw DownloadException(
          EngineErrorKind.unknown, 'ffmpeg 更新失败：请关闭其他实例或稍后重试（原因：$e）');
    }
    await _deleteQuietly(bakPath);
  }

  /// 自愈：引擎缺失或损坏（零字节）时重新下载并再次解析确认。
  Future<void> ensureEngine() async {
    try {
      locator.resolve();
    } on EngineMissingException catch (e) {
      await downloader(e.path);
      locator.resolve();
      return;
    }
    // 存在但可能为零字节损坏（下载中断残留）：视为损坏，强制重下
    final engine = locator.resolve();
    try {
      final f = File(engine.ytDlpPath);
      if (f.existsSync() && f.lengthSync() == 0) {
        await Logger.log(
            'engine self-heal: yt-dlp.exe is zero bytes, re-downloading');
        await downloader(engine.ytDlpPath);
        locator.resolve();
      }
    } catch (e) {
      await Logger.log('engine self-heal: re-download failed: $e');
      rethrow;
    }
  }

  Future<String?> _readLocalVersion() async {
    final engine = locator.resolve();
    final proc = await launcher.start(
      engine.ytDlpPath,
      ['--version'],
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    try {
      final lines = await proc.stdout.take(1).toList();
      return lines.isEmpty ? null : lines.first.trim();
    } finally {
      // 读取首行后确保子进程终止（已退出时 kill 幂等），避免句柄泄漏。
      proc.kill();
    }
  }

  /// 默认实现：dart:io HttpClient 拉取 GitHub releases/latest 的 tag_name。
  Future<String?> _fetchGitHubTag() async {
    try {
      final body = await httpGet(
          'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest');
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final tag = decoded['tag_name'];
      return tag is String ? tag : null;
    } catch (_) {
      return null;
    }
  }

  /// 默认 httpGet：要求 GitHub REST 携带 User-Agent 否则 403；非 200 抛错。
  /// 每个阶段（连接/响应/读取体）各有 [checkTimeout] 超时，加上
  /// HttpClient 级别的 connectionTimeout 防止 TCP 握手挂死。
  Future<String> _defaultHttpGet(String url) async {
    final client = HttpClient()
      ..connectionTimeout = checkTimeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(checkTimeout);
      req.headers
          .set(HttpHeaders.userAgentHeader, 'video_downloader/1.0 (yt-dlp updater)');
      final resp = await req.close().timeout(checkTimeout);
      final body = await resp.transform(utf8.decoder).join().timeout(checkTimeout);
      if (resp.statusCode != 200) {
        throw DownloadException(EngineErrorKind.network, 'HTTP ${resp.statusCode}');
      }
      return body;
    } finally {
      client.close();
    }
  }

  /// 默认 downloader：下载 GitHub `releases/latest/download/yt-dlp.exe` 到 destPath。
  Future<void> _defaultDownload(String destPath) async {
    final client = HttpClient()
      ..connectionTimeout = checkTimeout;
    try {
      final req = await client
          .getUrl(Uri.parse(
              'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'))
          .timeout(checkTimeout);
      req.headers
          .set(HttpHeaders.userAgentHeader, 'video_downloader/1.0 (yt-dlp updater)');
      final resp = await req.close().timeout(checkTimeout);
      if (resp.statusCode != 200) {
        throw DownloadException(
            EngineErrorKind.network, 'download failed: HTTP ${resp.statusCode}');
      }
      final sink = File(destPath).openWrite();
      try {
        await resp.pipe(sink).timeout(checkTimeout);
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// 默认 ffmpeg 远端版本获取：gyan.dev `release-version` 返回纯文本当前 release 版本。
  Future<String?> _fetchGyanFfmpegVersion() async {
    try {
      final body = await httpGet(
          'https://www.gyan.dev/ffmpeg/builds/release-version');
      return body.trim();
    } catch (_) {
      return null;
    }
  }

  /// 默认 ffmpeg 下载：下载 gyan.dev essentials zip 到 zipPath。
  Future<void> _defaultFfmpegDownload(String zipPath) async {
    final client = HttpClient()
      ..connectionTimeout = checkTimeout;
    try {
      final req = await client
          .getUrl(Uri.parse(
              'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'))
          .timeout(checkTimeout);
      req.headers
          .set(HttpHeaders.userAgentHeader, 'video_downloader/1.0 (yt-dlp updater)');
      final resp = await req.close().timeout(checkTimeout);
      if (resp.statusCode != 200) {
        throw DownloadException(EngineErrorKind.network,
            'ffmpeg download failed: HTTP ${resp.statusCode}');
      }
      final sink = File(zipPath).openWrite();
      try {
        await resp.pipe(sink).timeout(checkTimeout);
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// 默认 verifier：运行 `exePath --version`，校验输出首行非空。
  Future<void> _defaultVerifier(String exePath) async {
    final proc = await launcher.start(
      exePath,
      ['--version'],
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    try {
      final lines = await proc.stdout.take(1).toList();
      final first = lines.isEmpty ? '' : lines.first.trim();
      if (first.isEmpty) {
        throw DownloadException(EngineErrorKind.unknown, 'verify: empty version output');
      }
    } finally {
      proc.kill();
    }
  }

  Future<void> _deleteQuietly(String path) async {
    final f = File(path);
    if (!await f.exists()) return;
    try {
      await f.delete();
    } catch (_) {
      // best-effort：删除失败不外抛，避免掩盖原始错误
    }
  }

  Future<void> _quietly(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      // best-effort
    }
  }
}
