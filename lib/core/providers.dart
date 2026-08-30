// lib/core/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用启动时由 main 注入的 SharedPreferences（测试中 override 为内存实例）。
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
