// lib/engine/yt_dlp_service.dart
import 'dart:async';
import 'dart:io';

import 'package:video_downloader/core/logger.dart';
import 'package:video_downloader/engine/engine_locator.dart';
import 'package:video_downloader/engine/models.dart';
import 'package:video_downloader/engine/process_launcher.dart';
import 'package:video_downloader/engine/yt_dlp_parser.dart';
import 'package:path/path.dart' as p;

class YtDlpService {
  YtDlpService({
    ProcessLauncher? launcher,
    EngineLocator? locator,
    this.probeTimeout = const Duration(seconds: 60),
    // 排空宽限 5s：正常 EOF 远快于此；被杀进程的管道若被残留句柄拖住，
    // 5s 后以已捕获内容继续，避免取消后的状态落定被无限拖延
    this.drainTimeout = const Duration(seconds: 5),
    // killTreeTimeout：taskkill 自身可能在安全软件/系统调用卡顿下挂起，
    // 超时后放弃等待；killGrace：树终止被静默拦截时等待退出的宽限，
    // 超时后回退单进程终止。二者可在测试中注入小值使取消快速落定。
    this.killTreeTimeout = const Duration(seconds: 3),
    this.killGrace = const Duration(seconds: 2),
  })  : launcher = launcher ?? const SystemProcessLauncher(),
        locator = locator ?? EngineLocator();

  final ProcessLauncher launcher;
  final EngineLocator locator;
  final Duration probeTimeout;
  final Duration drainTimeout;
  final Duration killTreeTimeout;
  final Duration killGrace;

  final Map<String, AppProcess> _active = {};
  final Set<String> _cancelRequested = {};

  Future<void> cancel(String taskId) async {
    // 先置标志：进程可能尚未注册（download 在首个 await 后才登记），
    // 注册时自检此标志即可覆盖"启动前取消"的竞态窗口
    _cancelRequested.add(taskId);
    final proc = _active.remove(taskId);
    if (proc == null) return;
    await _terminate(proc);
  }

  Future<void> _terminate(AppProcess proc) async {
    // 不 await：日志不参与取消落定的关键路径，避免多出微任务扰动时序
    // （done 的错误若先被报告为 unhandled 会令既有取消测试出现竞争失败）
    unawaited(Logger.log('terminate(pid=${proc.pid}): killing process tree'));
    try {
      // taskkill 自身也可能挂起（安全软件/系统调用卡顿）：
      // 超时后放弃等待，回退单进程终止，保证取消全链路可注入落定
      await proc.killTree().timeout(killTreeTimeout);
    } on ProcessException {
      // 尽力而为：taskkill 失败（如进程已自行退出）不阻断取消流程
    } on TimeoutException {
      // killTree 挂起：直接进入下方退出码等待 + kill 兜底
    }
    // 树终止可能被安全软件静默拦截：killGrace 内未退出则回退单进程终止，
    // 保证下载 future 一定落定（队列的 canceling 状态依赖它）
    try {
      await proc.exitCode.timeout(killGrace);
    } on TimeoutException {
      proc.kill();
    } catch (_) {
      // exitCode 已失败（进程已亡），无需处理
    }
  }

  /// 引擎缺失在服务边界统一转为 DownloadException(engineMissing)，
  /// 让队列层与分析层都能拿到结构化错误
  ResolvedEngine _resolveEngine() {
    try {
      return locator.resolve();
    } on EngineMissingException catch (e) {
      throw DownloadException(EngineErrorKind.engineMissing, e.path);
    }
  }

  static Future<void> _awaitDrain(
      Completer<void> a, Completer<void> b, Duration limit) {
    return Future.wait([a.future, b.future]).timeout(limit);
  }

