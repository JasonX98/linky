// test/engine/yt_dlp_service_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_downloader/engine/engine_locator.dart';
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
  bool killTreeCalled = false;
  @override
  Future<int> get exitCode => _exitCode;
  @override
  void kill() => killed = true;
  @override
  int get pid => 4321;
  @override
  Future<void> killTree() async {
    killTreeCalled = true;
  }
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

EngineLocator _stubLocatorWithFfmpeg(Directory dir) {
  final bin = p.join(dir.path, 'data', 'flutter_assets', 'assets', 'bin');
  Directory(bin).createSync(recursive: true);
  File(p.join(bin, 'yt-dlp.exe')).writeAsStringSync('');
  File(p.join(bin, 'ffmpeg.exe')).writeAsStringSync('');
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
    expect(launcher.lastArgs,
        containsAllInOrder(['--encoding', 'utf-8']));
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

  test('probe passes --cookies when cookieFile given', () async {
    final launcher =
        FakeLauncher(FakeAppProcess(stdout: Stream.value(_videoJson)));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    await service.probe('https://example.com/v',
        cookieFile: r'C:\cookies\net.txt');
    expect(launcher.lastArgs,
        containsAllInOrder(['--cookies', r'C:\cookies\net.txt']));
  });

  test('probe omits --cookies when cookieFile is null', () async {
    final launcher =
        FakeLauncher(FakeAppProcess(stdout: Stream.value(_videoJson)));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    await service.probe('https://example.com/v');
    expect(launcher.lastArgs, isNot(contains('--cookies')));
  });

  test('non-zero exit classifies stderr into error kind', () async {
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
          .having((e) => e.kind, 'kind', EngineErrorKind.unavailable)),
    );
  });

  test('probe timeout kills process and throws timeout kind', () async {
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
          .having((e) => e.kind, 'kind', EngineErrorKind.timeout)),
    );
    expect(proc.killed, isTrue);
  });

  test('malformed stdout json surfaces parseFailed kind', () async {
    final launcher =
        FakeLauncher(FakeAppProcess(stdout: Stream.value('not-json{')));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    await expectLater(
      service.probe('https://example.com/v'),
      throwsA(isA<DownloadException>()
          .having((e) => e.kind, 'kind', EngineErrorKind.parseFailed)),
    );
  });

  test('non-object json surfaces parseFailed kind', () async {
    final launcher =
        FakeLauncher(FakeAppProcess(stdout: Stream.value('[]')));
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));

    await expectLater(
      service.probe('https://example.com/v'),
      throwsA(isA<DownloadException>()
          .having((e) => e.kind, 'kind', EngineErrorKind.parseFailed)),
    );
  });

  test('probe drains stdout fully before parsing', () async {
    final ctrl = StreamController<String>();
    const part1 = '{"_type":"video","id":"v1","title":"完整';
    const part2 = '标题","webpage_url":"https://e/v"}';
    Timer(const Duration(milliseconds: 20), () {
      ctrl.add(part2);
      ctrl.close();
    });
    ctrl.add(part1);
    final launcher = FakeLauncher(FakeAppProcess(
      stdout: ctrl.stream,
      exitCode: Future.value(0), // exits immediately, before stdout drains
    ));
    final service =
        YtDlpService(launcher: launcher, locator: _stubLocator(temp));

    final result = await service.probe('https://example.com/v');
    expect((result as VideoResult).meta.title, '完整标题');
  });

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
      expect(launcher.lastArgs, containsAllInOrder(['--encoding', 'utf-8']));
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

    test('failure maps stderr to login kind exception', () async {
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
            .having((e) => e.kind, 'kind', EngineErrorKind.login)),
      );
    });

    test('download passes --cookies when cookieFile set', () async {
      final launcher = FakeLauncher(FakeAppProcess(stdout: Stream.fromIterable([
        'D:\\dl\\Sample.mp4',
      ])));
      final service = YtDlpService(
          launcher: launcher, locator: _stubLocator(temp));

      final path = await service.download(DownloadRequest(
          url: 'https://example.com/v',
          preset: QualityPreset.best,
          outputDir: 'D:\\dl',
          cookieFile: r'C:\cookies\net.txt'));
      expect(path, 'D:\\dl\\Sample.mp4');
      expect(launcher.lastArgs,
          containsAllInOrder(['--cookies', r'C:\cookies\net.txt']));
    });

    test('download omits --cookies when cookieFile is null', () async {
      final launcher = FakeLauncher(FakeAppProcess(stdout: Stream.fromIterable([
        'D:\\dl\\Sample.mp4',
      ])));
      final service = YtDlpService(
          launcher: launcher, locator: _stubLocator(temp));

      await service.download(DownloadRequest(
          url: 'https://example.com/v',
          preset: QualityPreset.best,
          outputDir: 'D:\\dl'));
      expect(launcher.lastArgs, isNot(contains('--cookies')));
    });

    test('download drain timeout falls back to captured filepath', () async {
      final ctrl = StreamController<String>();
      ctrl.add('D:\\dl\\Sample.mp4'); // filepath arrives; stream never closes
      final launcher = FakeLauncher(FakeAppProcess(
        stdout: ctrl.stream,
        exitCode: Future.value(0),
      ));
      final service = YtDlpService(
          launcher: launcher,
          locator: _stubLocator(temp),
          drainTimeout: const Duration(milliseconds: 50));

      final path = await service
          .download(DownloadRequest(
              url: 'https://example.com/v',
              preset: QualityPreset.best,
              outputDir: 'D:\\dl'))
          .timeout(const Duration(seconds: 5));
      expect(path, 'D:\\dl\\Sample.mp4');
    });
  });

  test('missing engine surfaces as engineMissing DownloadException', () async {
    // 指向不含 yt-dlp.exe 的空目录
    final empty = await Directory.systemTemp.createTemp('no_engine');
    addTearDown(() => empty.delete(recursive: true));
    final service = YtDlpService(
        launcher: FakeLauncher(FakeAppProcess(stdout: const Stream.empty())),
        locator: EngineLocator(baseDirOverride: empty.path));

    await expectLater(
        service.probe('https://example.com/v'),
        throwsA(isA<DownloadException>()
            .having((e) => e.kind, 'kind', EngineErrorKind.engineMissing)
            .having((e) => e.detail, 'detail', contains(empty.path))));
    await expectLater(
        service.download(DownloadRequest(
            url: 'https://example.com/v',
            preset: QualityPreset.best,
            outputDir: 'D:\\dl')),
        throwsA(isA<DownloadException>()
            .having((e) => e.kind, 'kind', EngineErrorKind.engineMissing)
            .having((e) => e.detail, 'detail', contains(empty.path))));
  });

  test('cancel kills the registered process tree', () async {
    final proc = FakeAppProcess(stdout: const Stream.empty());
    final launcher = FakeLauncher(proc);
    final service = YtDlpService(
        launcher: launcher, locator: _stubLocator(temp));
    final done = service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't7'));
    // download 在 launcher.start 恢复的微任务里才注册进程，且其退出后的
    // finally 会移除注册；恰等一个微任务，保证 cancel 落在注册窗口内
    await Future<void>.value();

    await service.cancel('t7');
    expect(proc.killTreeCalled, isTrue);
    // 取消后进程以非零码结束 → 友好异常（取消吞错由队列层负责）
    await expectLater(done, throwsA(isA<DownloadException>()));
  });

  test('cancel of unknown taskId is a no-op', () async {
    final service = YtDlpService(
        launcher: FakeLauncher(FakeAppProcess(stdout: const Stream.empty())),
        locator: _stubLocator(temp));
    await service.cancel('missing');
  });

  test('download falls back to engine ffmpeg path', () async {
    final launcher = FakeLauncher(FakeAppProcess(stdout: Stream.fromIterable([
      'D:\\dl\\X.mp4',
    ])));
    final locator = _stubLocatorWithFfmpeg(temp);
    final enginePath = p.join(
        temp.path, 'data', 'flutter_assets', 'assets', 'bin', 'ffmpeg.exe');
    final service = YtDlpService(launcher: launcher, locator: locator);

    await service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl'));
    expect(launcher.lastArgs,
        containsAllInOrder(['--ffmpeg-location', enginePath]));
    expect(launcher.lastArgs, contains('--no-warnings'));
    expect(launcher.lastArgs, contains('-o'));
  });

  test('cancel issued before registration still terminates the download',
      () async {
    final proc = _StickyProcess();
    final gate = Completer<void>();
    final launcher = _GatedLauncher(gate, proc);
    final service = YtDlpService(launcher: launcher, locator: _stubLocator(temp));
    final done = service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't9'));

    // 进程尚未注册（launcher.start 未放行）时发出取消
    await service.cancel('t9');
    gate.complete();

    // 注册时自检取消标志 → 自终止 → 下载 future 落定
    await expectLater(done.timeout(const Duration(seconds: 5)),
        throwsA(isA<DownloadException>()));
  });

  test('cancel survives a hanging killTree via kill fallback', () async {
    final proc = _HangingKillTreeProcess();
    final service =
        YtDlpService(launcher: FakeLauncher(proc), locator: _stubLocator(temp));
    final done = service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't9'));

    await Future<void>.value(); // 完成进程注册

    await service.cancel('t9');

    // killTree 挂起时，退出码等待 + kill 兜底必须让下载 future 落定
    await expectLater(done.timeout(const Duration(seconds: 5)),
        throwsA(isA<DownloadException>()));
  });

  test('injected kill timeouts settle cancel quickly', () async {
    final proc = _HangingKillTreeProcess();
    final service = YtDlpService(
        launcher: FakeLauncher(proc),
        locator: _stubLocator(temp),
        killTreeTimeout: const Duration(milliseconds: 20),
        killGrace: const Duration(milliseconds: 20));
    final done = service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't9'));
    await Future<void>.value();
    final sw = Stopwatch()..start();
    await service.cancel('t9');
    expect(sw.elapsedMilliseconds, lessThan(1500)); // 默认 3s+2s 不应被触发
    await expectLater(done.timeout(const Duration(seconds: 3)),
        throwsA(isA<DownloadException>()));
  });

  test('cancel falls back to kill when tree-kill does not terminate',
      () async {
    final proc = _StickyProcess();
    final service = YtDlpService(
        launcher: FakeLauncher(proc), locator: _stubLocator(temp));
    final done = service.download(DownloadRequest(
        url: 'https://example.com/v',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't9'));

    // 等待 download 完成进程注册（注册发生在首个 await 后的一个微任务）
    await Future<void>.value();

    await service.cancel('t9');

    // killTree 被拦截静默失败时，保底 kill() 必须让下载 future 落定
    await expectLater(done.timeout(const Duration(seconds: 3)),
        throwsA(isA<DownloadException>()));
  });

  test('cancel flag does not leak when spawn fails before registration',
      () async {
    final switchable = _SwitchableLauncher(_ThrowOnStartLauncher());
    final service =
        YtDlpService(launcher: switchable, locator: _stubLocator(temp));

    // 先附着错误监听，避免 rejected future 在微任务间隙被报告为未处理
    final firstExpect = expectLater(
        service.download(DownloadRequest(
            url: 'u',
            preset: QualityPreset.best,
            outputDir: 'D:\\dl',
            taskId: 't9')),
        throwsA(anything));
    await Future<void>.value(); // 进入 download，抵达 launcher.start
    await service.cancel('t9'); // 置标志（尚未注册）
    await firstExpect; // 启动失败

    // 同 id 重试：标志必须已清理，否则注册时自终止 → 未能定位输出文件
    switchable.active =
        FakeLauncher(FakeAppProcess(stdout: Stream.value('D:\\dl\\ok.mp4')));
    final path = await service.download(DownloadRequest(
        url: 'u',
        preset: QualityPreset.best,
        outputDir: 'D:\\dl',
        taskId: 't9'));
    expect(path, 'D:\\dl\\ok.mp4');
  });
}

