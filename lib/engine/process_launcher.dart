// lib/engine/process_launcher.dart
import 'dart:convert';
import 'dart:io';

import 'package:video_downloader/core/logger.dart';

abstract class AppProcess {
  Stream<String> get stdout;
  Stream<String> get stderr;
  Future<int> get exitCode;
  void kill();
  int get pid;
  Future<void> killTree();
}

abstract class ProcessLauncher {
  Future<AppProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });
}

class SystemProcessLauncher implements ProcessLauncher {
  const SystemProcessLauncher();

  @override
  Future<AppProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final proc = await Process.start(
      executable,
      arguments,
      environment: environment,
      mode: ProcessStartMode.normal,
    );
    return _SystemAppProcess(proc);
  }
}

class _SystemAppProcess implements AppProcess {
  _SystemAppProcess(Process proc)
      : stdout = proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        stderr = proc.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        _exitCode = proc.exitCode,
        _proc = proc;

  final Process _proc;
  final Future<int> _exitCode;

  @override
  final Stream<String> stdout;

  @override
  final Stream<String> stderr;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  void kill() {
    _proc.kill();
  }

  @override
  int get pid => _proc.pid;

  @override
  Future<void> killTree() async {
    // /T 终止整棵进程树（含 ffmpeg 合并子进程），/F 强制；忽略退出码：
    // 进程可能已自行退出，此时 taskkill 报错属预期
    final res =
        await Process.run('taskkill', ['/PID', _proc.pid.toString(), '/T', '/F']);
    // 记录 taskkill 结果（退出码/stdout/stderr），failure 属预期、仅留痕
    await Logger.log(
        'taskkill(pid=${_proc.pid}) exit=${res.exitCode} '
        'stdout=${res.stdout} stderr=${res.stderr}');
  }
}
