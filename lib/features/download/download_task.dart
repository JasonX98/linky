import 'package:video_downloader/engine/models.dart';

enum TaskStatus { queued, downloading, canceling, completed, failed, canceled }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.preset,
    required this.status,
    this.progress,
    this.filePath,
    this.errorKind,
    this.errorDetail,
    this.uploader,
    this.durationSec,
  });

  final String id;
  final String url;
  final String title;
  final QualityPreset preset;
  final TaskStatus status;
  final DownloadProgress? progress;
  final String? filePath;
  final EngineErrorKind? errorKind;
  final String? errorDetail;
  final String? uploader;
  final int? durationSec;

  bool get isActive =>
      status == TaskStatus.queued ||
      status == TaskStatus.downloading ||
      status == TaskStatus.canceling;

  DownloadTask copyWith({
    TaskStatus? status,
    DownloadProgress? progress,
    bool clearProgress = false,
    String? filePath,
    bool clearFilePath = false,
    EngineErrorKind? errorKind,
    String? errorDetail,
    bool clearError = false,
    String? uploader,
    int? durationSec,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title,
      preset: preset,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      uploader: uploader ?? this.uploader,
      durationSec: durationSec ?? this.durationSec,
    );
  }
}
