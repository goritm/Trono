import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/push_notification_config.dart';
import 'package:trono/screens/settings_screen.dart';
import 'package:trono/services/push_notification_service.dart';
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

class _FakePushSupabaseService extends SupabaseSyncService {
  _FakePushSupabaseService({this.signedIn = true}) : super.forTesting();

  bool signedIn;
  final List<Map<String, Object?>> upsertedTokens = [];
  final List<String> deletedTokens = [];

  @override
  bool get isInitialized => true;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<void> upsertMyPushToken({
    required String token,
    required String locale,
    required SocialNotificationPrefs prefs,
    String platform = 'android',
  }) async {
    upsertedTokens.add({
      'token': token,
      'locale': locale,
      'platform': platform,
      ...prefs.toPlatformMap(),
    });
  }

  @override
  Future<void> deletePushToken(String token) async {
    deletedTokens.add(token);
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocialNotificationChannel & SocialNotificationPrefs (V2.8 PR #28)', () {
    test('defines exact stable Android NotificationChannel IDs', () {
      expect(
        SocialNotificationChannel.friendThrones.channelId,
        'trono_friend_thrones',
      );
      expect(
        SocialNotificationChannel.friendComments.channelId,
        'trono_friend_comments',
      );
      expect(
        SocialNotificationChannel.friendReactions.channelId,
        'trono_friend_reactions',
      );
    });

    test('defaults all 3 categories to enabled and supports independent copyWith', () {
      const defaults = SocialNotificationPrefs();
      expect(defaults.friendThrones, isTrue);
      expect(defaults.friendComments, isTrue);
      expect(defaults.friendReactions, isTrue);

      final mutedComments = defaults.copyWith(friendComments: false);
      expect(mutedComments.friendThrones, isTrue);
      expect(mutedComments.friendComments, isFalse);
      expect(mutedComments.friendReactions, isTrue);
      expect(mutedComments.toPlatformMap(), {
        'notifyFriendThrones': true,
        'notifyFriendComments': false,
        'notifyFriendReactions': true,
      });
    });
  });

  group('PushNotificationService MethodChannel bridge (V2.8 PR #28)', () {
    const channel = MethodChannel('com.trono.trono/push_test');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'getFcmToken' => 'fake_fcm_token_1234567890abcdef',
              'openNotificationSettings' => true,
              'getInitialOpenTab' => 'social',
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes ensureChannels, getFcmToken, openNotificationSettings & getInitialOpenTab', () async {
      final service = PushNotificationService(channel: channel);

      await service.ensureChannels(
        locale: const Locale('es'),
        prefs: const SocialNotificationPrefs(friendReactions: false),
      );
      final token = await service.getFcmToken();
      final opened = await service.openSystemNotificationSettings(
        channelId: SocialNotificationChannel.friendComments.channelId,
      );
      final tab = await service.consumeInitialOpenTab();

      expect(token, 'fake_fcm_token_1234567890abcdef');
      expect(opened, isTrue);
      expect(tab, 'social');
      expect(calls.map((c) => c.method).toList(), [
        'ensureChannels',
        'getFcmToken',
        'openNotificationSettings',
        'getInitialOpenTab',
      ]);
      final ensureArgs = Map<String, Object?>.from(calls.first.arguments as Map);
      expect(ensureArgs['locale'], 'es');
      expect(ensureArgs['notifyFriendReactions'], isFalse);
    });

    test('gracefully no-ops when native push channel is missing', () async {
      const missing = MethodChannel('com.trono.trono/push_missing');
      final service = PushNotificationService(channel: missing);

      await expectLater(
        service.ensureChannels(
          locale: const Locale('en'),
          prefs: const SocialNotificationPrefs(),
        ),
        completes,
      );
      expect(await service.getFcmToken(), isNull);
      expect(await service.openSystemNotificationSettings(), isFalse);
      expect(await service.consumeInitialOpenTab(), isNull);
    });

    test('delivers live token refresh and open-tab callbacks from native Android', () async {
      final service = PushNotificationService(channel: channel);
      final tokens = <String>[];
      final tabs = <String>[];
      service.startListening(
        onTokenRefresh: tokens.add,
        onOpenTab: tabs.add,
      );

      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(
          const MethodCall('onFcmToken', 'refreshed_token_0987654321xyz'),
        ),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('onOpenTab', 'social')),
        (_) {},
      );

