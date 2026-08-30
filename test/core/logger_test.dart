// test/core/logger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/core/logger.dart';

void main() {
  test('log delivers to attached sink and swallows sink errors', () async {
    final received = <String>[];
    Logger.attach((m) async => received.add(m));
    await Logger.log('hello world');
    expect(received, ['hello world']);

    // sink 抛错不影响 log
    Logger.attach((_) async => throw StateError('sink down'));
    await Logger.log('still ok');
  });
}
