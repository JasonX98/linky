# M3 历史持久化、设置与双语实现计划（Plan 3 / 4）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 播放列表批量下载 UI、drift 历史持久化（任务终态自动落库 + 历史页管理）、设置持久化（下载目录/并发/默认画质/语言）、全 UI 双语（zh/en，引擎错误 kind 化本地化）。

**Architecture:** 数据层 drift（`AppDatabase` + `HistoryRepository`）；设置经 `SettingsController`（shared_preferences）持久化并被队列/目录解析/默认画质/语言实时消费；引擎错误在 T2 重构为 `EngineErrorKind` 枚举（服务边界抛出，UI 按语言渲染）；i18n 用 gen-l10n（`synthetic-package: false`），zh 为模板。

**Tech Stack:** drift + sqlite3_flutter_libs（+ build_runner/drift_dev 代码生成）、shared_preferences、file_selector（目录选择）、flutter gen-l10n。Riverpod/fluent_ui 沿用 M2。

**Spec:** `docs/superpowers/specs/2026-08-28-ytdlp-downloader-design.md`（本计划实现其 §9 里程碑 M3：§3.1 播放列表批量、§5.1 历史表、§5.2 设置、§6 历史/设置页与双语）

## Global Constraints

- 包名 `video_downloader`；平台仅 Windows
- 历史表 schema 按 spec §5.1 十二列；`format_label` 存 **QualityPreset 枚举名**（best/p1080/…，展示时本地化）；终态 completed/failed/canceled 均落库
- 设置键名（shared_preferences）：`downloadDir`(String?)、`concurrency`(int, 默认 3 范围 1–5)、`defaultPreset`(int, QualityPreset.values 下标)、`language`(String 'zh'/'en'，默认跟随系统，zh 回退)
- 引擎错误 kind 化：`EngineErrorKind` 枚举（login/geo/unavailable/network/timeout/parseFailed/engineMissing/outputFileMissing/unknown）承载于 `DownloadException.kind`；`detail` 保留原始 stderr 末行；`mapYtDlpError` 中文函数被 `classifyYtDlpError` 取代（M1 相关测试同步迁移）
- i18n：gen-l10n，`synthetic-package: false`，zh 模板 + en 完整；引擎错误按 kind 在 UI 层本地化；语言切换即时生效（FluentApp.locale）
- M1/M2 契约不变：`--encoding utf-8`、取消三层兜底（killTree 3s → exitCode 2s → kill）、drainTimeout 5s、`_patch` expected 守卫
- 新依赖：`drift`、`sqlite3_flutter_libs`、`shared_preferences`、`file_selector`；dev：`drift_dev`、`build_runner`（版本记录进提交正文）
- drift 测试前提：`NativeDatabase` 需要 sqlite3.dll——**先执行 `flutter build windows --debug` 生成 `build/windows/x64/runner/Debug/sqlite3.dll`**，测试 `setUpAll` 用 `open.overrideFor` 指向该 dll（T1 内含此脚手架）
- TDD；每任务提交；`flutter` 全路径 `D:\Application\DevTools\flutter\flutter3.44.9\bin\flutter.bat`；GUI 冒烟前必须重建；e2e 需 `RUN_E2E=1`

---

### Task 1: drift 基础设施与 HistoryRepository

**Files:**
- Modify: `pubspec.yaml`（drift/sqlite3_flutter_libs + dev: drift_dev/build_runner）
- Create: `lib/data/app_database.dart`、`lib/data/history_repository.dart`、`lib/data/app_database.g.dart`（代码生成产物，提交）
- Create: `test/data/history_repository_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - 表 `DownloadHistoryEntries`（spec §5.1 十二列：id 自增 / url / title / uploader? / durationSec? / formatLabel / filePath? / fileSize? / status / errorSummary? / createdAt / completedAt?）
  - `class AppDatabase extends _$AppDatabase`（schemaVersion 1）；`AppDatabase openAppDatabase()`（LazyDatabase +getApplicationSupportDirectory/history.sqlite）；测试用 `AppDatabase(VmDatabase.memory())`
  - `class HistoryRepository(AppDatabase db)`：
    - `Future<void> record({required String url, required String title, String? uploader, int? durationSec, required String formatLabel, String? filePath, int? fileSize, required String status, String? errorDetail, DateTime? completedAt})`（createdAt 自动取 now）
    - `Future<List<DownloadHistoryEntry>> recentEntries({int limit = 200})`（createdAt 倒序）
    - `Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200})`
    - `Future<void> deleteById(int id)`、`Future<int> removeAll()`

- [ ] **Step 1: 依赖与代码生成脚手架**

```powershell
& "D:\Application\DevTools\flutter\flutter3.44.9\bin\flutter.bat" pub add drift sqlite3_flutter_libs
& "D:\Application\DevTools\flutter\flutter3.44.9\bin\flutter.bat" pub add --dev drift_dev build_runner
```

（记录版本进提交正文）

- [ ] **Step 2: 写失败测试（含 sqlite3.dll 脚手架）**

```dart
// test/data/history_repository_test.dart
import 'dart:io';
import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:video_downloader/data/app_database.dart';
import 'package:video_downloader/data/history_repository.dart';

