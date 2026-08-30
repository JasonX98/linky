import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/download_task.dart';

DownloadTask _t(TaskStatus status) => DownloadTask(
    id: 't0',
    url: 'u',
    title: '标题',
    preset: QualityPreset.best,
    status: status);

void main() {
  test('isActive covers queued/downloading/canceling only', () {
    expect(_t(TaskStatus.queued).isActive, isTrue);
    expect(_t(TaskStatus.downloading).isActive, isTrue);
    expect(_t(TaskStatus.canceling).isActive, isTrue);
    expect(_t(TaskStatus.completed).isActive, isFalse);
    expect(_t(TaskStatus.failed).isActive, isFalse);
    expect(_t(TaskStatus.canceled).isActive, isFalse);
  });

  test('copyWith patches fields and clears nullables', () {
    const progress = DownloadProgress(fraction: 0.5);
    final t = _t(TaskStatus.downloading)
        .copyWith(progress: progress, filePath: 'D:\\x.mp4');
    expect(t.progress, same(progress));
    expect(t.filePath, 'D:\\x.mp4');

    final reset = t.copyWith(
        status: TaskStatus.queued,
        clearProgress: true,
        clearFilePath: true,
        clearError: true);
    expect(reset.status, TaskStatus.queued);
    expect(reset.progress, isNull);
    expect(reset.filePath, isNull);
    expect(reset.errorKind, isNull);
    expect(reset.errorDetail, isNull);
    expect(reset.id, 't0');
  });

  test('copyWith without clear keeps existing values', () {
    final t = _t(TaskStatus.downloading).copyWith(filePath: 'D:\\x.mp4');
    final again = t.copyWith(status: TaskStatus.completed);
    expect(again.filePath, 'D:\\x.mp4');
    expect(again.status, TaskStatus.completed);
  });
}
