// test/data/history_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';

void main() {
  late AppDatabase db;
  late HistoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HistoryRepository(db);
  });

  tearDown(() async => db.close());

  test('record + recentEntries round-trips fields', () async {
    await repo.record(
      url: 'https://example.com/v',
      title: '测试视频',
      uploader: 'UP主',
      durationSec: 61,
      formatLabel: 'best',
      filePath: r'D:\dl\测试视频.mp4',
      status: 'completed',
      completedAt: DateTime(2026, 1, 2, 3, 4),
    );

    final rows = await repo.recentEntries();
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.url, 'https://example.com/v');
    expect(r.title, '测试视频');
    expect(r.uploader, 'UP主');
    expect(r.durationSec, 61);
    expect(r.formatLabel, 'best');
    expect(r.filePath, r'D:\dl\测试视频.mp4');
    expect(r.status, 'completed');
    expect(r.createdAt, DateTime(2026, 1, 2, 3, 4));
  });

  test('failed row keeps errorDetail; nullable fields stay null', () async {
    await repo.record(
        url: 'u',
        title: 't',
        formatLabel: 'p720',
        status: 'failed',
        errorDetail: '视频不可用：可能已被删除或设为私密');
    final r = await repo.recentEntries();
    expect(r.single.status, 'failed');
    expect(r.single.errorSummary, '视频不可用：可能已被删除或设为私密');
    expect(r.single.filePath, isNull);
    expect(r.single.completedAt, isNull);
  });

  test('recentEntries orders by createdAt desc', () async {
    await repo.record(url: 'u1', title: '旧', formatLabel: 'best', status: 'completed', completedAt: DateTime(2026, 1, 1));
    await repo.record(url: 'u2', title: '新', formatLabel: 'best', status: 'completed', completedAt: DateTime(2026, 1, 2));
    final rows = await repo.recentEntries();
    expect(rows.first.title, '新');
    expect(rows.last.title, '旧');
  });

  test('equal createdAt tie-breaks by id desc in recent and watch', () async {
    await repo.record(url: 'u1', title: '先', formatLabel: 'best', status: 'completed', completedAt: DateTime(2026, 1, 1));
    await repo.record(url: 'u2', title: '后', formatLabel: 'best', status: 'completed', completedAt: DateTime(2026, 1, 1));
    // createdAt 秒级精度相同 → 必须按 id 倒排保证稳定顺序（后插入在前）
    final recent = await repo.recentEntries();
    expect(recent.first.title, '后');
    expect(recent.last.title, '先');
    final watched = await repo.watchRecent().first;
    expect(watched.first.title, '后');
    expect(watched.last.title, '先');
  });

  test('watchRecent emits on insert and deleteById removes', () async {
    await repo.record(url: 'u', title: 't', formatLabel: 'best', status: 'completed');
    final first = await repo.watchRecent().first;
    expect(first, hasLength(1));

    await repo.deleteById(first.single.id);
    expect(await repo.recentEntries(), isEmpty);
  });

  test('removeAll clears everything', () async {
    await repo.record(url: 'u1', title: 'a', formatLabel: 'best', status: 'completed');
    await repo.record(url: 'u2', title: 'b', formatLabel: 'best', status: 'failed');
    await repo.removeAll();
    expect(await repo.recentEntries(), isEmpty);
  });
}
