// lib/features/download/analysis_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/providers.dart';

sealed class AnalysisState {
  const AnalysisState();
}

class AnalysisIdle extends AnalysisState {
  const AnalysisIdle();
}

class AnalysisLoading extends AnalysisState {
  const AnalysisLoading();
}

class AnalysisVideo extends AnalysisState {
  const AnalysisVideo(this.meta);
  final VideoMeta meta;
}

class AnalysisPlaylist extends AnalysisState {
  const AnalysisPlaylist(this.meta);
  final PlaylistMeta meta;
}

class AnalysisError extends AnalysisState {
  const AnalysisError(this.message, {this.kind = EngineErrorKind.unknown});
  final String message;
  final EngineErrorKind kind;
}

class AnalysisController extends Notifier<AnalysisState> {
  @override
  AnalysisState build() {
    ref.watch(ytDlpServiceProvider);
    return const AnalysisIdle();
  }

  Future<void> analyze(String url) async {
    state = const AnalysisLoading();
    try {
      final cookieFile = ref.read(settingsProvider).cookieFile;
      final result = await ref
          .read(ytDlpServiceProvider)
          .probe(url, cookieFile: cookieFile);
      state = switch (result) {
        VideoResult(:final meta) => AnalysisVideo(meta),
        PlaylistResult(:final meta) => AnalysisPlaylist(meta),
      };
    } on DownloadException catch (e) {
      // message 暂存 detail，UI 按 kind 本地化渲染
      state = AnalysisError(e.detail, kind: e.kind);
    } catch (e) {
      // 非预期异常无结构化 detail：原始 toString 作 detail，kind 归 unknown。
      // UI 经 displayError/ErrorMessage 渲染——core 恒为友好文案，raw 仅作副行。
      state = AnalysisError(e.toString());
    }
  }

  void reset() => state = const AnalysisIdle();
}
