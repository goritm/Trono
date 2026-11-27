import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trono/config/supabase_config.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/screens/social_screen.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/supabase_sync_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';

class _MemoryRepo implements BathroomRepository {
  final List<BathroomLog> _items = [];

  @override
  Future<void> clearAll() async => _items.clear();

  @override
  Future<List<BathroomLog>> getAllLogs() async => List.of(_items);

  @override
  Future<List<BathroomLog>> getAllLogsIncludingDeleted() async =>
      List.of(_items);

  @override
  Future<List<BathroomLog>> getPendingSyncLogs() async => const [];

  @override
  Future<void> markLogsSynced(List<String> ids) async {}

  @override
  Future<void> softDeleteLog(String id) async =>
      _items.removeWhere((e) => e.id == id);

  @override
  Future<void> upsertLog(BathroomLog log) async {
    _items.removeWhere((e) => e.id == log.id);
    _items.add(log);
  }

  @override
  Future<void> upsertLogsBatch(List<BathroomLog> logs) async {
    for (final l in logs) {
      await upsertLog(l);
    }
  }
}

class _FakeGoogleAuthService extends SupabaseSyncService {
  _FakeGoogleAuthService({
    this.launchResult = true,
    this.throwError,
  }) : super.forTesting();

  bool launchResult;
  Object? throwError;
  int googleSignInCalls = 0;
  bool _signedIn = false;

  @override
  bool get isInitialized => true;

  @override
  bool get isSignedIn => _signedIn;

  void simulateSignedIn() {
    _signedIn = true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCalls++;
    if (throwError != null) throw throwError!;
    return launchResult;
  }
}

Future<(TronoController, SocialController, _FakeGoogleAuthService)>
_buildControllers({
  bool launchResult = true,
  Object? throwError,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.init();
  final repo = _MemoryRepo();
  final trono = TronoController(
    repository: repo,
    settings: settings,
    updateChecker: UpdateCheckerService(
      settings: settings,
      currentVersionProvider: () async => '2.7.0',
      httpGet: (_) async => null,
    ),
    onTimerSynced: (_) async {},
    readExternalTimerStart: () async => null,
  );
  await trono.init();
  final fakeService = _FakeGoogleAuthService(
    launchResult: launchResult,
    throwError: throwError,
  );
  final social = SocialController(
    tronoController: trono,
    repository: repo,
    settings: settings,
    service: fakeService,
  );
  await social.init();
  return (trono, social, fakeService);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google OAuth Config & Display Name Resolver (V2.7 PR #27)', () {
    test('defines mobile deep-link redirect URL com.trono.trono://login-callback', () {
      expect(
        SupabaseConfig.oauthRedirectUrl,
        'com.trono.trono://login-callback',
      );
    });

    test('resolves display name priority and clamps to 32 chars', () {
      expect(
        SupabaseSyncService.resolveDisplayNameFromMetadata(
          {'display_name': '  El Rey  ', 'full_name': 'Jose Sandoval'},
          email: 'jose@example.com',
        ),
        'El Rey',
      );
      expect(
        SupabaseSyncService.resolveDisplayNameFromMetadata(
          {'full_name': 'Jose Sandoval', 'name': 'Jose'},
          email: 'jose@example.com',
        ),
        'Jose Sandoval',
      );
      expect(
        SupabaseSyncService.resolveDisplayNameFromMetadata(
          {'name': 'Maria'},
          email: 'maria@example.com',
        ),
        'Maria',
      );
      expect(
        SupabaseSyncService.resolveDisplayNameFromMetadata(
          const {},
          email: 'throne.king@example.com',
        ),
        'throne.king',
      );
      expect(
        SupabaseSyncService.resolveDisplayNameFromMetadata(const {}),
        'Trono',
      );
      final clamped = SupabaseSyncService.resolveDisplayNameFromMetadata(
        {'full_name': 'A Very Long Google Display Name Exceeding Thirty Two Chars'},
      );
      expect(clamped.length, 32);
    });
  });

  group('SocialController.signInWithGoogle (V2.7 PR #27)', () {
    test('delegates to SupabaseSyncService.signInWithGoogle', () async {
      final (trono, social, service) = await _buildControllers(
        launchResult: true,
      );
      addTearDown(() {
        social.dispose();
        trono.dispose();
      });

      final launched = await social.signInWithGoogle();
      expect(launched, isTrue);
      expect(service.googleSignInCalls, 1);
    });
  });

  group('AuthSheet Continue with Google UI (V2.7 PR #27)', () {
    testWidgets(
      'shows Continue with Google (EN), launches OAuth, shows handoff hint, and auto-closes on sign-in',
      (tester) async {
        final (trono, social, service) = (await tester.runAsync(
          () => _buildControllers(launchResult: true),
        ))!;
        addTearDown(() {
          social.dispose();
          trono.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => showAuthSheet(ctx, social),
                    child: const Text('Open Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Auth'));
        await tester.pumpAndSettle();

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('or with email'), findsOneWidget);

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(service.googleSignInCalls, 1);
        expect(find.textContaining('browser'), findsOneWidget);

        // Simulate deep-link callback completing sign-in
        service.simulateSignedIn();
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        social.notifyListeners();
        await tester.pumpAndSettle();

        // Auth sheet auto-dismisses once signed in
        expect(find.text('Continue with Google'), findsNothing);
      },
    );

    testWidgets(
      'renders Spanish parity copy and surfaces AuthException cleanly',
      (tester) async {
        final (trono, social, _) = (await tester.runAsync(
          () => _buildControllers(
            throwError: const AuthException('Google provider disabled'),
          ),
        ))!;
        addTearDown(() {
          social.dispose();
          trono.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        showAuthSheet(ctx, social, initialSignUp: false),
                    child: const Text('Abrir Auth'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Abrir Auth'));
        await tester.pumpAndSettle();

        expect(find.text('Continuar con Google'), findsOneWidget);
        expect(find.text('o con correo'), findsOneWidget);

        await tester.tap(find.text('Continuar con Google'));
        await tester.pumpAndSettle();

        expect(find.text('Google provider disabled'), findsOneWidget);
        // Sheet stays open & interactive so user can retry or use email
        expect(find.text('Continuar con Google'), findsOneWidget);
      },
    );
  });
}
