# M1 引擎集成实现计划（Plan 1 / 4）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 Flutter Windows 工程，捆绑 yt-dlp/FFmpeg 引擎，通过 Process 驱动完成单视频"分析→下载→进度展示"全链路（极简 UI），验证最大风险点。

**Architecture:** Flutter 通过 `ProcessLauncher` 抽象启动捆绑的 `yt-dlp.exe`；纯函数解析器处理 JSON 元数据、进度行与错误映射；`EngineLocator` 在打包产物内定位引擎文件。UI 为薄壳，核心逻辑全部在可单测的 engine 层。

**Tech Stack:** Flutter (Windows desktop)、dart:io Process、path_provider、flutter_test。Riverpod/fluent_ui/drift 在 M2/M3 引入。

**Spec:** `docs/superpowers/specs/2026-08-28-ytdlp-downloader-design.md`（本计划实现其 §9 里程碑 M1，范围：单视频下载、极简 UI；播放列表 UI、队列、历史、设置、自动更新在后续计划）

## Global Constraints

- 平台：仅 Windows 桌面（v1）；Flutter stable，执行 Task 1 时记录具体版本
- 包名：`video_downloader`（`flutter create --project-name video_downloader`）
- 引擎文件：`yt-dlp.exe`、`ffmpeg.exe`、`ffprobe.exe` 位于 `assets/bin/`，**二进制不入 git**（`.gitignore` 忽略 `assets/bin/*.exe`），由 `tool/fetch_engine.ps1` 下载
- 画质预设映射（verbatim，见 Task 2）：best→`bv*+ba/b`；1080p→`bv*[height<=1080]+ba/b[height<=1080]`；720p→`bv*[height<=720]+ba/b[height<=720]`；480p→`bv*[height<=480]+ba/b[height<=480]`
- 下载统一参数：`--merge-output-format mp4`、`--ffmpeg-location <捆绑的 ffmpeg.exe>`、输出模板 `<下载目录>/%(title)s.%(ext)s`
- 分析超时 60s；默认下载目录 = 系统"下载"文件夹（`getDownloadsDirectory()`，失败回退 `Directory.systemTemp`）
- 子进程启动必须设置环境变量 `PYTHONIOENCODING=utf-8`（保证中文标题输出不乱码）
- 错误提示为中文友好文案（M3 接入 intl 双语）；TDD：测试先红后绿；每任务结束 git commit
- 测试命令均为 `flutter test <path>`（在 `downloadApp/` 工作目录执行）；`flutter test` 运行于 Dart VM，`dart:io` 可用

---

### Task 1: Flutter Windows 工程脚手架

**Files:**
- Create: `pubspec.yaml`、`lib/main.dart`、`windows/`（flutter create 生成）、`.gitignore`（追加条目）
- Test: `test/widget_test.dart`（flutter create 生成的默认测试）

**Interfaces:**
- Consumes: 无
- Produces: 可编译运行的 Flutter Windows 工程，包名 `video_downloader`，依赖 `path`、`path_provider`

- [ ] **Step 1: 确认环境并创建工程**

在 `downloadApp/` 目录执行：

```powershell
flutter --version   # 记录版本号，写入本任务提交信息
flutter create --platforms=windows --project-name video_downloader .
flutter pub add path path_provider
```

- [ ] **Step 2: 验证工程可用**

```powershell
flutter analyze   # 预期：No issues found!
flutter test      # 预期：默认 widget 测试通过
flutter run -d windows   # 预期：空应用窗口启动（首次编译较慢），确认后关闭
```

- [ ] **Step 3: 提交**

```powershell
git add .
git commit -m "chore: scaffold flutter windows project (video_downloader)"
```

---

### Task 2: 引擎域模型与画质预设

**Files:**
- Create: `lib/engine/models.dart`
- Test: `test/engine/models_test.dart`

**Interfaces:**
- Consumes: 无
- Produces（后续任务依赖的确切签名）:
  - `enum QualityPreset { best, p1080, p720, p480 }`，成员含 `final String label; final String formatSelector;`
  - `class VideoMeta { final String id, title, webUrl; final String? uploader, thumbnailUrl; final int? durationSec; }`（const 构造）
  - `class PlaylistEntry { final String id, title, url; final int? durationSec; }`（const 构造）
  - `class PlaylistMeta { final String? title; final List<PlaylistEntry> entries; }`（const 构造）
  - `sealed class AnalysisResult`；`class VideoResult extends AnalysisResult { final VideoMeta meta; }`；`class PlaylistResult extends AnalysisResult { final PlaylistMeta meta; }`
  - `class DownloadProgress { final double fraction; final String? speed; final int? etaSeconds; }`（const 构造，fraction ∈ [0,1]）
  - `class DownloadRequest { final String url; final QualityPreset preset; final String outputDir; final String? ffmpegPath; }`（const 构造）
  - `class DownloadException implements Exception { final String friendlyMessage; final String rawTail; const DownloadException(this.friendlyMessage, [this.rawTail = '']); }`
  - `class EngineMissingException implements Exception { final String path; const EngineMissingException(this.path); }`

- [ ] **Step 1: 写失败测试**

```dart
// test/engine/models_test.dart
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

  test('DownloadException exposes friendly message and raw tail', () {
    const e = DownloadException('网络错误', 'raw output');
    expect(e.friendlyMessage, '网络错误');
    expect(e.rawTail, 'raw output');
    expect(e.toString(), contains('网络错误'));
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/models_test.dart`
Expected: FAIL（`Error: Couldn't resolve the package 'video_downloader'` 或类未定义）