void main() {
  setUpAll(() {
    // flutter test 不加载 Windows 插件：显式指向 flutter build 产出的 sqlite3.dll
    open.overrideFor(OperatingSystem.windows, () {
      final dll = File('build/windows/x64/runner/Debug/sqlite3.dll');
      return DynamicLibrary.open(dll.absolute.path);
    });
  });

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
```

- [ ] **Step 3: 运行确认失败**

Run: `flutter test test/data/history_repository_test.dart`
Expected: FAIL（app_database.dart 不存在 → 编译错误）

- [ ] **Step 4: 实现 + 代码生成**

```dart
// lib/data/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
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
```

```dart
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
          createdAt: DateTime.now(),
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
          ..orderBy([(u) => OrderingTerm.desc(u.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) {
    return (_db.select(_db.downloadHistoryEntries)
          ..orderBy([(u) => OrderingTerm.desc(u.createdAt)])
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
```

先生成再跑测试（生成需要表定义存在）：

```powershell
& "D:\Application\DevTools\flutter\flutter3.44.9\bin\cache\dart-sdk\bin\dart.exe" run build_runner build --delete-conflicting-outputs
& "D:\Application\DevTools\flutter\flutter3.44.9\bin\flutter.bat" build windows --debug   # 产出 sqlite3.dll 供测试加载
& "D:\Application\DevTools\flutter\flutter3.44.9\bin\flutter.bat" test test\data\history_repository_test.dart
```

Expected: 生成 `app_database.g.dart`；测试 5/5 PASS

- [ ] **Step 5: 全量回归 + 提交**

```powershell
flutter analyze; flutter test   # 全绿（含既有 69+3skip）
git add pubspec.yaml pubspec.lock lib/data test/data
git commit -m "feat(data): drift history repository (m3)"
```

（提交正文记录 drift/drift_dev/build_runner/sqlite3_flutter_libs 版本）

---

### Task 2: 引擎错误分类（kind 化）

**Files:**
- Modify: `lib/engine/models.dart`（EngineErrorKind 枚举；DownloadException 改形）
- Modify: `lib/engine/yt_dlp_parser.dart`（classifyYtDlpError 取代 mapYtDlpError）
- Modify: `lib/engine/yt_dlp_service.dart`（5 处抛点改 kind）
- Modify: `lib/features/download/queue_controller.dart` + `lib/features/download/download_task.dart`（errorSummary → errorKind/errorDetail）
- Test: `test/engine/yt_dlp_parser_test.dart`、`test/engine/yt_dlp_service_test.dart`、`test/features/download/queue_controller_test.dart`（断言迁移）

**Interfaces:**
- Consumes: M1 parser 的错误映射逻辑（登录→地区→不可用→网络→兜底 顺序不变）
- Produces:
  - `enum EngineErrorKind { login, geo, unavailable, network, timeout, parseFailed, engineMissing, outputFileMissing, unknown }`（定义在 models.dart）
  - `DownloadException` 新形：`const DownloadException(this.kind, [this.detail = ''])`，字段 `final EngineErrorKind kind; final String detail;`（friendlyMessage 删除——显示职责移交 UI 层，T5 本地化）
  - parser：`EngineError classifyYtDlpError(String stderrTail)`；`class EngineError { final EngineErrorKind kind; final String detail; }`（detail = stderr 末条非空行）；`mapYtDlpError` 删除
  - service 抛点映射：probe 超时→`timeout`；probe 非零退出→classify 结果；probe 解析失败→`parseFailed`（detail=stdout 原文）；缺引擎→`engineMissing`（detail=path）；下载非零→classify；路径未定位→`outputFileMissing`
  - DownloadTask：`errorSummary` → `final EngineErrorKind? errorKind; final String? errorDetail;`（copyWith 对应调整）；过渡期 UI 直接显示 errorDetail（T5 换成本地化文本）
  - queue：`_friendly` 删除；error 路径 patch `errorKind: e is DownloadException ? e.kind : EngineErrorKind.unknown, errorDetail: e is DownloadException ? e.detail : e.toString()`

- [ ] **Step 1: 迁移失败测试（先改断言，使其在旧代码上必然失败）**

parser 测试（`mapYtDlpError` group 整体替换为）：

```dart
  group('classifyYtDlpError', () {
    test('video unavailable', () {
      final e = classifyYtDlpError(
          'ERROR: [youtube] abc: Video unavailable. This video is no longer available');
      expect(e.kind, EngineErrorKind.unavailable);
      expect(e.detail, contains('no longer available'));
    });
    test('network error', () {
      expect(
          classifyYtDlpError(
              'ERROR: unable to download video data: HTTP Error 403: Forbidden')
              .kind,
          EngineErrorKind.network);
    });
    test('geo restricted', () {
      expect(
          classifyYtDlpError(
                  'ERROR: [youtube] abc: This video is not available in your country.')
              .kind,
          EngineErrorKind.geo);
    });
    test('login required', () {
      expect(
          classifyYtDlpError(
                  'ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate for some users.')
              .kind,
          EngineErrorKind.login);
    });
    test('fallback keeps last stderr line as detail', () {
      final e = classifyYtDlpError('ERROR: [bilibili] 123: something weird happened');
      expect(e.kind, EngineErrorKind.unknown);
      expect(e.detail, 'ERROR: [bilibili] 123: something weird happened');
    });
  });
```

（顶部 import 增加 models.dart 的 EngineErrorKind；移除 mapYtDlpError 相关导入符号）

service 测试断言迁移（3 处）：

```dart
// 非零退出（原 contains('不可用')）
throwsA(isA<DownloadException>()
    .having((e) => e.kind, 'kind', EngineErrorKind.unavailable))
// 下载失败（原 contains('登录')）
.having((e) => e.kind, 'kind', EngineErrorKind.login)
// 分析超时（原 contains('超时')）
.having((e) => e.kind, 'kind', EngineErrorKind.timeout)
// 解析失败（原 contains('无法解析') 与 drains 同理）
.having((e) => e.kind, 'kind', EngineErrorKind.parseFailed)
```

queue 测试迁移（2 处）：`tasks.single.errorSummary contains('不可用')` → `errorKind == EngineErrorKind.unavailable`；T5 的 `errorSummary == '发生意外错误，请重试'` → `errorKind == EngineErrorKind.unknown` 且 `errorDetail` 非空。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/engine test/features`
Expected: FAIL（classifyYtDlpError/EngineErrorKind 不存在；friendlyMessage 断言失败）

- [ ] **Step 3: 实现**

models.dart（EngineErrorKind 放在 QualityPreset 附近；DownloadException 替换）：

```dart
enum EngineErrorKind {
  login, geo, unavailable, network, timeout, parseFailed, engineMissing, outputFileMissing, unknown,
}

class DownloadException implements Exception {
  const DownloadException(this.kind, [this.detail = '']);
  final EngineErrorKind kind;
  final String detail;
  @override
  String toString() => 'DownloadException($kind): $detail';
}
```

parser：`mapYtDlpError` 整体替换为：

```dart
EngineError classifyYtDlpError(String stderrTail) {
  final t = stderrTail.toLowerCase();
  EngineError at(EngineErrorKind kind) => EngineError(
      kind, detail: _lastNonEmptyLine(stderrTail));
  if (t.contains('sign in') ||
      t.contains('confirm your age') ||
      t.contains('members') ||
      t.contains('join this channel')) {
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
      t.contains('does not exist')) {
    return at(EngineErrorKind.unavailable);
  }
  if (t.contains('timed out') ||
      t.contains('timeout') ||
      t.contains('unable to download') ||
      t.contains('connection') ||
      t.contains('getaddrinfo') ||
      t.contains('network')) {
    return at(EngineErrorKind.network);
  }
  return at(EngineErrorKind.unknown);
}

String _lastNonEmptyLine(String s) => s
    .split('\n')
    .where((l) => l.trim().isNotEmpty)
    .lastOrNull?.trim() ?? '';
```

（`EngineError` 类与 `EngineErrorKind` 的 import 来自 models.dart。）

service 五处抛点：

```dart
throw const DownloadException(EngineErrorKind.timeout);                       // 分析超时（drain 超时同理）
throw DownloadException(EngineErrorKind.parseFailed, stdoutBuf.toString());   // 解析失败
throw DownloadException(cls.kind, cls.detail);                                 // 非零退出（cls = classifyYtDlpError(stderrBuf)）
throw DownloadException(EngineErrorKind.engineMissing, e.path);               // 缺引擎（见 Task 4 的 _resolveEngine 合并说明）
throw const DownloadException(EngineErrorKind.outputFileMissing);             // 路径未定位
```

注：M1 末尾的 `_resolveEngine()`（EngineMissingException → DownloadException(engineMissing, e.path)）保持等价语义，仅改构造形参。probe 超时的两处（exitCode 与 drain）与 self-terminate 抛点全部迁移。download_task.dart：

```dart
final EngineErrorKind? errorKind;
final String? errorDetail;
```
copyWith：`errorKind`、`errorDetail` 参数；`clearError` 同时清两者。queue_controller：`_patch` 增加 `errorKind` 透传；error 路径：

```dart
_patch(task.id,
    expected: const {TaskStatus.downloading, TaskStatus.canceling},
    status: wasCanceling ? TaskStatus.canceled : TaskStatus.failed,
    errorKind: wasCanceling ? null : (e is DownloadException ? e.kind : EngineErrorKind.unknown),
    errorDetail: wasCanceling ? null : (e is DownloadException ? e.detail : e.toString()));
```

- [ ] **Step 4: 运行确认通过 + 全量回归**

Run: `flutter analyze; flutter test`
Expected: 全绿。UI（download_page）若编译报 `errorSummary` 不存在 → 过渡期改为 `Text(t.errorDetail ?? '')` 并在报告中注明（T5 换成本地化渲染）。

- [ ] **Step 5: 提交**

```powershell
git add -A lib/engine lib/features test/engine test/features
git commit -m "refactor(engine): classify yt-dlp errors into kinds (i18n groundwork)"
```

---

### Task 3: 终态落库与任务上下文补全

**Files:**
- Modify: `lib/engine/models.dart`（DownloadRequest.uploader/durationSec 可选）
- Modify: `lib/features/download/download_task.dart`（uploader/durationSec 字段）
- Modify: `lib/features/download/providers.dart`（appDatabaseProvider + historyRepositoryProvider）
- Modify: `lib/features/download/queue_controller.dart`（终态落库 + 透传）
- Test: `test/features/download/queue_controller_test.dart`（FakeHistoryRepository）

**Interfaces:**
- Consumes: Task 1 `HistoryRepository.record`；Task 2 的 kind
- Produces:
  - `DownloadRequest`/`DownloadTask`/`enqueue` 新增可选 `String? uploader`、`int? durationSec`（分析卡片入队时透传，历史记录用）
  - providers：`appDatabaseProvider`（`openAppDatabase()` + `ref.onDispose(db.close)`）、`historyRepositoryProvider`
  - 队列终态（completed/failed/canceled）落库：status 用 `task.status.name`；errorSummary 用 `errorDetail`；formatLabel 用 `preset.name`；uploader/durationSec 透传；落库失败静默（不 影响任务）
  - `FakeQueueService.download` 签名不变（uploader/durationSec 不经 service，由 controller 侧直接持有）

- [ ] **Step 1: 追加失败测试**

```dart
class FakeHistoryRepository {
  int recordCount = 0;
  final List<Map<String, Object?>> rows = [];
  Future<void> record({
    required String url, required String title, String? uploader,
    int? durationSec, required String formatLabel, String? filePath,
    int? fileSize, required String status, String? errorDetail, DateTime? completedAt,
  }) async {
    recordCount++;
    rows.add({'url': url, 'title': title, 'status': status, 'filePath': filePath});
  }
  Future<List<DownloadHistoryEntry>> recentEntries({int limit = 200}) async => [];
  Stream<List<DownloadHistoryEntry>> watchRecent({int limit = 200}) => const Stream.empty();
  Future<void> deleteById(int id) async {}
  Future<int> removeAll() async => 0;
}
```

（容器 overrides 追加 `historyRepositoryProvider.overrideWith((ref) => FakeHistoryRepository())`——因此 `historyRepositoryProvider` 的类型必须是 `Provider<HistoryRepository>`；Fake 需与 HistoryRepository 同形。若类型冲突，把 Fake 声明为 `implements HistoryRepository` 并以相同方法体实现。）

新增用例：

```dart
  test('terminal transitions record history rows', () async {
    final history = container.read(historyRepositoryProvider) as FakeHistoryRepository;
    final id = await controller.enqueue(url: 'u', title: '视频', preset: QualityPreset.best);
    await _settle();
    fake.pending[id]!.complete('D:\\dl\\v.mp4');
    await _settle();
    expect(history.recordCount, 1);
    expect(history.rows.single['status'], 'completed');

    final id2 = await controller.enqueue(url: 'u2', title: '视频2', preset: QualityPreset.best);
    await _settle();
    fake.pending[id2]!.completeError(const DownloadException(EngineErrorKind.unavailable, 'detail-x'));
    await _settle();
    expect(history.rows.last['status'], 'failed');
  });
```

- [ ] **Step 2: 运行确认失败 → Step 3: 实现**

providers.dart 追加：

```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final historyRepositoryProvider = Provider<HistoryRepository>(
    (ref) => HistoryRepository(ref.watch(appDatabaseProvider)));
```

DownloadRequest/DownloadTask/enqueue 增加 `uploader`/`durationSec` 可选透传；queue `_run` 的成功/失败/取消三个 `_patch` 之后：

```dart
unawaited(_recordTerminal(updatedTask)); // 用 patch 后的最新任务状态
```

```dart
Future<void> _recordTerminal(DownloadTask t) async {
  try {
    await ref.read(historyRepositoryProvider).record(
        url: t.url, title: t.title, uploader: t.uploader,
        durationSec: t.durationSec, formatLabel: t.preset.name,
        filePath: t.filePath, status: t.status.name,
        errorDetail: t.errorDetail, completedAt: DateTime.now());
  } catch (_) {
    // 历史落库失败不影响任务状态
  }
}
```

（`_patch` 返回 void——改为返回 `DownloadTask?`（更新后的任务），或在 patch 后重新 `_find`；实现者取一种并保持测试通过。）

- [ ] **Step 4: 运行确认通过 + 全量回归 → Step 5: 提交**

```powershell
flutter analyze; flutter test
git add lib/engine/models.dart lib/features/download lib/features/download/queue_controller.dart test/features/download
git commit -m "feat(history): persist terminal tasks to drift via queue"
```

---

### Task 4: 设置持久化与 SettingsController

**Files:**
- Modify: `pubspec.yaml`（shared_preferences）
- Create: `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/download/providers.dart`（sharedPrefsProvider + settingsProvider；downloadsDirProvider 读设置）
- Modify: `lib/features/download/queue_controller.dart`（并发改由 settings 驱动）
- Modify: `lib/main.dart`（main 预取 prefs + override）
- Test: `test/features/settings/settings_controller_test.dart`、`test/features/download/queue_controller_test.dart`（容器加 settings override）

**Interfaces:**
- Consumes: Task 3 providers 模式
- Produces:
  - `sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError())`（main override）
  - `class SettingsState { downloadDir(String?)/concurrency(int=3)/defaultPreset(QualityPreset=best)/language(String，默认跟随系统 zh 回退) }` const + copyWith
  - `class SettingsController extends Notifier<SettingsState>`：build 从 prefs 读取；`setDownloadDir(String?)` / `setConcurrency(int)`(clamp 1–5) / `setDefaultPreset(QualityPreset)` / `setLanguage(String)` —— 即改即持久化
  - `settingsProvider = NotifierProvider<SettingsController, SettingsState>(...)`
  - `downloadsDirProvider`：先读 `settingsProvider.downloadDir`，空则 Downloads → temp
  - 队列并发：`int get _concurrency => ref.read(settingsProvider).concurrency`（删除字段）；`controller.setConcurrency(v)` 变为委托 `settingsProvider.notifier.setConcurrency(v)`；`build()` 内 `ref.listen(settingsProvider, (p, n) { if (p?.concurrency != n.concurrency) _startNext(); })`
  - main.dart：`WidgetsFlutterBinding.ensureInitialized(); final prefs = await SharedPreferences.getInstance(); runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const App()));`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/settings/settings_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/features/download/providers.dart';
import 'package:video_downloader/features/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> make(
      Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('defaults: concurrency 3, best preset, language follows system', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.concurrency, 3);
    expect(s.defaultPreset, QualityPreset.best);
    expect(s.language, isIn(['zh', 'en']));
    expect(s.downloadDir, isNull);
  });

  test('setters persist to prefs and update state', () async {
    final (c, prefs) = await make({});
    final ctl = c.read(settingsProvider.notifier);
    ctl.setConcurrency(5);
    ctl.setDefaultPreset(QualityPreset.p720);
    ctl.setDownloadDir(r'D:\Videos');
    ctl.setLanguage('en');
    await Future<void>.delayed(Duration.zero);

    final s = c.read(settingsProvider);
    expect(s.concurrency, 5);
    expect(s.defaultPreset, QualityPreset.p720);
    expect(s.downloadDir, r'D:\Videos');
    expect(s.language, 'en');
    expect(prefs.getInt('concurrency'), 5);
    expect(prefs.getInt('defaultPreset'), QualityPreset.p720.index);
    expect(prefs.getString('downloadDir'), r'D:\Videos');
    expect(prefs.getString('language'), 'en');
  });

  test('concurrency clamps to 1..5 and loads persisted values', () async {
    final (c, _) = await make({'concurrency': 9, 'defaultPreset': 2});
    final s = c.read(settingsProvider);
    expect(s.concurrency, 3.clamp(1, 5)); // 越界回落默认 3
    expect(s.defaultPreset, QualityPreset.p480);
    c.read(settingsProvider.notifier).setConcurrency(0);
    expect(c.read(settingsProvider).concurrency, 1);
  });
}
```

queue 测试迁移：容器 overrides 追加

```dart
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
... sharedPrefsProvider.overrideWithValue(prefs),
```
（setUp 变 async；既有 `controller.setConcurrency(1)` 调用不变——委托层保持 API。）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现（按 Interfaces 描述） → Step 4: 全量回归 → Step 5: 提交**

```powershell
git add pubspec.yaml pubspec.lock lib/features/settings lib/features/download/providers.dart lib/features/download/queue_controller.dart lib/main.dart test/features
git commit -m "feat(settings): persisted settings (dir/concurrency/preset/language) driving queue and dir resolution"
```

---

### Task 5: i18n 基础（gen-l10n zh/en + 全量迁移 + 语言切换）

**Files:**
- Modify: `pubspec.yaml`（`flutter: generate: true`）
- Create: `l10n.yaml`、`lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`
- Modify: `lib/main.dart`（FluentApp locale/delegates）、`lib/features/shell/app_shell.dart`、`lib/features/download/download_page.dart`（全字符串 + 错误按 kind 本地化 + 顺手修复 M2 遗留：'正在取消...' 双渲染、_analyze 冗余 setState）
- Test: `test/ui/download_page_test.dart`（新增 en 用例）、`test/ui/app_shell_test.dart`

**Interfaces:**
- Produces:
  - `l10n.yaml`：`arb-dir: lib/l10n` / `template-arb-file: app_zh.arb` / `output-localization-file: app_localizations.dart` / `synthetic-package: false` / `output-class: S`
  - ARB 键（zh 模板给中文值；en 给英文；占位符用 ICU）：navDownload/navHistory/navSettings、historyPlaceholder、settingsPlaceholder、urlPlaceholder、analyze/analyzing、addToDownload、taskList、statusQueued、statusDownloading、statusCanceling、statusDone、statusCanceled、statusFailed、speedLabel、etaLabel(seconds 占位)、retry、cancel、openFolder、selectAll、invertSelection、playlistNotice(title,count)、selectedCount(count)、openFile、settingsDownloadDir、browse、settingsConcurrency、settingsDefaultQuality、settingsLanguage、languageName(自指)、errorLogin、errorGeo、errorUnavailable、errorNetwork、errorTimeout、errorParse、errorEngineMissing(path)、errorOutputMissing、errorUnknown(detail 占位)、unknownUploader、durationSeconds(count)、downloadFailed
  - `String errorText(BuildContext context, EngineErrorKind kind, String detail)`（core 或 download_page 内私有 helper）：kind → context.S 的 errorXxx；engineMissing 用 path 占位；unknown/errorDetail 兜底
  - 生成类名 `S`，导入 `package:video_downloader/l10n/app_localizations.dart`；用法 `S.of(context).xxx`
  - FluentApp：`locale: Locale(settings.language)`、`localizationsDelegates: S.localizationsDelegates`、`supportedLocales: S.supportedLocales`
- 迁移原则：现有中文串的 zh 值与 M2 完全一致（既有 widget 测试不动即绿）；en 提供准确英文

- [ ] **Step 1: 配置 + ARB（zh 先行，全部键列出；en 同键翻译）**

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localizations-file: app_localizations.dart
output-class: S
synthetic-package: false
nullable-getter: false
```

`app_zh.arb` 示例（节选，完整键见 Interfaces；`@@locale` 置顶）：

```json
{
  "@@locale": "zh",
  "navDownload": "下载",
  "navHistory": "历史",
  "navSettings": "设置",
  "playlistNotice": "检测到播放列表「{title}」，共 {count} 个条目",
  "@playlistNotice": { "placeholders": { "title": {"type": "String"}, "count": {"type": "int"} } },
  "errorEngineMissing": "未找到下载引擎：{path}",
  "@errorEngineMissing": { "placeholders": { "path": {"type": "String"} } },
  "selectedCount": "已选 {count}/{total} 个条目",
  "@selectedCount": { "placeholders": { "count": {"type": "int"}, "total": {"type": "int"} } }
}
```

生成：`flutter gen-l10n`

- [ ] **Step 2: 写失败测试**

```dart
// download_page_test.dart 追加
  testWidgets('english locale switches chrome strings', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ytDlpServiceProvider.overrideWithValue(FakeUiService()),
        sharedPrefsProvider.overrideWithValue(prefs),
        downloadsDirProvider.overrideWithValue(() async => r'C:\tmp'),
      ],
      child: FluentApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsWidgets); // 导航项
    expect(find.text('下载'), findsNothing);
  });
```

（既有 zh 用例在 settings override 后应保持全绿——zh 文案不变。）

- [ ] **Step 3: 运行确认失败 → Step 4: 实现**

- gen-l10n 配置如上；`flutter gen-l10n` 产出 `lib/l10n/app_localizations*.dart`（提交）
- main.dart：`FluentApp(locale: Locale(ref... settings.language), localizationsDelegates: S.localizationsDelegates, supportedLocales: S.supportedLocales, ...)`（App 需变 ConsumerWidget 以读 settingsProvider）
- 全页面字符串替换为 `S.of(context).xxx`；任务状态行错误渲染改为 `errorText(context, kind, detail)`；修复 M2 遗留：`正在取消...` 只保留状态行一处、`_analyze` 尾部 `setState(() {})` 删除
- 队列 errorSummary 过渡显示移除：任务行错误显示 `errorText`；分析 Error 分支 `AnalysisError.message` 由 controller 传 kind？——**保持 AnalysisError.message**（controller 层在 T5 一并改为：probe 失败时 message = detail，UI 按 `AnalysisError.kind` 本地化——给 AnalysisError 增加 `EngineErrorKind kind` 字段，DownloadException 捕获处填 kind，generic 填 unknown；message 保留 detail）

- [ ] **Step 5: 全量回归（zh 用例全绿 + en 新用例绿）→ Step 6: 提交**

```powershell
git add -A lib test l10n.yaml pubspec.yaml
git commit -m "feat(i18n): gen-l10n zh/en with kind-based error localization and live language switch"
```

---

### Task 6: 播放列表批量下载 UI

**Files:**
- Modify: `lib/features/download/download_page.dart`（playlist 分支：多选列表 + 全选/反选 + 批量入队）
- Test: `test/ui/download_page_test.dart`

**Interfaces:**
- Consumes: Task 5 l10n；M1 `PlaylistMeta.entries`（id/title/url/durationSec）；queue.enqueue
- Produces:
  - 播放列表分支渲染：InfoBar（playlistNotice，count=条目总数）+ `ListView`（每行 Checkbox + 标题 + 时长）+ `selectAll_button` / `invertSelection_button` + `enqueue_button`（无选中禁用；文案 addToDownload）
  - 状态：`Set<String> _selectedUrls`（分析成功后默认全选）；单选切换即时更新 `selectedCount` 文案
  - `_enqueuePlaylist()`：对选中条目逐个 `enqueue(url: entry.url, title: entry.title, preset: _preset, uploader: video.uploader, durationSec: entry.durationSec)`；完成后 reset 分析 + 清空输入
  - M2 遗留顺手项：'正在取消...' 单处渲染；`_analyze` 冗余 setState 移除（若 T5 未清）

- [ ] **Step 1: 写失败测试**

```dart
  testWidgets('playlist batch enqueues selected entries', (tester) async {
    await tester.pumpWidget(wrap(FakeUiService(playlist: true)));
    await tester.enterText(find.byKey(const Key('url_field')), 'u');
    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pumpAndSettle();

    // 默认全选 3 条，取消第 1 条后批量入队 → 仅 2 个任务
    await tester.tap(find.byKey(const Key('check_u1')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enqueue_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open_t1')), findsOneWidget);
    expect(find.byKey(const Key('open_t2')), findsOneWidget);
    expect(find.byKey(const Key('open_t0')), findsNothing);
  });
```

（FakeUiService.playlist 分支改为 3 条目：url u1/u2/u3，title A/B/C；Checkbox key 规则 `check_<entry.url>`。）

- [ ] **Step 2: 运行确认失败 → Step 3: 实现 → Step 4: 全量回归 → Step 5: 提交**

```powershell
flutter analyze; flutter test
git add lib/features/download/download_page.dart test/ui/download_page_test.dart
git commit -m "feat(playlist): batch download UI with select-all and per-entry toggles"
```

---

### Task 7: 历史页

**Files:**
- Create: `lib/features/history/history_page.dart`
- Modify: `lib/features/shell/app_shell.dart`（历史窗格指向 HistoryPage）
- Modify: `lib/features/download/providers.dart`（无改动则跳过）
- Test: `test/ui/history_page_test.dart`

**Interfaces:**
- Consumes: Task 1 `historyRepositoryProvider.watchRecent/deleteById/removeAll`；queue.enqueue（重新下载）；l10n
- Produces:
  - `HistoryPage`（ConsumerWidget）：`ref.watch(historyRepositoryProvider).watchRecent()` 流 → 列表行：标题（maxLines 1）、状态徽标（completed/failed/canceled 本地化）、完成时间（`yyyy-MM-dd HH:mm` 本地格式化简版）、错误 detail（failed 时弱化显示）
  - 行操作（key 规则）：`open_file_<id>`（`Process.run('cmd.exe', ['/c', 'start', '', filePath])`，仅 completed 且有 filePath）、`open_dir_<id>`（explorer /select，同条件）、`redownload_<id>`（enqueue 同 url/title/preset-by-name）、`delete_<id>`（deleteById）
  - 空态文案：`S.of(context).historyPlaceholder`（'暂无下载记录'——新增键）
  - 列表刷新：drift watch 自动响应

- [ ] **Step 1: 写失败测试**

```dart
// test/ui/history_page_test.dart
// FakeHistoryRepository（内存 list + 手动 watch StreamController）注入 historyRepositoryProvider
// 用例 1：两条记录（completed/failed）→ 标题/状态/操作按钮按 status 条件渲染
// 用例 2：tap delete_<id> → 行消失
// 用例 3：tap redownload_<id> → 队列出现同名任务（需同时注入 fake queue service）
```

（Fake 直接 `implements HistoryRepository`，watchRecent 返回 `Stream.value(rows)` 供 pumpAndSettle。）

- [ ] **Step 2: 确认失败 → Step 3: 实现 → Step 4: 回归 → Step 5: 提交**

```powershell
flutter analyze; flutter test
git add lib/features/history lib/features/shell/app_shell.dart test/ui/history_page_test.dart
git commit -m "feat(history): history page with open/redownload/delete"
```

---

### Task 8: 设置页

**Files:**
- Create: `lib/features/settings/settings_page.dart`
- Modify: `pubspec.yaml`（file_selector）
- Modify: `lib/features/shell/app_shell.dart`（设置窗格指向 SettingsPage）
- Test: `test/ui/settings_page_test.dart`

**Interfaces:**
- Consumes: Task 4 `settingsProvider`（setDownloadDir/setConcurrency/setDefaultPreset/setLanguage）；Task 5 l10n
- Produces:
  - `SettingsPage`（ConsumerWidget）：`ScaffoldPage` 表单
    - 下载目录：当前值 Text（空显示'系统下载文件夹'）+ `browse_button`（`getDirectoryPath()` → setDownloadDir）
    - 并发：`Slider(min: 1, max: 5, divisions: 4, value, onChanged → setConcurrency)` + 数值 Text（key `concurrency_slider`）
    - 默认画质：`ComboBox<QualityPreset>`（label 本地化? preset label 保持枚举 zh 名——T5 未纳入则沿用 M2 label；键 `preset_combo`）
    - 语言：`ComboBox<String>`（中文/English，`language_combo` → setLanguage 即时切换全 UI）
  - 浏览依赖注入：`Future<String?> Function()? directoryPicker`（构造参数，测试注入；默认 `getDirectoryPath`）

- [ ] **Step 1: 写失败测试**

```dart
// 注入 mock prefs + fake picker
// 用例 1：tap browse_button → fake 返回 'D:\X' → 目录 Text 更新
// 用例 2：拖动/点击 slider（tester.tap 在目标刻度）→ concurrency 文本变化
// 用例 3：语言选 English → 'Settings' 等本页文案即时变英文
```

- [ ] **Step 2: 确认失败 → Step 3: 实现 → Step 4: 回归 → Step 5: 提交**

```powershell
flutter analyze; flutter test
git add pubspec.yaml pubspec.lock lib/features/settings lib/features/shell test/ui/settings_page_test.dart
git commit -m "feat(settings): settings page with dir picker, concurrency, quality, language"
```

---

### Task 9: E2E 与 GUI 冒烟

**Files:**
- Create: `test/e2e/history_settings_e2e_test.dart`（RUN_E2E 门控，同 M2 模式）
- Modify: 无其他

**Interfaces:**
- Consumes: M2 本地节流服务器模式；真实引擎（YTDLP_ENGINE_DIR）；内存 drift（appDatabaseProvider override）+ mock prefs
- Produces: M3 出口标准——完成落库可查、设置驱动并发与目录、批量入队走真实队列

- [ ] **Step 1: 写 E2E（3 个用例）**

1. **完成落库**：节流服务器 2MB → enqueue → completed → `historyRepository.recentEntries()` 轮询出现 status=completed 且 filePath 以 tmp 开头（AppDatabase 用 `NativeDatabase.memory()` override appDatabaseProvider）
2. **设置驱动**：mock prefs `{concurrency: 1, downloadDir: <tmp>}` → 两个节流任务严格串行，且产物落在 tmp（目录设置生效）
3. **失败落库**：指向不存在端口 → failed → 历史行 status=failed 含 errorDetail

- [ ] **Step 2: 运行（含 env）→ Step 3: 全量回归 → Step 4: 提交**

```powershell
$env:RUN_E2E='1'; $env:YTDLP_ENGINE_DIR=(Resolve-Path "assets\bin").Path
flutter test test\e2e
Remove-Item Env:RUN_E2E
flutter analyze; flutter test   # 默认套件全绿 + e2e skipped
git add test/e2e/history_settings_e2e_test.dart
git commit -m "test(e2e): history persistence and settings-driven queue"
```

- [ ] **Step 5: GUI 冒烟（与用户协作；先重建！）**

```powershell
flutter build windows --debug
Start-Process "build\windows\x64\runner\Debug\video_downloader.exe"
```

用户清单：
1. 粘贴 B 站播放列表链接 → 分析 → 多选条目 → 批量入队按并发下载
2. 下载完成/失败后，历史页出现记录；打开文件/文件夹、重新下载、删除均可用
3. 设置页改并发为 1 → 新任务串行；改下载目录 → 新任务落新目录
4. 语言切 English → 全 UI（含导航/按钮/状态/历史/设置）即时英文；切回中文恢复
5. 重启应用 → 设置与历史仍在
6. 全程无控制台闪窗

- [ ] **Step 6: 有修复则回归提交；无修复确认工作树干净**

---

## 后续计划

- **Plan 4 (M4)**：引擎自动更新与自愈、错误打磨（含 killTree 诊断日志、超时可注入）、免责声明、msix 打包、fetch 脚本 SHA-256 校验
