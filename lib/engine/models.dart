enum QualityPreset {
  best('最佳画质', 'bv*+ba/b'),
  p1080('1080p', 'bv*[height<=1080]+ba/b[height<=1080]'),
  p720('720p', 'bv*[height<=720]+ba/b[height<=720]'),
  p480('480p', 'bv*[height<=480]+ba/b[height<=480]');

  const QualityPreset(this.label, this.formatSelector);
  final String label;
  final String formatSelector;
}

enum EngineErrorKind {
  login, geo, unavailable, network, timeout, parseFailed, engineMissing, outputFileMissing, unknown,
}

class EngineError {
  const EngineError(this.kind, {this.detail = ''});
  final EngineErrorKind kind;
  final String detail;
}

class VideoMeta {
  const VideoMeta({
    required this.id,
    required this.title,
    required this.webUrl,
    this.uploader,
    this.thumbnailUrl,
    this.durationSec,
  });
  final String id;
  final String title;
  final String webUrl;
  final String? uploader;
  final String? thumbnailUrl;
  final int? durationSec;
}

class PlaylistEntry {
  const PlaylistEntry({
    required this.id,
    required this.title,
    required this.url,
    this.durationSec,
    this.titleIsFallback = false,
  });
  final String id;
  final String title;
  final String url;
  final int? durationSec;

  /// true：title 是解析回退产物（B 站分 P 条目常缺 title，id/URL 文件名
  /// 仅为占位），UI 应显示本地化的“第N集/Episode N”而非该回退值
  final bool titleIsFallback;
}

class PlaylistMeta {
  const PlaylistMeta({this.title, required this.entries});
  final String? title;
  final List<PlaylistEntry> entries;
}

sealed class AnalysisResult {
  const AnalysisResult();
}

class VideoResult extends AnalysisResult {
  const VideoResult(this.meta);
  final VideoMeta meta;
}

class PlaylistResult extends AnalysisResult {
  const PlaylistResult(this.meta);
  final PlaylistMeta meta;
}

class DownloadProgress {
  const DownloadProgress({required this.fraction, this.speed, this.etaSeconds});
  final double fraction;
  final String? speed;
  final int? etaSeconds;
}

class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.preset,
    required this.outputDir,
    this.ffmpegPath,
    this.taskId,
    this.uploader,
    this.durationSec,
    this.cookieFile,
  });
  final String url;
  final QualityPreset preset;
  final String outputDir;
  final String? ffmpegPath;
  final String? taskId;
  final String? uploader;
  final int? durationSec;

  /// 全局 Cookie 文件路径（Netscape 格式）；非空时传给 yt-dlp `--cookies`。
  final String? cookieFile;
}

class DownloadException implements Exception {
  const DownloadException(this.kind, [this.detail = '']);
  final EngineErrorKind kind;
  final String detail;
  @override
  String toString() => 'DownloadException($kind): $detail';
}

class EngineMissingException implements Exception {
  const EngineMissingException(this.path);
  final String path;
  @override
  String toString() => 'EngineMissingException: $path';
}
