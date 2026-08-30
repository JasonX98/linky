// test/engine/process_launcher_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/engine/process_launcher.dart';

void main() {
  test('SystemProcessLauncher starts process and streams lines', () async {
    final launcher = SystemProcessLauncher();
    final proc = await launcher.start('cmd.exe', ['/c', 'echo', 'hello']);

    final lines = await proc.stdout.toList();
    expect(lines.first, 'hello');
    expect(await proc.exitCode, 0);
  });

  test('stderr is streamed as lines', () async {
    final launcher = SystemProcessLauncher();
    final proc = await launcher.start('cmd.exe', ['/c', 'echo', 'oops>&2']);
    final lines = await proc.stderr.toList();
    expect(lines.first, 'oops');
  });

  test('AppProcess exposes pid', () async {
    final launcher = SystemProcessLauncher();
    final proc = await launcher.start('cmd.exe', ['/c', 'echo', 'hi']);
    expect(proc.pid, greaterThan(0));
    await proc.exitCode;
  });

  test('killTree terminates the process tree', () async {
    final launcher = SystemProcessLauncher();
    // 30 秒的长任务，killTree 后必须立即退出
    final proc = await launcher
        .start('cmd.exe', ['/c', 'ping', '-n', '30', '127.0.0.1', '>nul']);
    await proc.killTree();
    var code = -1;
    var timedOut = false;
    try {
      code = await proc.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      timedOut = true;
    }
    expect(timedOut, isFalse,
        reason: 'killTree should terminate the whole process tree');
    expect(code, isNot(0));
  });
}