- [ ] **Step 3: 最小实现**

```dart
// lib/engine/models.dart
enum QualityPreset {
  best('最佳画质', 'bv*+ba/b'),
  p1080('1080p', 'bv*[height<=1080]+ba/b[height<=1080]'),
  p720('720p', 'bv*[height<=720]+ba/b[height<=720]'),
  p480('480p', 'bv*[height<=480]+ba/b[height<=480]');

  const QualityPreset(this.label, this.formatSelector);
  final String label;
  final String formatSelector;
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
  });
  final String id;
  final String title;
  final String url;
  final int? durationSec;
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
  });
  final String url;
  final QualityPreset preset;
  final String outputDir;
  final String? ffmpegPath;
}

class DownloadException implements Exception {
  const DownloadException(this.friendlyMessage, [this.rawTail = '']);
  final String friendlyMessage;
  final String rawTail;
  @override
  String toString() => 'DownloadException: $friendlyMessage';
}

class EngineMissingException implements Exception {
  const EngineMissingException(this.path);
  final String path;
  @override
  String toString() => 'EngineMissingException: $path';
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/models_test.dart`
Expected: PASS（全部用例绿色）

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/models.dart test/engine/models_test.dart
git commit -m "feat(engine): quality presets and domain models"
```

---

### Task 3: YtDlpParser —— 分析 JSON 解析

**Files:**
- Create: `lib/engine/yt_dlp_parser.dart`
- Test: `test/engine/yt_dlp_parser_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `AnalysisResult` / `VideoResult` / `PlaylistResult` / `VideoMeta` / `PlaylistMeta` / `PlaylistEntry`
- Produces:
  - `AnalysisResult parseAnalysisJson(String raw)` —— 解析 `--dump-single-json` 的输出，按 `_type` 返回 `VideoResult` 或 `PlaylistResult`
  - 解析容错：字段缺失返回 null/空串兜底，`title` 缺失时兜底为 `'未知标题'`；播放列表 `entries` 里取 `url ?? webpage_url`，`id` 取 `id ?? url`

- [ ] **Step 1: 写失败测试（fixture 内嵌，模拟真实 yt-dlp 输出结构）**

```dart
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

  test('missing title falls back to 未知标题', () {
    final result =
        parseAnalysisJson('{"_type":"video","id":"x","webpage_url":"u"}');
    expect((result as VideoResult).meta.title, '未知标题');
  });

  test('missing duration yields null', () {
    final result =
        parseAnalysisJson('{"_type":"video","id":"x","title":"t","webpage_url":"u"}');
    expect((result as VideoResult).meta.durationSec, isNull);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/yt_dlp_parser_test.dart`
Expected: FAIL（`yt_dlp_parser.dart` 不存在）

- [ ] **Step 3: 最小实现**

```dart
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
        .map((e) => PlaylistEntry(
              id: (_str(e, 'id') ?? _str(e, 'url') ?? '').trim(),
              title: _str(e, 'title') ?? _str(e, 'id') ?? '未知标题',
              url: (_str(e, 'url') ?? _str(e, 'webpage_url') ?? '').trim(),
              durationSec: _int(e, 'duration'),
            ))
        .toList();
    return PlaylistResult(
      PlaylistMeta(title: _str(map, 'title'), entries: entries),
    );
  }
  return VideoResult(
    VideoMeta(
      id: _str(map, 'id') ?? '',
      title: _str(map, 'title') ?? '未知标题',
      uploader: _str(map, 'uploader') ?? _str(map, 'channel'),
      durationSec: _int(map, 'duration'),
      thumbnailUrl: _str(map, 'thumbnail'),
      webUrl: _str(map, 'webpage_url') ?? _str(map, 'original_url') ?? '',
    ),
  );
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/yt_dlp_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/yt_dlp_parser.dart test/engine/yt_dlp_parser_test.dart
git commit -m "feat(engine): parse yt-dlp analysis json (video/playlist)"
```

---

### Task 4: YtDlpParser —— 进度行解析与错误映射

**Files:**
- Modify: `lib/engine/yt_dlp_parser.dart`（追加两个函数）
- Test: `test/engine/yt_dlp_parser_test.dart`（追加 group）

**Interfaces:**
- Consumes: Task 2 的 `DownloadProgress`
- Produces:
  - `DownloadProgress? parseProgressLine(String line)` —— 仅解析 `PROGRESS|` 前缀行（由 Task 8 的 `--progress-template` 生成），非进度行返回 null；`Unknown` 速度/ETA 返回 null
  - `String mapYtDlpError(String stderrTail)` —— 把 stderr 尾部映射为中文友好文案，五类：网络 / 视频不可用 / 地区限制 / 需要登录 / 兜底
  - `int? parseEtaSeconds(String text)` —— 解析 `HH:MM:SS` 或 `MM:SS`，`Unknown` 返回 null

- [ ] **Step 1: 追加失败测试**

在 `test/engine/yt_dlp_parser_test.dart` 的 `main()` 内、Task 3 既有测试之后追加以下 group（无需新增 import，Task 3 已有的整文件 import 已覆盖 `parseProgressLine`、`parseEtaSeconds`、`mapYtDlpError`）：