  Future<AnalysisResult> probe(String url, {String? cookieFile}) async {
    final engine = _resolveEngine();
    final proc = await launcher.start(
      engine.ytDlpPath,
      // --encoding utf-8：PyInstaller 打包的 yt-dlp.exe 会忽略
      // PYTHONIOENCODING/PYTHONUTF8，中文 locale 下 stdout 会回退 GBK，
      // 中文文件名/标题必须用该参数强制 UTF-8（实测验证）。
      [
        '--dump-single-json',
        '--flat-playlist',
        '--encoding', 'utf-8',
        '--no-warnings',
        if (cookieFile != null && cookieFile.isNotEmpty) ...['--cookies', cookieFile],
        url,
      ],
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    void settle(Completer<void> c) {
      if (!c.isCompleted) c.complete();
    }

    final subs = <StreamSubscription<String>>[
      proc.stdout.listen(
        stdoutBuf.write,
        onDone: () => settle(stdoutDone),
        onError: (Object _) => settle(stdoutDone),
      ),
      proc.stderr.listen(
        stderrBuf.write,
        onDone: () => settle(stderrDone),
        onError: (Object _) => settle(stderrDone),
      ),
    ];
    int code;
    try {
      code = await proc.exitCode.timeout(probeTimeout);
    } on TimeoutException {
      proc.kill();
      await Future.wait(subs.map((s) => s.cancel()));
      throw const DownloadException(EngineErrorKind.timeout);
    }
    try {
      await _awaitDrain(stdoutDone, stderrDone, probeTimeout);
    } on TimeoutException {
      proc.kill();
      await Future.wait(subs.map((s) => s.cancel()));
      throw const DownloadException(EngineErrorKind.timeout);
    }
    await Future.wait(subs.map((s) => s.cancel()));
    if (code != 0) {
      final cls = classifyYtDlpError(stderrBuf.toString());
      throw DownloadException(cls.kind, cls.detail);
    }
    try {
      return parseAnalysisJson(stdoutBuf.toString());
    } on FormatException {
      throw DownloadException(EngineErrorKind.parseFailed, stdoutBuf.toString());
    } on TypeError {
      throw DownloadException(EngineErrorKind.parseFailed, stdoutBuf.toString());
    }
  }

  List<String> _buildDownloadArgs(DownloadRequest request, ResolvedEngine engine) {
    final ffmpeg = request.ffmpegPath ?? engine.ffmpegPath;
    return [
      '-f', request.preset.formatSelector,
      '--merge-output-format', 'mp4',
      '--newline',
      '--progress',
      '--no-simulate',
      '--progress-template',
      'download:PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
      '--encoding', 'utf-8',
      '--no-warnings',
      '--print', 'after_move:filepath',
      '-o', p.join(request.outputDir, '%(title)s.%(ext)s'),
      if (ffmpeg != null) ...['--ffmpeg-location', ffmpeg],
      if (request.cookieFile != null && request.cookieFile!.isNotEmpty)
        ...['--cookies', request.cookieFile!],
      request.url,
    ];
  }

  Future<String> download(
    DownloadRequest request, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final engine = _resolveEngine();
    final taskId = request.taskId;
    AppProcess? proc;
    try {
      proc = await launcher.start(
        engine.ytDlpPath,
        _buildDownloadArgs(request, engine),
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );
      if (taskId != null) {
        _active[taskId] = proc;
        // 注册前已被 cancel：立即自终止，下载 future 以非零码落定
        if (_cancelRequested.remove(taskId)) {
          await _terminate(proc);
        }
      }
      return await _downloadWithProcess(request, proc, onProgress);
    } finally {
      if (taskId != null) {
        _active.remove(taskId);
        // 启动失败也必须清标志，否则同 id 重试会被残留标志自终止
        _cancelRequested.remove(taskId);
      }
    }
  }

  Future<String> _downloadWithProcess(
    DownloadRequest request,
    AppProcess proc,
    void Function(DownloadProgress)? onProgress,
  ) async {
      String? filePath;
      final stderrBuf = StringBuffer();
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      void settle(Completer<void> c) {
        if (!c.isCompleted) c.complete();
      }

      final subs = <StreamSubscription<String>>[
        proc.stdout.listen(
          (line) {
            final progress = parseProgressLine(line);
            if (progress != null) {
              onProgress?.call(progress);
              return;
            }
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('[')) return;
            filePath = trimmed;
          },
          onDone: () => settle(stdoutDone),
          onError: (Object _) => settle(stdoutDone),
        ),
        proc.stderr.listen(
          stderrBuf.writeln,
          onDone: () => settle(stderrDone),
          onError: (Object _) => settle(stderrDone),
        ),
      ];
      final code = await proc.exitCode;
      try {
        await _awaitDrain(stdoutDone, stderrDone, drainTimeout);
      } on TimeoutException {
        // 进程已退出但句柄未释放：以已捕获内容继续，不使任务永久挂起
      }
      await Future.wait(subs.map((s) => s.cancel()));
      if (code != 0) {
        final cls = classifyYtDlpError(stderrBuf.toString());
        throw DownloadException(cls.kind, cls.detail);
      }
      final path = filePath;
      if (path == null || path.isEmpty) {
        throw const DownloadException(EngineErrorKind.outputFileMissing);
      }
      return path;
  }
}
