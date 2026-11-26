import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/app_update.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/update_banner_card.dart';

void main() {
  group('SemVer parsing & comparison', () {
    test('parses prefixes, build metadata, and compares numerically', () {
      final v230 = SemVer.tryParse('2.3.0')!;
      final v240 = SemVer.tryParse('v2.4.0+4')!;
      final v299 = SemVer.tryParse('v2.9.9')!;
      final v2100 = SemVer.tryParse('v2.10.0')!;
      final v300 = SemVer.tryParse('3.0.0')!;

      expect(v240.major, 2);
      expect(v240.minor, 4);
      expect(v240.patch, 0);
      expect(v240.isNewerThan(v230), isTrue);
      expect(v230.isNewerThan(v240), isFalse);
      expect(v240.isNewerThan(SemVer.tryParse('2.4.0')!), isFalse);
      // Multi-digit numeric comparison (2.10.0 > 2.9.9)
      expect(v2100.isNewerThan(v299), isTrue);
      expect(v300.isNewerThan(v2100), isTrue);
    });

    test('returns null for malformed tags', () {
      expect(SemVer.tryParse(''), isNull);
      expect(SemVer.tryParse('nightly'), isNull);
      expect(SemVer.tryParse('v2.4'), isNull);
      expect(SemVer.tryParse('v2.a.0'), isNull);
    });
  });

  group('AppUpdateParser (GitHub Releases JSON)', () {
    test('prefers .apk asset browser_download_url and detects newer release', () {
      final payload = jsonEncode({
        'tag_name': 'v2.4.0',
        'name': 'Trono v2.4.0 👑',
        'draft': false,
        'prerelease': false,
        'html_url': 'https://github.com/goritm/Trono/releases/tag/v2.4.0',
        'body': 'Aviso automático de actualización in-app',
        'assets': [
          {
            'name': 'checksums.txt',
            'browser_download_url': 'https://example.com/checksums.txt',
          },
          {
            'name': 'trono-v2.4.0.apk',
            'browser_download_url':
                'https://github.com/goritm/Trono/releases/download/v2.4.0/trono-v2.4.0.apk',
          },
        ],
      });

      final info = AppUpdateParser.parseLatestRelease(payload);
      expect(info, isNotNull);
      expect(info!.tagName, 'v2.4.0');
      expect(info.version.toString(), '2.4.0');
      expect(
        info.downloadUrl,
        'https://github.com/goritm/Trono/releases/download/v2.4.0/trono-v2.4.0.apk',
      );
      expect(info.isDirectApk, isTrue);
      expect(info.isNewerThan('2.3.0'), isTrue);
      expect(info.isNewerThan('2.4.0'), isFalse);
      expect(info.isNewerThan('2.5.0'), isFalse);
    });

    test('falls back to html_url when no .apk asset is attached', () {
      final payload = jsonEncode({
        'tag_name': 'v2.4.1',
        'draft': false,
        'prerelease': false,
        'html_url': 'https://github.com/goritm/Trono/releases/tag/v2.4.1',
        'assets': [],
      });

      final info = AppUpdateParser.parseLatestRelease(payload);
      expect(info, isNotNull);
      expect(
        info!.downloadUrl,
        'https://github.com/goritm/Trono/releases/tag/v2.4.1',
      );
      expect(info.isDirectApk, isFalse);
    });

    test('ignores draft, prerelease, or invalid JSON', () {
      final draft = jsonEncode({
        'tag_name': 'v2.5.0',
        'draft': true,
        'prerelease': false,
        'html_url': 'https://github.com/goritm/Trono/releases/tag/v2.5.0',
      });
      final pre = jsonEncode({
        'tag_name': 'v2.5.0',
        'draft': false,
        'prerelease': true,
        'html_url': 'https://github.com/goritm/Trono/releases/tag/v2.5.0',
      });

      expect(AppUpdateParser.parseLatestRelease(draft), isNull);
      expect(AppUpdateParser.parseLatestRelease(pre), isNull);
      expect(AppUpdateParser.parseLatestRelease('{not json'), isNull);
    });
  });

  group('UpdateCheckerService (throttle, dismissal & offline safety)', () {
    String releaseJson(String tag) => jsonEncode({
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'html_url': 'https://github.com/goritm/Trono/releases/tag/$tag',
      'assets': [
        {
          'name': 'trono-$tag.apk',
          'browser_download_url':
              'https://github.com/goritm/Trono/releases/download/$tag/trono-$tag.apk',
        },
      ],
    });

    test('enforces 12h auto-check throttle, allows force bypass, and tracks dismissal per tag', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();

      int fetchCalls = 0;
      String currentTag = 'v2.4.0';
      DateTime clock = DateTime(2026, 11, 26, 10, 0);

      final service = UpdateCheckerService(
        settings: settings,
        currentVersionProvider: () async => '2.3.0',
        httpGet: (_) async {
          fetchCalls++;
          return releaseJson(currentTag);
        },
        nowProvider: () => clock,
      );

      // 1st automatic check fetches & finds v2.4.0
      final r1 = await service.checkForUpdate(force: false);
      expect(fetchCalls, 1);
      expect(r1.status, UpdateCheckStatus.updateAvailable);
      expect(r1.release?.tagName, 'v2.4.0');
      expect(service.shouldShowHomeBanner(r1.release), isTrue);

      // 2 hours later -> automatic check is throttled (0 extra network calls)
      clock = clock.add(const Duration(hours: 2));
      final r2 = await service.checkForUpdate(force: false);
      expect(fetchCalls, 1);
      expect(r2.status, UpdateCheckStatus.throttled);

      // Dismiss v2.4.0 -> home banner hidden for v2.4.0, but still returned on manual force check
      await service.dismissRelease('v2.4.0');
      expect(service.shouldShowHomeBanner(r1.release), isFalse);

      final rForced = await service.checkForUpdate(force: true);
      expect(fetchCalls, 2);
      expect(rForced.status, UpdateCheckStatus.updateAvailable);

      // 13 hours later with a newer v2.5.0 -> banner re-appears!
      currentTag = 'v2.5.0';
      clock = clock.add(const Duration(hours: 13));
      final r3 = await service.checkForUpdate(force: false);
      expect(fetchCalls, 3);
      expect(r3.release?.tagName, 'v2.5.0');
      expect(service.shouldShowHomeBanner(r3.release), isTrue);
    });

    test('handles offline / network error gracefully without throwing', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();

      final service = UpdateCheckerService(
        settings: settings,
        currentVersionProvider: () async => '2.3.0',
        httpGet: (_) async => throw Exception('No internet'),
      );

      final result = await service.checkForUpdate(force: true);
      expect(result.status, UpdateCheckStatus.failed);
      expect(result.release, isNull);
    });
  });

  group('UpdateBannerCard widget', () {
    testWidgets('renders tag and invokes download & dismiss callbacks', (tester) async {
      bool downloaded = false;
      bool dismissed = false;

      final release = AppReleaseInfo(
        tagName: 'v2.4.0',
        version: SemVer.tryParse('2.4.0')!,
        downloadUrl: 'https://github.com/goritm/Trono/releases/download/v2.4.0/trono-v2.4.0.apk',
        isDirectApk: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UpdateBannerCard(
                release: release,
                onDownload: () => downloaded = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('v2.4.0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update_banner_download_btn')));
      expect(downloaded, isTrue);

      await tester.tap(find.byKey(const ValueKey('update_banner_dismiss_btn')));
      expect(dismissed, isTrue);
    });
  });
}
