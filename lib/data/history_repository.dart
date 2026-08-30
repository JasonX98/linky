// lib/data/history_repository.dart
import 'package:drift/drift.dart';
import 'package:video_downloader/data/app_database.dart';

class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  Future<void> record({
    required String url,
    required String title,
    String? uploader,
    int? durationSec,
    required String formatLabel,
    String? filePath,
    int? fileSize,
    required String status,
    String? errorDetail,
    DateTime? completedAt,
  }) {
    return _db
        .into(_db.downloadHistoryEntries)
        .insert(DownloadHistoryEntriesCompanion.insert(
          url: url,
          title: title,
          formatLabel: formatLabel,
          status: status,
          createdAt: completedAt ?? DateTime.now(),
          uploader: Value(uploader),
          durationSec: Value(durationSec),
          filePath: Value(filePath),
          fileSize: Value(fileSize),
          errorSummary: Value(errorDetail),
          completedAt: Value(completedAt),
        ));
  }

  Future<List<DownloadHistoryEntry>> recentEntries({int limit = 200}) {
    return (_db.select(_db.downloadHistoryEntries)
          ..orderBy([
            (u) => OrderingTerm.desc(u.createdAt),
            // createdAt 秒级精度，同秒并列时按 id 倒排保证稳定顺序
            (u) => OrderingTerm.desc(u.id),
          ])
          ..limit(limit))
        .get();
  }

  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) {
    return (_db.select(_db.downloadHistoryEntries)
          ..orderBy([
            (u) => OrderingTerm.desc(u.createdAt),
            (u) => OrderingTerm.desc(u.id),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.downloadHistoryEntries)
          ..where((u) => u.id.equals(id)))
        .go();
  }

  Future<int> removeAll() {
    return _db.delete(_db.downloadHistoryEntries).go();
  }
}
