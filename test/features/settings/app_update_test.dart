// test/features/settings/app_update_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/features/settings/app_update.dart';

void main() {
  group('AppVersion', () {
    test('parses v prefix and strips +build suffix', () {
      final a = AppVersion.tryParse('v1.0.4');
      expect(a, isNotNull);
      expect(a!.toString(), '1.0.4');
      expect(a.parts, [1, 0, 4]);

      final b = AppVersion.tryParse('1.0.3+0');
      expect(b, isNotNull);
      expect(b!.toString(), '1.0.3');
    });

    test('rejects invalid version strings', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('v'), isNull);
      expect(AppVersion.tryParse('not-a-version'), isNull);
      expect(AppVersion.tryParse('1.a.3'), isNull);
    });

    test('isNewerThan compares segments, missing segment treated as 0', () {
      final current = AppVersion.tryParse('1.0.3')!;
      final newer = AppVersion.tryParse('v1.0.4')!;
      expect(newer.isNewerThan(current), isTrue);
      expect(current.isNewerThan(newer), isFalse);

      final withPatch = AppVersion.tryParse('1.0.4.1')!;
      final noPatch = AppVersion.tryParse('1.0.4')!;
      expect(withPatch.isNewerThan(noPatch), isTrue);
    });

    test('same major.minor.patch is not newer (ignores +build)', () {
      final a = AppVersion.tryParse('v1.0.3')!;
      final b = AppVersion.tryParse('1.0.3+0')!;
      expect(a.isNewerThan(b), isFalse);
      expect(a == b, isTrue);
    });
  });

  group('AppUpdateService.checkForUpdate', () {
    test('returns available when latest is newer', () async {
      final svc = AppUpdateService(
        currentVersion: '1.0.3',
        fetchLatest: () async =>
            const AppRelease(version: '1.0.4', releaseUrl: 'https://x/r'),
      );
      final res = await svc.checkForUpdate();
      expect(res, isA<AppUpdateAvailable>());
      expect((res as AppUpdateAvailable).release.version, '1.0.4');
    });

    test('returns upToDate when major.minor.patch match', () async {
      final svc = AppUpdateService(
        currentVersion: '1.0.3+0',
        fetchLatest: () async =>
            const AppRelease(version: 'v1.0.3', releaseUrl: 'https://x/r'),
      );
      final res = await svc.checkForUpdate();
      expect(res, isA<AppUpdateUpToDate>());
    });

    test('fails gracefully when fetchLatest throws', () async {
      final svc = AppUpdateService(
        currentVersion: '1.0.3',
        fetchLatest: () async => throw Exception('boom'),
      );
      final res = await svc.checkForUpdate();
      expect(res, isA<AppUpdateFailed>());
    });

    test('fails gracefully when fetchLatest returns null', () async {
      final svc = AppUpdateService(
        currentVersion: '1.0.3',
        fetchLatest: () async => null,
      );
      final res = await svc.checkForUpdate();
      expect(res, isA<AppUpdateFailed>());
    });
  });

  group('AppUpdateService.openReleasePage', () {
    test('calls injected openUrl with the release url', () async {
      final urls = <String>[];
      final svc = AppUpdateService(openUrl: (u) async => urls.add(u));
      await svc.openReleasePage(const AppRelease(
          version: '1.0.4', releaseUrl: 'https://x/releases/v1.0.4'));
      expect(urls, ['https://x/releases/v1.0.4']);
    });
  });
}