/// start 可切换的实现：先抛启动失败，再切换到正常进程
class _SwitchableLauncher implements ProcessLauncher {
  _SwitchableLauncher(this.active);
  ProcessLauncher active;

  @override
  Future<AppProcess> start(String executable, List<String> arguments,
          {Map<String, String>? environment}) =>
      active.start(executable, arguments, environment: environment);
}

class _ThrowOnStartLauncher implements ProcessLauncher {
  @override
  Future<AppProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    throw const ProcessException('yt-dlp.exe', [], 'spawn failed');
  }
}

/// start 等待 gate 放行，模拟进程创建耗时的注册竞态窗口
class _GatedLauncher implements ProcessLauncher {
  _GatedLauncher(this.gate, this.process);
  final Completer<void> gate;
  final AppProcess process;

  @override
  Future<AppProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    await gate.future;
    return process;
  }
}

/// killTree 静默无效（模拟安全软件拦截 taskkill），仅 kill() 能使进程退出
class _StickyProcess implements AppProcess {
  final Completer<int> _exit = Completer<int>();

  @override
  int get pid => 1;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void kill() {
    if (!_exit.isCompleted) _exit.complete(1);
  }

  @override
  Future<void> killTree() async {}

  @override
  Stream<String> get stdout => const Stream.empty();

  @override
  Stream<String> get stderr => const Stream.empty();
}

/// killTree 永不返回（模拟 taskkill 挂起），仅 kill() 能使进程退出
class _HangingKillTreeProcess implements AppProcess {
  final Completer<int> _exit = Completer<int>();

  @override
  int get pid => 2;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void kill() {
    if (!_exit.isCompleted) _exit.complete(1);
  }

  @override
  Future<void> killTree() => Completer<void>().future;

  @override
  Stream<String> get stdout => const Stream.empty();

  @override
  Stream<String> get stderr => const Stream.empty();
}
