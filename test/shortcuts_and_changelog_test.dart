import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/app_update.dart';
import 'package:trono/services/app_shortcut_service.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/update_banner_card.dart';

void main() {
  group('AppShortcutAction & AppShortcutService (V2.5)', () {
    test('parses valid shortcut identifiers and rejects invalid ones', () {
      expect(
        AppShortcutAction.tryParse('claim_throne'),
        AppShortcutAction.claimThrone,
      );
      expect(
        AppShortcutAction.tryParse('start_timer'),
        AppShortcutAction.startTimer,
      );
      expect(AppShortcutAction.tryParse('  claim_throne '), AppShortcutAction.claimThrone);
      expect(AppShortcutAction.tryParse('unknown'), isNull);
      expect(AppShortcutAction.tryParse(''), isNull);
      expect(AppShortcutAction.tryParse(null), isNull);
    });

    test('consumes initial shortcut and handles live warm-start callbacks', () async {
      final received = <AppShortcutAction>[];
      const testChannel = MethodChannel('com.trono.trono/shortcuts_test');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
            if (call.method == 'getInitialShortcut') {
              return 'claim_throne';
            }
            return null;
          });

      final service = AppShortcutService(channel: testChannel);
      final initial = await service.consumeInitialShortcut();
      expect(initial, AppShortcutAction.claimThrone);

      service.startListening(received.add);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            testChannel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onShortcut', 'start_timer'),
            ),
            (_) {},
          );

      expect(received, [AppShortcutAction.startTimer]);
      service.dispose();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });

    test('handles MissingPluginException gracefully without throwing', () async {
      const missingChannel = MethodChannel('com.trono.trono/nonexistent_test');
      final service = AppShortcutService(channel: missingChannel);
      expect(await service.consumeInitialShortcut(), isNull);
    });
  });

  group('ReleaseNotesFormatter (V2.5)', () {
    test('cleans markdown headings, bullets, bold, inline code, and links', () {
      const raw = '''
## What's Changed
* **Trigger Lab** — correlate food tags vs Bristol scale
- Added [Android App Shortcuts](https://github.com/goritm/Trono) (`claim_throne`)
-   

### Full Changelog
https://github.com/goritm/Trono/compare/v2.3.0...v2.4.0
''';

      final lines = ReleaseNotesFormatter.extractLines(raw);
      expect(lines, [
        "What's Changed",
        'Trigger Lab — correlate food tags vs Bristol scale',
        'Added Android App Shortcuts (claim_throne)',
        'Full Changelog',
      ]);
    });

    test('returns empty list for null or blank notes', () {
      expect(ReleaseNotesFormatter.extractLines(null), isEmpty);
      expect(ReleaseNotesFormatter.extractLines('   \n\n  '), isEmpty);
    });
  });

  group('UpdateBannerCard & Release Notes Sheet (V2.5)', () {
    testWidgets('hides What’s New button when releaseNotes is null', (tester) async {
      const release = AppReleaseInfo(
        tagName: 'v2.5.0',
        version: SemVer(2, 5, 0),
        downloadUrl: 'https://github.com/goritm/Trono/releases/download/v2.5.0/trono-v2.5.0.apk',
        isDirectApk: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(
            body: UpdateBannerCard(
              release: release,
              onDownload: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('update_banner_notes_btn')), findsNothing);
    });

    testWidgets('opens Release Notes sheet and triggers download CTA', (tester) async {
      int downloads = 0;
      const release = AppReleaseInfo(
        tagName: 'v2.5.0',
        version: SemVer(2, 5, 0),
        downloadUrl: 'https://github.com/goritm/Trono/releases/download/v2.5.0/trono-v2.5.0.apk',
        isDirectApk: true,
        releaseNotes: '- **Trigger Lab** correlations\n- Native Android App Shortcuts',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(
            body: UpdateBannerCard(
              release: release,
              onDownload: () => downloads++,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('update_banner_notes_btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update_banner_notes_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Trigger Lab correlations'), findsOneWidget);
      expect(find.text('Native Android App Shortcuts'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('release_notes_download_btn')));
      await tester.pumpAndSettle();
      expect(downloads, 1);
    });
  });
}
