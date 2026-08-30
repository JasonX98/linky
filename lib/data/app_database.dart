// lib/data/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class DownloadHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get uploader => text().nullable()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get formatLabel => text()();
  TextColumn get filePath => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get errorSummary => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [DownloadHistoryEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

Future<File> databaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}history.sqlite');
}

AppDatabase openAppDatabase() {
  return AppDatabase(
      LazyDatabase(() async => NativeDatabase(await databaseFile())));
}