```dart
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

  group('mapYtDlpError', () {
    test('video unavailable', () {
      expect(
          mapYtDlpError(
              'ERROR: [youtube] abc: Video unavailable. This video is no longer available'),
          contains('不可用'));
    });
    test('network error', () {
      expect(
          mapYtDlpError(
              'ERROR: unable to download video data: HTTP Error 403: Forbidden'),
          contains('网络'));
    });
    test('geo restricted', () {
      expect(
          mapYtDlpError(
              'ERROR: [youtube] abc: This video is not available in your country.'),
          contains('地区'));
    });
    test('login required', () {
      expect(
          mapYtDlpError(
              'ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate for some users.'),
          contains('登录'));
    });
    test('fallback keeps last stderr line', () {
      final msg = mapYtDlpError(
          'ERROR: [bilibili] 123: something weird happened');
      expect(msg, contains('下载失败'));
      expect(msg, contains('something weird happened'));
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/yt_dlp_parser_test.dart`
Expected: FAIL（`parseProgressLine` 等未定义）

- [ ] **Step 3: 最小实现（追加到 `yt_dlp_parser.dart`）**

```dart
final _progressRe = RegExp(r'^PROGRESS\|([^|]*)\|([^|]*)\|([^|]*)');

DownloadProgress? parseProgressLine(String line) {
  final m = _progressRe.firstMatch(line.trim());
  if (m == null) return null;
  final pct = double.tryParse(m.group(1)!.replaceAll('%', '').trim()) ?? 0;
  final speedRaw = m.group(2)!.trim();
  final etaRaw = m.group(3)!.trim();
  return DownloadProgress(
    fraction: (pct / 100).clamp(0.0, 1.0),
    speed: speedRaw == 'Unknown' ? null : speedRaw,
    etaSeconds: parseEtaSeconds(etaRaw),
  );
}

int? parseEtaSeconds(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = parts.map((s) => int.tryParse(s.trim())).toList();
  if (nums.any((n) => n == null)) return null;
  var seconds = 0;
  for (final n in nums!) {
    seconds = seconds * 60 + n!;
  }
  return seconds;
}

String mapYtDlpError(String stderrTail) {
  final t = stderrTail.toLowerCase();
  if (t.contains('sign in') ||
      t.contains('confirm your age') ||
      t.contains('members') ||
      t.contains('join this channel')) {
    return '该视频需要登录或为会员/年龄限制内容，暂不支持下载';
  }
  if (t.contains('not available in your country') ||
      t.contains('geo-restricted') ||
      t.contains('geo restricted') ||
      t.contains('blocked it in your country')) {
    return '该视频在当前地区不可用';
  }
  if (t.contains('video unavailable') ||
      t.contains('removed by the uploader') ||
      t.contains('private video') ||
      t.contains('does not exist')) {
    return '视频不可用：可能已被删除或设为私密';
  }
  if (t.contains('timed out') ||
      t.contains('timeout') ||
      t.contains('unable to download') ||
      t.contains('connection') ||
      t.contains('getaddrinfo') ||
      t.contains('network')) {
    return '网络错误：请检查网络连接后重试';
  }
  final lastErrorLine = stderrTail
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .lastOrNull;
  return '下载失败：${lastErrorLine?.trim() ?? '未知错误'}';
}
```

注：`lastOrNull` 来自 `dart:collection`（Dart 3 已内置于 `Iterable` 扩展，无需额外 import；若分析器报错则 `import 'package:collection/collection.dart'` 并 `flutter pub add collection`）。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/yt_dlp_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/yt_dlp_parser.dart test/engine/yt_dlp_parser_test.dart
git commit -m "feat(engine): progress line parsing and error mapping"
```

---

### Task 5: EngineLocator —— 引擎路径解析

**Files:**
- Create: `lib/engine/engine_locator.dart`
- Test: `test/engine/engine_locator_test.dart`
- Modify: `pubspec.yaml`（若 Task 1 已添加 `path` 则跳过）

**Interfaces:**
- Consumes: Task 2 的 `EngineMissingException`
- Produces:
  - `class ResolvedEngine { final String ytDlpPath; final String? ffmpegPath; const ResolvedEngine({required this.ytDlpPath, this.ffmpegPath}); }`
  - `class EngineLocator { EngineLocator({String? baseDirOverride, EnvLookup? env}); ResolvedEngine resolve(); }`
  - `typedef EnvLookup = String? Function(String key);`
  - 解析规则（顺序）：`baseDirOverride`（测试注入）→ 环境变量 `YTDLP_ENGINE_DIR`（**直接指向含 yt-dlp.exe 的目录**，开发/集成测试用）→ 默认 `<exe目录>/data/flutter_assets/assets/bin`
  - `resolve()` 在 `yt-dlp.exe` 不存在时抛 `EngineMissingException(path)`；`ffmpeg.exe` 存在则填充 `ffmpegPath`，否则 null

- [ ] **Step 1: 写失败测试**

```dart
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
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/engine_locator_test.dart`
Expected: FAIL（`engine_locator.dart` 不存在）

- [ ] **Step 3: 最小实现**

```dart
// lib/engine/engine_locator.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/models.dart';

typedef EnvLookup = String? Function(String key);

String? _defaultEnv(String key) => Platform.environment[key];

class ResolvedEngine {
  const ResolvedEngine({required this.ytDlpPath, this.ffmpegPath});
  final String ytDlpPath;
  final String? ffmpegPath;
}

class EngineLocator {
  EngineLocator({this.baseDirOverride, EnvLookup? env})
      : env = env ?? _defaultEnv;

  final String? baseDirOverride;
  final EnvLookup env;

