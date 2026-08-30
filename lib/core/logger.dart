// lib/core/logger.dart
import 'package:flutter/foundation.dart';

typedef LogSink = Future<void> Function(String message);

class Logger {
  static LogSink? _sink;

  /// 附加日志落盘 sink。debugPrint 恒开，sink 仅追加；
  /// sink 抛错在 [log] 内静默吸收，绝不阻断调用方。
  static void attach(LogSink sink) {
    _sink = sink;
  }

  static Future<void> log(String message) async {
    debugPrint(message);
    final sink = _sink;
    if (sink == null) return;
    try {
      await sink(message);
    } catch (_) {
      // sink 异常静默：日志失败不得影响业务链路
    }
  }
}
