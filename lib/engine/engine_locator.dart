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
    final String engineDir;
    final base = baseDirOverride;
    if (base != null) {
      engineDir = p.join(base, 'data', 'flutter_assets', 'assets', 'bin');
    } else {
      final envDir = env('YTDLP_ENGINE_DIR');
      if (envDir != null && envDir.isNotEmpty) {
        engineDir = envDir;
      } else {
        engineDir = p.join(
          p.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          'assets',
          'bin',
        );
      }
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