  ResolvedEngine resolve() {
    final envDir = env('YTDLP_ENGINE_DIR');
    final String engineDir;
    if (envDir != null && envDir.isNotEmpty) {
      engineDir = envDir;
    } else {
      final base = baseDirOverride ?? p.dirname(Platform.resolvedExecutable);
      engineDir = p.join(base, 'data', 'flutter_assets', 'assets', 'bin');
    }
    final ytDlpPath = p.join(engineDir, 'yt-dlp.exe');
    if (!File(ytDlpPath).existsSync()) {
      throw EngineMissingException(ytDlpPath);
    }
    final ffmpegPath = p.join(engineDir, 'ffmpeg.exe');
    return ResolvedEngine(
      ytDlpPath: ytDlpPath,
      ffmpegPath: File(ffmpegPath).existsSync() ? ffmpegPath : null,
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/engine_locator_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/engine_locator.dart test/engine/engine_locator_test.dart
git commit -m "feat(engine): locate bundled yt-dlp/ffmpeg binaries"
```

---

### Task 6: ProcessLauncher 抽象与系统实现

**Files:**
- Create: `lib/engine/process_launcher.dart`
- Test: `test/engine/process_launcher_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `abstract class AppProcess { Stream<String> get stdout; Stream<String> get stderr; Future<int> get exitCode; void kill(); }`（stdout/stderr 已按 UTF-8 + 按行切分）
  - `abstract class ProcessLauncher { Future<AppProcess> start(String executable, List<String> arguments, {Map<String, String>? environment}); }`
  - `class SystemProcessLauncher implements ProcessLauncher` —— 封装 `dart:io` 的 `Process.start`，stdout/stderr 经 `utf8.decoder` + `LineSplitter` 转为行流；`kill()` 调用进程的 `kill()`
  - Fake 实现由各任务测试文件内定义（`FakeAppProcess` / `FakeLauncher`）

- [ ] **Step 1: 写失败测试**

```dart
// test/engine/process_launcher_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/process_launcher.dart';

void main() {
  test('SystemProcessLauncher starts process and streams lines', () async {
    final launcher = SystemProcessLauncher();
    final proc = await launcher.start('cmd.exe', ['/c', 'echo', 'hello']);

    final lines = await proc.stdout.toList();
    expect(lines.first, 'hello');
    expect(await proc.exitCode, 0);
  });

  test('stderr is streamed as lines', () async {
    final launcher = SystemProcessLauncher();
    final proc =
        await launcher.start('cmd.exe', ['/c', 'echo', 'oops', '1>&2']);
    final lines = await proc.stderr.toList();
    expect(lines.first, 'oops');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/process_launcher_test.dart`
Expected: FAIL（`process_launcher.dart` 不存在）

- [ ] **Step 3: 最小实现**

```dart
// lib/engine/process_launcher.dart
import 'dart:convert';
import 'dart:io';

abstract class AppProcess {
  Stream<String> get stdout;
  Stream<String> get stderr;
  Future<int> get exitCode;
  void kill();
}

abstract class ProcessLauncher {
  Future<AppProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });
}

class SystemProcessLauncher implements ProcessLauncher {
  const SystemProcessLauncher();

  @override
  Future<AppProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final proc = await Process.start(
      executable,
      arguments,
      environment: environment,
      mode: ProcessStartMode.normal,
    );
    return _SystemAppProcess(proc);
  }
}

class _SystemAppProcess implements AppProcess {
  _SystemAppProcess(Process proc)
      : stdout = proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        stderr = proc.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        _exitCode = proc.exitCode,
        _proc = proc;

  final Process _proc;
  final Future<int> _exitCode;

  @override
  final Stream<String> stdout;

  @override
  final Stream<String> stderr;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  void kill() {
    _proc.kill();
  }
}
```

注：Windows 上 `cmd.exe` 输出为本地码页，本测试仅用 ASCII 内容；yt-dlp 侧通过 `PYTHONIOENCODING=utf-8`（Task 7/8 传入）保证 UTF-8 输出正确解码。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/process_launcher_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/process_launcher.dart test/engine/process_launcher_test.dart
git commit -m "feat(engine): process launcher abstraction over dart:io"
```

---

### Task 7: YtDlpService.probe —— 元数据探测

**Files:**
- Create: `lib/engine/yt_dlp_service.dart`
- Test: `test/engine/yt_dlp_service_test.dart`

**Interfaces:**
- Consumes:
  - Task 5 `EngineLocator.resolve()` → `ResolvedEngine`
  - Task 6 `ProcessLauncher.start(...)` → `AppProcess`
  - Task 3 `parseAnalysisJson`
  - Task 2 `DownloadException`
- Produces:
  - `class YtDlpService { YtDlpService({ProcessLauncher? launcher, EngineLocator? locator, Duration probeTimeout = const Duration(seconds: 60)}); Future<AnalysisResult> probe(String url); }`
  - probe 执行 `yt-dlp --dump-single-json --flat-playlist --no-warnings <url>`，环境变量含 `PYTHONIOENCODING=utf-8`
  - 超时：kill 进程并抛 `DownloadException('分析超时：请检查网络连接或链接是否有效')`
  - 退出码非 0：抛 `DownloadException(mapYtDlpError(stderr), stderr全文)`
  - 测试内 Fake 约定：`FakeAppProcess({required Stream<String> stdout, Stream<String> stderr = ..., Future<int> exitCode})`；`FakeLauncher(AppProcess)` 记录 `lastArgs`/`startCount`

- [ ] **Step 1: 写失败测试**

```dart
// test/engine/yt_dlp_service_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/process_launcher.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';

class FakeAppProcess implements AppProcess {
  FakeAppProcess({
    required this.stdout,
    this.stderr = const Stream.empty(),
    Future<int>? exitCode,
  }) : _exitCode = exitCode ?? Future.value(0);
  @override
  final Stream<String> stdout;
  @override
  final Stream<String> stderr;
  final Future<int> _exitCode;
  bool killed = false;
  @override
  Future<int> get exitCode => _exitCode;
  @override
  void kill() => killed = true;
}

class FakeLauncher implements ProcessLauncher {
  FakeLauncher(this.process);
  final AppProcess process;
  var startCount = 0;
  List<String> lastArgs = const [];
  Map<String, String>? lastEnv;
  @override
  Future<AppProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    startCount++;
    lastArgs = arguments;
    lastEnv = environment;
    return process;
  }
}

EngineLocator _stubLocator(Directory dir) {
  final bin = p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
  Directory(bin).createSync(recursive: true);
  File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('');
  return EngineLocator(baseDirOverride: dir.path);
}

const _videoJson =
    '{"_type":"video","id":"v1","title":"T","webpage_url":"https://e/v"}';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('svc_test'));
  tearDown(() async => temp.delete(recursive: true));