      expect(tokens, ['refreshed_token_0987654321xyz']);
      expect(tabs, ['social']);
      service.dispose();
    });
  });

  group('SocialController Push Token & Prefs Sync + Settings UI (V2.8 PR #28)', () {
    test('syncs FCM token + prefs on init/update and deletes token on signOut', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final repo = _MemoryRepo();

      const testChannel = MethodChannel('com.trono.trono/push_ctrl_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
            if (call.method == 'getFcmToken') {
              return 'device_fcm_token_abcdef1234567890';
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, null);
      });

      final pushService = PushNotificationService(channel: testChannel);
      final trono = TronoController(
        repository: repo,
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.8.0',
          httpGet: (_) async => null,
        ),
        onTimerSynced: (_) async {},
        readExternalTimerStart: () async => null,
      );
      await trono.init();

      final fakeSupa = _FakePushSupabaseService(signedIn: true);
      final social = SocialController(
        tronoController: trono,
        repository: repo,
        settings: settings,
        service: fakeSupa,
        pushService: pushService,
      );
      await social.init();
      await social.syncPushTokenNow();

      expect(fakeSupa.upsertedTokens, isNotEmpty);
      expect(
        fakeSupa.upsertedTokens.last['token'],
        'device_fcm_token_abcdef1234567890',
      );
      expect(fakeSupa.upsertedTokens.last['notifyFriendComments'], isTrue);

      // Disable comments only -> updates local settings + syncs to Supabase
      await social.setSocialNotificationPrefs(
        social.socialNotificationPrefs.copyWith(friendComments: false),
      );
      expect(social.socialNotificationPrefs.friendComments, isFalse);
      expect(social.socialNotificationPrefs.friendThrones, isTrue);
      expect(fakeSupa.upsertedTokens.last['notifyFriendComments'], isFalse);

      // Sign out -> removes device token from Supabase
      await social.signOut();
      expect(fakeSupa.deletedTokens, ['device_fcm_token_abcdef1234567890']);

      social.dispose();
      trono.dispose();
    });

    testWidgets(
      'SettingsScreen renders 3 social push toggles + Android channel settings button in EN & ES',
      (tester) async {
        const testChannel = MethodChannel('com.trono.trono/push_ui_test');
        final openedCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              openedCalls.add(call);
              if (call.method == 'openNotificationSettings') return true;
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(testChannel, null);
        });

        final bundle = (await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsService();
          await settings.init();
          final repo = _MemoryRepo();
          final trono = TronoController(
            repository: repo,
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.0',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await trono.init();
          final social = SocialController(
            tronoController: trono,
            repository: repo,
            settings: settings,
            service: _FakePushSupabaseService(signedIn: false),
            pushService: PushNotificationService(channel: testChannel),
          );
          await social.init();
          return (trono, social);
        }))!;
        final (trono, social) = bundle;
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
            home: SettingsScreen(controller: trono, social: social),
          ),
        );
        await tester.pumpAndSettle();

        final listFinder = find.byType(Scrollable).first;
        final commentsSwitch = find.byKey(
          const ValueKey('push_friend_comments_switch'),
        );
        await tester.scrollUntilVisible(
          commentsSwitch,
          300,
          scrollable: listFinder,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('push_friend_thrones_switch')),
          findsOneWidget,
        );
        expect(commentsSwitch, findsOneWidget);
        expect(
          find.byKey(const ValueKey('push_friend_reactions_switch')),
          findsOneWidget,
        );

        await tester.tap(commentsSwitch);
        await tester.pumpAndSettle();
        expect(social.socialNotificationPrefs.friendComments, isFalse);

        final androidSettingsTile = find.byKey(
          const ValueKey('open_android_notif_settings_tile'),
        );
        await tester.scrollUntilVisible(
          androidSettingsTile,
          200,
          scrollable: listFinder,
        );
        await tester.pumpAndSettle();
        await tester.tap(androidSettingsTile);
        await tester.pumpAndSettle();

        expect(
          openedCalls.any((c) => c.method == 'openNotificationSettings'),
          isTrue,
        );
      },
    );
  });
}
