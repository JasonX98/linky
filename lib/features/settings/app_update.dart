// lib/features/settings/app_update.dart
//
// 应用自身更新的「检测 + 跳转」能力（跳转式，不做文件替换）。
// 独立于 EngineUpdateService：前者负责引擎（yt-dlp / ffmpeg）的原子替换，
// 这里只负责读取当前版本、拉取 GitHub 最新 release、比较、并引导用户打开
// 发布页。版本比较用轻量 AppVersion（可处理 `v` 前缀与 `+build` 后缀）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/theme/app_theme.dart';

/// 应用发布信息：一次 GitHub `releases/latest` 请求即拿全。
class AppRelease {
  const AppRelease({required this.version, required this.releaseUrl});

  /// 去 `v` 前缀后的纯净版本号（如 `1.0.4`）。
  final String version;

  /// GitHub release 页面 URL（`html_url`）。
  final String releaseUrl;
}

/// 应用更新检测结果：available / upToDate / failed 三态。
sealed class AppUpdateResult {
  const AppUpdateResult();
}

/// 发现新版本（latest 新于当前），可引导用户前往发布页。
class AppUpdateAvailable extends AppUpdateResult {
  const AppUpdateAvailable(this.release);
  final AppRelease release;
}

/// 当前已是最新版本，无需更新。
class AppUpdateUpToDate extends AppUpdateResult {
  const AppUpdateUpToDate();
}

/// 检测失败（网络/解析/远端不可用），提供可展示的详情但不抛异常。
class AppUpdateFailed extends AppUpdateResult {
  const AppUpdateFailed([this.detail = '']);
  final String detail;
}

/// 轻量应用版本号：解析 `v` 前缀、剥离 `+build` 后缀，按主/次/补丁分段比较。
/// 设计上与引擎的 `EngineVersion`（yt-dlp 日期式 tag）相互独立。
class AppVersion implements Comparable<AppVersion> {
  AppVersion(List<int> parts) : parts = List.unmodifiable(parts);

  final List<int> parts;

  /// 解析 `v?major.minor.patch[.x][+build]`；任一字段非法/整体为空返回 null。
  static AppVersion? tryParse(String s) {
    var t = s.trim();
    if (t.startsWith('v') || t.startsWith('V')) {
      t = t.substring(1);
    }
    final plus = t.indexOf('+');
    if (plus >= 0) t = t.substring(0, plus);
    if (t.isEmpty) return null;
    final parts = t.split('.').map((x) => int.tryParse(x.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    return AppVersion(parts.cast<int>());
  }

  bool isNewerThan(AppVersion other) {
    final max =
        parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < max; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  @override
  int compareTo(AppVersion other) =>
      isNewerThan(other) ? 1 : (other.isNewerThan(this) ? -1 : 0);

  bool _equalParts(List<int> o) {
    if (parts.length != o.length) return false;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != o[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && _equalParts(other.parts);

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => parts.join('.');
}

/// 应用更新服务：读当前版本 -> 拉远端 release -> 比较；并负责任何跳转。
class AppUpdateService {
  AppUpdateService({
    String? currentVersion,
    Future<AppRelease?> Function()? fetchLatest,
    Future<void> Function(String url)? openUrl,
    this.checkTimeout = const Duration(seconds: 10),
  })  : currentVersion = currentVersion ?? AppMeta.version {
    this.fetchLatest = fetchLatest ?? _fetchGithubLatest;
    this.openUrl = openUrl ?? _defaultOpenUrl;
  }

  /// 当前应用版本（默认取 AppMeta.version，可在测试中注入）。
  final String currentVersion;

  /// 顶层超时兜底，防止外部链路永久悬挂。
  final Duration checkTimeout;

  /// 注入或默认远端 release 获取函数（失败降级返回 null）。
  late final Future<AppRelease?> Function() fetchLatest;

  /// 注入或默认打开 release 页函数（默认 Windows explorer，测试中替换）。
  late final Future<void> Function(String url) openUrl;

  /// 检查是否有应用更新：三态返回，绝不抛异常。
  Future<AppUpdateResult> checkForUpdate() async {
    final AppRelease? release;
    try {
      release = await fetchLatest();
    } catch (_) {
      return const AppUpdateFailed();
    }
    if (release == null) return const AppUpdateFailed();
    final current = AppVersion.tryParse(currentVersion);
    final latest = AppVersion.tryParse(release.version);
    if (current == null || latest == null) return const AppUpdateFailed();
    return latest.isNewerThan(current)
        ? AppUpdateAvailable(release)
        : const AppUpdateUpToDate();
  }

  /// 打开某个 release 的发布页。
  Future<void> openReleasePage(AppRelease release) =>
      openUrl(release.releaseUrl);

  /// 默认实现：GitHub `releases/latest`，一次拿全 tag（加 `v` 前缀的版本号）
  /// 与 `html_url`。失败（请求/非 200/缺字段/解析）一律返回 null。
  Future<AppRelease?> _fetchGithubLatest() async {
    try {
      final body = await _httpGet(
          'https://api.github.com/repos/JasonX98/linky/releases/latest');
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final tag = decoded['tag_name'];
      final url = decoded['html_url'];
      if (tag is! String || url is! String) return null;
      return AppRelease(version: _stripVPrefix(tag), releaseUrl: url);
    } catch (_) {
      return null;
    }
  }

  /// 默认 httpGet：与引擎更新一致的 UA / 超时 / 系统代理支持。
  Future<String> _httpGet(String url) async {
    final client = HttpClient()
      ..connectionTimeout = checkTimeout
      ..findProxy = HttpClient.findProxyFromEnvironment;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(checkTimeout);
      req.headers.set(HttpHeaders.userAgentHeader,
          'video_downloader/${AppMeta.version} (linky updater)');
      final resp = await req.close().timeout(checkTimeout);
      if (resp.statusCode != 200) {
        throw DownloadException(
            EngineErrorKind.network, 'app update: HTTP ${resp.statusCode}');
      }
      return await resp.transform(utf8.decoder).join().timeout(checkTimeout);
    } finally {
      client.close();
    }
  }

  /// 默认打开：Windows 用 `explorer` 调用系统默认浏览器。
  Future<void> _defaultOpenUrl(String url) async {
    await Process.start('explorer', <String>[url]);
  }

  static String _stripVPrefix(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    return t;
  }
}