  test('probe returns VideoResult and passes expected args', () async {
    final launcher = FakeLauncher(
        FakeAppProcess(stdout: Stream.value(_videoJson)));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    final result = await service.probe('https://example.com/v');

    expect(result, isA<VideoResult>());
    expect((result as VideoResult).meta.title, 'T');
    expect(launcher.startCount, 1);
    expect(launcher.lastArgs,
        containsAllInOrder(['--dump-single-json', '--flat-playlist']));
    expect(launcher.lastArgs.last, 'https://example.com/v');
    expect(launcher.lastEnv, containsPair('PYTHONIOENCODING', 'utf-8'));
  });

  test('probe parses playlist', () async {
    final json =
        '{"_type":"playlist","title":"PL","entries":[{"id":"a","title":"A","url":"u1"}]}';
    final launcher =
        FakeLauncher(FakeAppProcess(stdout: Stream.value(json)));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    final result = await service.probe('https://example.com/pl');
    expect((result as PlaylistResult).meta.entries.single.url, 'u1');
  });

  test('non-zero exit maps stderr to friendly error', () async {
    final launcher = FakeLauncher(FakeAppProcess(
      stdout: const Stream.empty(),
      stderr: Stream.value(
          'ERROR: [youtube] abc: Video unavailable. This video is no longer available'),
      exitCode: Future.value(1),
    ));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    await expectLater(
      service.probe('https://example.com/v'),
      throwsA(isA<DownloadException>()
          .having((e) => e.friendlyMessage, 'friendly', contains('不可用'))),
    );
  });

