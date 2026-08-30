// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DownloadHistoryEntriesTable extends DownloadHistoryEntries
    with TableInfo<$DownloadHistoryEntriesTable, DownloadHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploaderMeta = const VerificationMeta(
    'uploader',
  );
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
    'uploader',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatLabelMeta = const VerificationMeta(
    'formatLabel',
  );
  @override
  late final GeneratedColumn<String> formatLabel = GeneratedColumn<String>(
    'format_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorSummaryMeta = const VerificationMeta(
    'errorSummary',
  );
  @override
  late final GeneratedColumn<String> errorSummary = GeneratedColumn<String>(
    'error_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    title,
    uploader,
    durationSec,
    formatLabel,
    filePath,
    fileSize,
    status,
    errorSummary,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('uploader')) {
      context.handle(
        _uploaderMeta,
        uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('format_label')) {
      context.handle(
        _formatLabelMeta,
        formatLabel.isAcceptableOrUnknown(
          data['format_label']!,
          _formatLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatLabelMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_summary')) {
      context.handle(
        _errorSummaryMeta,
        errorSummary.isAcceptableOrUnknown(
          data['error_summary']!,
          _errorSummaryMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      uploader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uploader'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      formatLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_label'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_summary'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadHistoryEntriesTable createAlias(String alias) {
    return $DownloadHistoryEntriesTable(attachedDatabase, alias);
  }
}

class DownloadHistoryEntry extends DataClass
    implements Insertable<DownloadHistoryEntry> {
  final int id;
  final String url;
  final String title;
  final String? uploader;
  final int? durationSec;
  final String formatLabel;
  final String? filePath;
  final int? fileSize;
  final String status;
  final String? errorSummary;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadHistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    this.uploader,
    this.durationSec,
    required this.formatLabel,
    this.filePath,
    this.fileSize,
    required this.status,
    this.errorSummary,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    map['format_label'] = Variable<String>(formatLabel);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorSummary != null) {
      map['error_summary'] = Variable<String>(errorSummary);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DownloadHistoryEntriesCompanion(
      id: Value(id),
      url: Value(url),
      title: Value(title),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      formatLabel: Value(formatLabel),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      status: Value(status),
      errorSummary: errorSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(errorSummary),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String>(json['title']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      formatLabel: serializer.fromJson<String>(json['formatLabel']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      status: serializer.fromJson<String>(json['status']),
      errorSummary: serializer.fromJson<String?>(json['errorSummary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String>(title),
      'uploader': serializer.toJson<String?>(uploader),
      'durationSec': serializer.toJson<int?>(durationSec),
      'formatLabel': serializer.toJson<String>(formatLabel),
      'filePath': serializer.toJson<String?>(filePath),
      'fileSize': serializer.toJson<int?>(fileSize),
      'status': serializer.toJson<String>(status),
      'errorSummary': serializer.toJson<String?>(errorSummary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadHistoryEntry copyWith({
    int? id,
    String? url,
    String? title,
    Value<String?> uploader = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
    String? formatLabel,
    Value<String?> filePath = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    String? status,
    Value<String?> errorSummary = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadHistoryEntry(
    id: id ?? this.id,
    url: url ?? this.url,
    title: title ?? this.title,
    uploader: uploader.present ? uploader.value : this.uploader,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    formatLabel: formatLabel ?? this.formatLabel,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    status: status ?? this.status,
    errorSummary: errorSummary.present ? errorSummary.value : this.errorSummary,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadHistoryEntry copyWithCompanion(DownloadHistoryEntriesCompanion data) {
    return DownloadHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      uploader: data.uploader.present ? data.uploader.value : this.uploader,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      formatLabel: data.formatLabel.present
          ? data.formatLabel.value
          : this.formatLabel,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      status: data.status.present ? data.status.value : this.status,
      errorSummary: data.errorSummary.present
          ? data.errorSummary.value
          : this.errorSummary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryEntry(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('uploader: $uploader, ')
          ..write('durationSec: $durationSec, ')
          ..write('formatLabel: $formatLabel, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('status: $status, ')
          ..write('errorSummary: $errorSummary, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    title,
    uploader,
    durationSec,
    formatLabel,
    filePath,
    fileSize,
    status,
    errorSummary,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadHistoryEntry &&
          other.id == this.id &&
          other.url == this.url &&
          other.title == this.title &&
          other.uploader == this.uploader &&
          other.durationSec == this.durationSec &&
          other.formatLabel == this.formatLabel &&
          other.filePath == this.filePath &&
          other.fileSize == this.fileSize &&
          other.status == this.status &&
          other.errorSummary == this.errorSummary &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadHistoryEntriesCompanion
    extends UpdateCompanion<DownloadHistoryEntry> {
  final Value<int> id;
  final Value<String> url;
  final Value<String> title;
  final Value<String?> uploader;
  final Value<int?> durationSec;
  final Value<String> formatLabel;
  final Value<String?> filePath;
  final Value<int?> fileSize;
  final Value<String> status;
  final Value<String?> errorSummary;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const DownloadHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.uploader = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.formatLabel = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.status = const Value.absent(),
    this.errorSummary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String url,
    required String title,
    this.uploader = const Value.absent(),
    this.durationSec = const Value.absent(),
    required String formatLabel,
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    required String status,
    this.errorSummary = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
  }) : url = Value(url),
       title = Value(title),
       formatLabel = Value(formatLabel),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DownloadHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? uploader,
    Expression<int>? durationSec,
    Expression<String>? formatLabel,
    Expression<String>? filePath,
    Expression<int>? fileSize,
    Expression<String>? status,
    Expression<String>? errorSummary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (uploader != null) 'uploader': uploader,
      if (durationSec != null) 'duration_sec': durationSec,
      if (formatLabel != null) 'format_label': formatLabel,
      if (filePath != null) 'file_path': filePath,
      if (fileSize != null) 'file_size': fileSize,
      if (status != null) 'status': status,
      if (errorSummary != null) 'error_summary': errorSummary,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadHistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? url,
    Value<String>? title,
    Value<String?>? uploader,
    Value<int?>? durationSec,
    Value<String>? formatLabel,
    Value<String?>? filePath,
    Value<int?>? fileSize,
    Value<String>? status,
    Value<String?>? errorSummary,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadHistoryEntriesCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      durationSec: durationSec ?? this.durationSec,
      formatLabel: formatLabel ?? this.formatLabel,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      errorSummary: errorSummary ?? this.errorSummary,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (formatLabel.present) {
      map['format_label'] = Variable<String>(formatLabel.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorSummary.present) {
      map['error_summary'] = Variable<String>(errorSummary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('uploader: $uploader, ')
          ..write('durationSec: $durationSec, ')
          ..write('formatLabel: $formatLabel, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('status: $status, ')
          ..write('errorSummary: $errorSummary, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadHistoryEntriesTable downloadHistoryEntries =
      $DownloadHistoryEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [downloadHistoryEntries];
}

typedef $$DownloadHistoryEntriesTableCreateCompanionBuilder =
    DownloadHistoryEntriesCompanion Function({
      Value<int> id,
      required String url,
      required String title,
      Value<String?> uploader,
      Value<int?> durationSec,
      required String formatLabel,
      Value<String?> filePath,
      Value<int?> fileSize,
      required String status,
      Value<String?> errorSummary,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadHistoryEntriesTableUpdateCompanionBuilder =
    DownloadHistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> url,
      Value<String> title,
      Value<String?> uploader,
      Value<int?> durationSec,
      Value<String> formatLabel,
      Value<String?> filePath,
      Value<int?> fileSize,
      Value<String> status,
      Value<String?> errorSummary,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

class $$DownloadHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorSummary => $composableBuilder(
    column: $table.errorSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploader => $composableBuilder(
    column: $table.uploader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorSummary => $composableBuilder(
    column: $table.errorSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get uploader =>
      $composableBuilder(column: $table.uploader, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorSummary => $composableBuilder(
    column: $table.errorSummary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadHistoryEntriesTable,
          DownloadHistoryEntry,
          $$DownloadHistoryEntriesTableFilterComposer,
          $$DownloadHistoryEntriesTableOrderingComposer,
          $$DownloadHistoryEntriesTableAnnotationComposer,
          $$DownloadHistoryEntriesTableCreateCompanionBuilder,
          $$DownloadHistoryEntriesTableUpdateCompanionBuilder,
          (
            DownloadHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $DownloadHistoryEntriesTable,
              DownloadHistoryEntry
            >,
          ),
          DownloadHistoryEntry,
          PrefetchHooks Function()
        > {
  $$DownloadHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $DownloadHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadHistoryEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> uploader = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<String> formatLabel = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorSummary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadHistoryEntriesCompanion(
                id: id,
                url: url,
                title: title,
                uploader: uploader,
                durationSec: durationSec,
                formatLabel: formatLabel,
                filePath: filePath,
                fileSize: fileSize,
                status: status,
                errorSummary: errorSummary,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String url,
                required String title,
                Value<String?> uploader = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                required String formatLabel,
                Value<String?> filePath = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                required String status,
                Value<String?> errorSummary = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadHistoryEntriesCompanion.insert(
                id: id,
                url: url,
                title: title,
                uploader: uploader,
                durationSec: durationSec,
                formatLabel: formatLabel,
                filePath: filePath,
                fileSize: fileSize,
                status: status,
                errorSummary: errorSummary,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadHistoryEntriesTable,
      DownloadHistoryEntry,
      $$DownloadHistoryEntriesTableFilterComposer,
      $$DownloadHistoryEntriesTableOrderingComposer,
      $$DownloadHistoryEntriesTableAnnotationComposer,
      $$DownloadHistoryEntriesTableCreateCompanionBuilder,
      $$DownloadHistoryEntriesTableUpdateCompanionBuilder,
      (
        DownloadHistoryEntry,
        BaseReferences<
          _$AppDatabase,
          $DownloadHistoryEntriesTable,
          DownloadHistoryEntry
        >,
      ),
      DownloadHistoryEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadHistoryEntriesTableTableManager get downloadHistoryEntries =>
      $$DownloadHistoryEntriesTableTableManager(
        _db,
        _db.downloadHistoryEntries,
      );
}
