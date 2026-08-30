// lib/engine/yt_dlp_parser.dart
import 'dart:convert';

import 'package:video_downloader/engine/models.dart';

String? _str(Map<String, dynamic> m, String key) => m[key]?.toString();

int? _int(Map<String, dynamic> m, String key) => (m[key] as num?)?.toInt();

AnalysisResult parseAnalysisJson(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  if (map['_type'] == 'playlist') {
    final entries = (map['entries'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) {
          final url = (_str(e, 'url') ?? _str(e, 'webpage_url') ?? '').trim();
          final hasTitle = _str(e, 'title') != null;
          final hasId = _str(e, 'id') != null;
          return PlaylistEntry(
            id: (_str(e, 'id') ?? url).trim(),
            title: hasTitle
                ? _str(e, 'title')!
                : hasId
                    ? _str(e, 'id')!
                    : (_titleFromUrl(url) ?? ''),
            url: url,
            durationSec: _int(e, 'duration'),
            titleIsFallback: !hasTitle,
          );
        })
        .toList();
    return PlaylistResult(
      PlaylistMeta(title: _str(map, 'title'), entries: entries),
    );
  }
  return VideoResult(
    VideoMeta(
      id: _str(map, 'id') ?? '',
      title: _str(map, 'title') ??
          _titleFromUrl(_str(map, 'webpage_url')) ??
          '',
      uploader: _str(map, 'uploader') ?? _str(map, 'channel'),
      durationSec: _int(map, 'duration'),
      thumbnailUrl: _str(map, 'thumbnail'),
      webUrl: _str(map, 'webpage_url') ?? _str(map, 'original_url') ?? '',
    ),
  );
}

String? _titleFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final path = url.split('?').first;
  final segments = path.split('/').where((s) => s.trim().isNotEmpty).toList();
  if (segments.isEmpty) return null;
  var name = segments.last;
  if (name.length > 60) name = name.substring(0, 60);
  return name;
}

final _progressRe = RegExp(r'^PROGRESS\|([^|]*)\|([^|]*)\|([^|]*)');

DownloadProgress? parseProgressLine(String line) {
  final m = _progressRe.firstMatch(line.trim());
  if (m == null) return null;
  final pct = double.tryParse(m.group(1)!.replaceAll('%', '').trim()) ?? 0;
  final speedRaw = m.group(2)!.trim();
  final etaRaw = m.group(3)!.trim();
  return DownloadProgress(
    fraction: (pct / 100).clamp(0.0, 1.0),
    speed: speedRaw.startsWith('Unknown') ? null : speedRaw,
    etaSeconds: parseEtaSeconds(etaRaw),
  );
}

int? parseEtaSeconds(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = parts.map((s) => int.tryParse(s.trim())).toList();
  if (nums.any((n) => n == null)) return null;
  var seconds = 0;
  for (final n in nums) {
    seconds = seconds * 60 + n!;
  }
  return seconds;
}

EngineError classifyYtDlpError(String stderrTail) {
  final t = stderrTail.toLowerCase();
  EngineError at(EngineErrorKind kind) => EngineError(
      kind, detail: _lastNonEmptyLine(stderrTail));
  if (t.contains('sign in') ||
      t.contains('confirm your age') ||
      t.contains('members') ||
      t.contains('join this channel') ||
      t.contains('bot') ||
      t.contains('not a bot') ||
      t.contains('cookies')) {
    return at(EngineErrorKind.login);
  }
  if (t.contains('not available in your country') ||
      t.contains('geo-restricted') ||
      t.contains('geo restricted') ||
      t.contains('blocked it in your country')) {
    return at(EngineErrorKind.geo);
  }
  if (t.contains('video unavailable') ||
      t.contains('removed by the uploader') ||
      t.contains('private video') ||
      t.contains('does not exist') ||
      t.contains('live event has ended')) {
    return at(EngineErrorKind.unavailable);
  }
  if (t.contains('timed out') ||
      t.contains('timeout') ||
      t.contains('unable to download') ||
      t.contains('connection') ||
      t.contains('getaddrinfo') ||
      t.contains('network') ||
      t.contains('connection reset') ||
      t.contains('remote end closed') ||
      t.contains('413') ||
      t.contains('429') ||
      t.contains('temporarily unavailable')) {
    return at(EngineErrorKind.network);
  }
  return at(EngineErrorKind.unknown);
}

String _lastNonEmptyLine(String s) => s
    .split('\n')
    .where((l) => l.trim().isNotEmpty)
    .lastOrNull?.trim() ?? '';