  test('probe timeout kills process and throws friendly error', () async {
    final never = Completer<int>();
    final proc = FakeAppProcess(
        stdout: const Stream.empty(), exitCode: never.future);
    final launcher = FakeLauncher(proc);
    final service = YtDlpService(
      launcher: launcher,
      locator: _stubLocator(temp),
      probeTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      service.probe('https://example.com/v'),
      throwsA(isA<DownloadException>()
          .having((e) => e.friendlyMessage, 'friendly', contains('超时'))),
    );
    expect(proc.killed, isTrue);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/yt_dlp_service_test.dart`
Expected: FAIL（`yt_dlp_service.dart` 不存在）

- [ ] **Step 3: 最小实现**

```dart
// lib/engine/yt_dlp_service.dart
import 'dart:async';

import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/process_launcher.dart';
import 'package:video_downloader/engine/yt_dlp_parser.dart';

class YtDlpService {
  YtDlpService({
    ProcessLauncher? launcher,
    EngineLocator? locator,
    this.probeTimeout = const Duration(seconds: 60),
  })  : launcher = launcher ?? const SystemProcessLauncher(),
        locator = locator ?? EngineLocator();

  final ProcessLauncher launcher;
  final EngineLocator locator;
  final Duration probeTimeout;

  Future<AnalysisResult> probe(String url) async {
    final engine = locator.resolve();
    final proc = await launcher.start(
      engine.ytDlpPath,
      ['--dump-single-json', '--flat-playlist', '--no-warnings', url],
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final subs = <StreamSubscription<String>>[
      proc.stdout.listen(stdoutBuf.write),
      proc.stderr.listen(stderrBuf.write),
    ];
    int code;
    try {
      code = await proc.exitCode.timeout(probeTimeout);
    } on TimeoutException {
      proc.kill();
      await subs.cancel();
      throw const DownloadException('分析超时：请检查网络连接或链接是否有效');
    }
    await subs.cancel();
    if (code != 0) {
      throw DownloadException(
        mapYtDlpError(stderrBuf.toString()),
        stderrBuf.toString(),
      );
    }
    return parseAnalysisJson(stdoutBuf.toString());
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/yt_dlp_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```powershell
git add lib/engine/yt_dlp_service.dart test/engine/yt_dlp_service_test.dart
git commit -m "feat(engine): probe url metadata via yt-dlp process"
```

---

### Task 8: YtDlpService.download —— 流式下载与进度回调

**Files:**
- Modify: `lib/engine/yt_dlp_service.dart`（追加 download 方法与参数构造）
- Test: `test/engine/yt_dlp_service_test.dart`（追加 group）

**Interfaces:**
- Consumes: Task 2 `DownloadRequest` / `DownloadProgress`；Task 4 `parseProgressLine`；Task 7 的 Fake 基础设施
- Produces:
  - `Future<String> download(DownloadRequest request, {void Function(DownloadProgress)? onProgress})` —— 返回最终文件路径（来自 `--print after_move:filepath` 行）
  - 下载参数（顺序无关断言用 `containsAllInOrder` 校验关键项）：`-f <selector>`、`--merge-output-format mp4`、`--newline`、`--progress`、`--no-simulate`、`--progress-template download:PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s`、`--print after_move:filepath`、`--no-warnings`、`-o <outputDir>/%(title)s.%(ext)s`、`--ffmpeg-location <ffmpegPath>`（仅当 request.ffmpegPath 非 null）、URL 在最后
  - **关键**：`--print` 默认隐含 `--quiet --simulate`，必须显式加 `--progress --no-simulate`，否则不下载也不出进度
  - stdout 行分类：`PROGRESS|` 行 → 进度回调；以 `[` 开头或空行 → 忽略；其余非空行 → 记为最终文件路径
  - 退出码非 0 → `DownloadException(mapYtDlpError(...), stderr全文)`；路径未捕获 → `DownloadException('下载完成但未能定位输出文件')`

- [ ] **Step 1: 追加失败测试**

```dart
// test/engine/yt_dlp_service_test.dart —— main() 内追加 group

  group('download', () {
    test('emits progress and returns final filepath', () async {
      final launcher = FakeLauncher(FakeAppProcess(stdout: Stream.fromIterable([
        '[download] Destination: D:\\dl\\Sample.mp4',
        'PROGRESS| 10.0%| 1.00MiB/s| 00:10',
        'PROGRESS| 50.0%| 2.00MiB/s| 00:05',
        'D:\\dl\\Sample.mp4',
      ])));
      final service = YtDlpService(
          launcher: launcher, locator: _stubLocator(temp));
      final seen = <DownloadProgress>[];

      final path = await service.download(
        DownloadRequest(
          url: 'https://example.com/v',
          preset: QualityPreset.p720,
          outputDir: 'D:\\dl',
          ffmpegPath: 'C:\\bin\\ffmpeg.exe',
        ),
        onProgress: seen.add,
      );

      expect(seen.map((e) => e.fraction), [0.10, 0.50]);
      expect(path, 'D:\\dl\\Sample.mp4');
      expect(launcher.lastArgs,
          containsAllInOrder(['-f', QualityPreset.p720.formatSelector]));
      expect(launcher.lastArgs, containsAllInOrder(['--merge-output-format', 'mp4']));
      expect(launcher.lastArgs, containsAllInOrder(['--ffmpeg-location', 'C:\\bin\\ffmpeg.exe']));
      expect(launcher.lastArgs, contains('--no-simulate'));
      expect(launcher.lastArgs, contains('--progress'));
      expect(
          launcher.lastArgs,
          containsAllInOrder([
            '--progress-template',
            'download:PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s'
          ]));
      expect(launcher.lastArgs, contains('-o'));
      expect(launcher.lastArgs.last, 'https://example.com/v');
    });

    test('already-downloaded log line is not treated as filepath', () async {
      final launcher = FakeLauncher(FakeAppProcess(stdout: Stream.fromIterable([
        '[download] Sample.mp4 has already been downloaded',
        'D:\\dl\\Sample.mp4',
      ])));
      final service = YtDlpService(
          launcher: launcher, locator: _stubLocator(temp));

      final path = await service.download(DownloadRequest(
          url: 'https://example.com/v',
          preset: QualityPreset.best,
          outputDir: 'D:\\dl'));
      expect(path, 'D:\\dl\\Sample.mp4');
    });

    test('failure maps stderr to friendly exception', () async {
      final launcher = FakeLauncher(FakeAppProcess(
        stdout: const Stream.empty(),
        stderr: Stream.value(
            'ERROR: [youtube] abc: Sign in to confirm your age'),
        exitCode: Future.value(1),
      ));
      final service = YtDlpService(
          launcher: launcher, locator: _stubLocator(temp));

      await expectLater(
        service.download(DownloadRequest(
            url: 'https://example.com/v',
            preset: QualityPreset.best,
            outputDir: 'D:\\dl')),
        throwsA(isA<DownloadException>()
            .having((e) => e.friendlyMessage, 'friendly', contains('登录'))),
      );
    });
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine/yt_dlp_service_test.dart`
Expected: FAIL（`download` 方法未定义）

- [ ] **Step 3: 实现（追加到 `yt_dlp_service.dart`）**

在文件顶部补 `import 'package:path/path.dart' as p;`，类内追加：

```dart
  List<String> _buildDownloadArgs(DownloadRequest request, ResolvedEngine engine) {
    return [
      '-f', request.preset.formatSelector,
      '--merge-output-format', 'mp4',
      '--newline',
      '--progress',
      '--no-simulate',
      '--progress-template',
      'download:PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
      '--no-warnings',
      '--print', 'after_move:filepath',
      '-o', p.join(request.outputDir, '%(title)s.%(ext)s'),
      if (request.ffmpegPath != null)
        ...['--ffmpeg-location', request.ffmpegPath!],
      request.url,
    ];
  }

  Future<String> download(
    DownloadRequest request, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final engine = locator.resolve();
    final proc = await launcher.start(
      engine.ytDlpPath,
      _buildDownloadArgs(request, engine),
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    String? filePath;
    final stderrBuf = StringBuffer();
    final subs = <StreamSubscription<String>>[
      proc.stdout.listen((line) {
        final progress = parseProgressLine(line);
        if (progress != null) {
          onProgress?.call(progress);
          return;
        }
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('[')) return;
        filePath = trimmed;
      }),
      proc.stderr.listen(stderrBuf.writeln),
    ];
    final code = await proc.exitCode;
    await subs.cancel();
    if (code != 0) {
      throw DownloadException(
        mapYtDlpError(stderrBuf.toString()),
        stderrBuf.toString(),
      );
    }
    final path = filePath;
    if (path == null || path.isEmpty) {
      throw const DownloadException('下载完成但未能定位输出文件');
    }
    return path;
  }
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/engine/yt_dlp_service_test.dart`
Expected: PASS（含 Task 7 全部用例）

- [ ] **Step 5: 全量回归 + 提交**

```powershell
flutter test
git add lib/engine/yt_dlp_service.dart test/engine/yt_dlp_service_test.dart
git commit -m "feat(engine): stream download with progress and friendly errors"
```

---

### Task 9: 引擎捆绑脚本与资产声明

**Files:**
- Create: `tool/fetch_engine.ps1`
- Modify: `pubspec.yaml`（assets 声明）、`.gitignore`（忽略二进制）
- Create（脚本产物，不入 git）: `assets/bin/yt-dlp.exe`、`assets/bin/ffmpeg.exe`、`assets/bin/ffprobe.exe`

**Interfaces:**
- Consumes: 无
- Produces: `assets/bin/` 下三个引擎文件；pubspec 声明 `- assets/bin/`；`EngineLocator` 默认路径从此目录命中（Task 10 的真实运行依赖本任务）

- [ ] **Step 1: 写脚本**

```powershell
# tool/fetch_engine.ps1 —— 下载 yt-dlp 与 FFmpeg 到 assets/bin/
$ErrorActionPreference = 'Stop'
$binDir = Join-Path $PSScriptRoot '..\assets\bin'
$binDir = [System.IO.Path]::GetFullPath($binDir)
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

Write-Host 'Downloading yt-dlp.exe ...'
$ytUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
Invoke-WebRequest -Uri $ytUrl -OutFile (Join-Path $binDir 'yt-dlp.exe')

Write-Host 'Downloading FFmpeg essentials ...'
$tmp = Join-Path $env:TEMP ("ffmpeg_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'ffmpeg.zip'
Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $tmp -Force
Copy-Item (Get-ChildItem $tmp -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1).FullName (Join-Path $binDir 'ffmpeg.exe')
Copy-Item (Get-ChildItem $tmp -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1).FullName (Join-Path $binDir 'ffprobe.exe')
Remove-Item -Recurse -Force $tmp

Write-Host "Engine files ready in $binDir"
& (Join-Path $binDir 'yt-dlp.exe') --version
& (Join-Path $binDir 'ffmpeg.exe') -version | Select-Object -First 1
```

- [ ] **Step 2: 运行脚本并验证产物**

```powershell
powershell -ExecutionPolicy Bypass -File tool\fetch_engine.ps1
Get-ChildItem assets\bin   # 预期：yt-dlp.exe、ffmpeg.exe、ffprobe.exe 三个文件
```

Expected: 脚本末尾打印 yt-dlp 版本号（如 `2026.xx.xx`）与 ffmpeg 版本行

- [ ] **Step 3: 声明资产并忽略二进制**

`pubspec.yaml` 的 `flutter:` 段追加：

```yaml
  assets:
    - assets/bin/
```

`.gitignore` 追加：

```
# engine binaries (fetched by tool/fetch_engine.ps1)
assets/bin/*.exe
```

- [ ] **Step 4: 验证工程仍健康**

```powershell
flutter analyze
flutter test
git status   # 预期：assets/bin 下的 .exe 不出现在待提交列表
```

Expected: 均通过，无 exe 入库

- [ ] **Step 5: 提交**

```powershell
git add tool/fetch_engine.ps1 pubspec.yaml .gitignore
git commit -m "build: bundle yt-dlp/ffmpeg engine via fetch script"
```

---

### Task 10: 极简 UI 端到端

**Files:**
- Modify: `lib/main.dart`（整页替换）
- Test: `test/ui/download_page_test.dart`

**Interfaces:**
- Consumes:
  - Task 7/8 `YtDlpService().probe/download`
  - Task 5 `EngineLocator().resolve()` → `ffmpegPath`
  - Task 2 `QualityPreset.best`、`VideoResult`/`PlaylistResult`、`DownloadException`、`EngineMissingException`
  - `path_provider` 的 `getDownloadsDirectory()`
- Produces: M1 可交付应用——输入 URL → 下载 → 进度条 → 完成路径。页面构造函数提供测试注入点：`DownloadPage({super.key, YtDlpService? service, Future<String> Function()? downloadsDir})`

- [ ] **Step 1: 写失败测试**

```dart
// test/ui/download_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';
import 'package:video_downloader/main.dart';

class _FakeService extends YtDlpService {
  @override
  Future<AnalysisResult> probe(String url) async =>
      VideoResult(const VideoMeta(id: '1', title: '测试视频', webUrl: url));

  @override
  Future<String> download(DownloadRequest request,
      {void Function(DownloadProgress)? onProgress}) async {
    onProgress?.call(const DownloadProgress(fraction: 0.5, speed: '1MiB/s'));
    return r'C:\tmp\测试视频.mp4';
  }
}

void main() {
  // 注意：fake 的 Future 立即完成，一次 pump 后中间态（分析中/下载中）不可见，
  // 因此只断言终态；进度条仅下载中渲染，避免 pumpAndSettle 挂起。
  testWidgets('downloads video and shows final path', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DownloadPage(
            service: _FakeService(), downloadsDir: () async => r'C:\tmp')));

    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/v');
    await tester.tap(find.byKey(const Key('download_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('完成'), findsOneWidget);
    expect(find.textContaining(r'C:\tmp\测试视频.mp4'), findsOneWidget);
  });

  testWidgets('playlist url shows friendly notice', (tester) async {
    final svc = _PlaylistFake();
    await tester.pumpWidget(MaterialApp(
        home: DownloadPage(service: svc, downloadsDir: () async => r'C:\tmp')));
    await tester.enterText(
        find.byKey(const Key('url_field')), 'https://example.com/pl');
    await tester.tap(find.byKey(const Key('download_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('批量下载将在下个版本提供'), findsOneWidget);
  });
}

class _PlaylistFake extends YtDlpService {
  @override
  Future<AnalysisResult> probe(String url) async => PlaylistResult(
        const PlaylistMeta(
            title: 'PL',
            entries: [PlaylistEntry(id: 'a', title: 'A', url: 'u1')]),
      );
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/download_page_test.dart`
Expected: FAIL（`DownloadPage` 不存在）

- [ ] **Step 3: 实现 UI（替换 `lib/main.dart`）**

```dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/yt_dlp_service.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Downloader',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DownloadPage(),
    );
  }
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, this.service, this.downloadsDir});

  final YtDlpService? service;
  final Future<String> Function()? downloadsDir;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  DownloadProgress? _progress;
  String _status = '粘贴视频链接，点击开始下载';

  Future<String> _resolveDownloadsDir() async {
    final injected = widget.downloadsDir;
    if (injected != null) return injected();
    return (await getDownloadsDirectory())?.path ?? Directory.systemTemp.path;
  }

  Future<void> _start() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _progress = null;
      _status = '分析中...';
    });
    final service = widget.service ?? YtDlpService();
    try {
      final result = await service.probe(url);
      if (result is PlaylistResult) {
        final n = result.meta.entries.length;
        setState(() => _status =
            '检测到播放列表「${result.meta.title ?? ''}」，共 $n 个条目；批量下载将在下个版本提供');
        return;
      }
      final video = (result as VideoResult).meta;
      setState(() => _status = '下载中：${video.title}');
      final dir = await _resolveDownloadsDir();
      final engine = EngineLocator().resolve();
      final path = await service.download(
        DownloadRequest(
          url: url,
          preset: QualityPreset.best,
          outputDir: dir,
          ffmpegPath: engine.ffmpegPath,
        ),
        onProgress: (p) => setState(() => _progress = p),
      );
      setState(() {
        _status = '完成：$path';
        _progress = null;
      });
    } on DownloadException catch (e) {
      setState(() => _status = e.friendlyMessage);
    } on EngineMissingException catch (e) {
      setState(() => _status = '未找到下载引擎：${e.path}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Downloader (M1)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('url_field'),
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: '视频链接',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('download_button'),
              onPressed: _busy ? null : _start,
              child: Text(_busy ? '处理中...' : '开始下载'),
            ),
            const SizedBox(height: 16),
            // 仅在下载中渲染：空闲时的不确定动画会让 widget 测试 pumpAndSettle 永不结束
            if (_busy) LinearProgressIndicator(value: _progress?.fraction, minHeight: 6),
            const SizedBox(height: 8),
            if (_progress?.speed != null)
              Text('速度 ${_progress!.speed} · 剩余 ${_progress!.etaSeconds ?? '?'} 秒'),
            const SizedBox(height: 8),
            Text(_status),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }
}
```

注：`Directory` 来自 `dart:io`，文件顶部补 `import 'dart:io';`。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/download_page_test.dart`
Expected: PASS

- [ ] **Step 5: 全量回归**

```powershell
flutter analyze
flutter test
```

Expected: 无问题、全部通过

- [ ] **Step 6: 真实端到端冒烟（手动清单）**

```powershell
flutter run -d windows
```

1. 粘贴一个短视频 URL（如 YouTube/Bilibili 短片）→ 状态变"下载中"，进度条实时推进
2. 完成后"完成：<路径>"，打开系统"下载"文件夹确认 mp4 存在且可播放
3. 再次粘贴同一 URL → 秒完成（yt-dlp 跳过已下载）且不报错
4. 粘贴无效 URL → 显示友好错误而非堆栈
5. 观察任务栏：**无黑色控制台窗口闪现**（设计验证项，若出现需在 Task 6 的 `Process.start` 上排查 `ProcessStartMode`）
6. 任选一个需要登录/不可用的视频 → 显示对应的友好提示文案

- [ ] **Step 7: 提交**

```powershell
git add lib/main.dart test/ui/download_page_test.dart
git commit -m "feat(ui): minimal single-video download page (M1 complete)"
```

---

## 后续计划

- **Plan 2 (M2)**：fluent_ui 主框架、任务队列与并发、取消、Riverpod 接入
- **Plan 3 (M3)**：播放列表批量 UI、drift 历史持久化、设置页、intl 双语
- **Plan 4 (M4)**：引擎自动更新与自愈下载、错误打磨、免责声明、msix 打包
