import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/insights.dart';
import 'package:trono/screens/home_screen.dart';
import 'package:trono/screens/map_screen.dart';
import 'package:trono/screens/settings_screen.dart';
import 'package:trono/services/location_service.dart';
import 'package:trono/services/push_notification_service.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/supabase_sync_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/log_detail_sheet.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2.8.1 Quick Follow-Up False Alarm & Clean Home Brand Header', () {
    testWidgets(
      'LogDetailSheet in quickFollowUp mode shows False alarm chip and saves BathroomType.falseAlarm',
      (tester) async {
        final now = DateTime(2026, 11, 27, 14, 0);
        final initial = BathroomLog(
          id: 'log-1',
          type: BathroomType.poop,
          timestamp: now,
          createdAt: now,
          updatedAt: now,
        );
        LogDetailSheetResult? sheetResult;

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
                    onPressed: () async {
                      sheetResult = await showLogDetailSheet(
                        ctx,
                        mode: LogSheetMode.quickFollowUp,
                        initialLog: initial,
                        defaultShareLevel: ShareLevel.full,
                      );
                    },
                    child: const Text('Open Quick'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Quick'));
        await tester.pumpAndSettle();

        // Both Throne & False alarm chips are available right away in quickFollowUp
        expect(find.text('👑 Trono'), findsOneWidget);
        expect(find.text('💨 Falsa alarma'), findsOneWidget);
        // Date/Time picker stays hidden in quickFollowUp
        expect(find.text('Fecha y hora'), findsNothing);

        // Switching to False alarm hides Bristol scale and saves as falseAlarm
        await tester.tap(find.text('💨 Falsa alarma'));
        await tester.pumpAndSettle();
        expect(find.text('Escala de Bristol'), findsNothing);

        await tester.tap(find.text('LISTO'));
        await tester.pumpAndSettle();

        expect(sheetResult?.savedLog, isNotNull);
        expect(sheetResult!.savedLog!.type, BathroomType.falseAlarm);
      },
    );

    testWidgets(
      'HomeScreen places Trono title on the left and transparent vector mark on the right (no square icon image)',
      (tester) async {
        final ctrl = (await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsService();
          await settings.init();
          final c = TronoController(
            repository: _MemoryRepo(),
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.1',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await c.init();
          return c;
        }))!;
        addTearDown(ctrl.dispose);

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
              body: HomeScreen(controller: ctrl, onOpenSettings: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text('Trono');
        final markFinder = find.byKey(const ValueKey('home_brand_mark'));

        expect(titleFinder, findsOneWidget);
        expect(markFinder, findsOneWidget);
        // No square raster trono_icon.png inside HomeScreen header
        expect(find.byType(Image), findsNothing);

        final titleRect = tester.getRect(titleFinder);
        final markRect = tester.getRect(markFinder);
        expect(markRect.left, greaterThan(titleRect.left));
      },
    );

    test('formatQuickLogToast appends live earnings for work & WFH logs when hourlyRate is set', () {
      final now = DateTime(2026, 11, 27, 14, 0);
      final workLog = BathroomLog(
        id: 'w1',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        durationSeconds: 600, // 10 min @ €18/h = €3.00
        createdAt: now,
        updatedAt: now,
      );
      final wfhLog = BathroomLog(
        id: 'w2',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        tags: const [BathroomLog.wfhTag],
        createdAt: now,
        updatedAt: now,
      );
      final homeLog = BathroomLog(
        id: 'h1',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        createdAt: now,
        updatedAt: now,
      );

      final es = AppStrings(const Locale('es'));
      final en = AppStrings(const Locale('en'));

      expect(
        formatQuickLogToast(
          baseMessage: '💼 ${es.savedInstantToast}',
          log: workLog,
          hourlyRate: 18.0,
          currencySymbol: '€',
        ),
        '💼 ¡Registrado! (+10 XP · 💰 +€3.00)',
      );
      expect(
        formatQuickLogToast(
          baseMessage: '💻 ${en.savedInstantToast}',
          log: wfhLog,
          hourlyRate: 18.0,
          currencySymbol: '€',
        ),
        '💻 Logged! (+10 XP · 💰 ~€1.50)',
      );
      expect(
        formatQuickLogToast(
          baseMessage: '🏠 ${en.savedInstantToast}',
          log: homeLog,
          hourlyRate: 18.0,
          currencySymbol: '€',
        ),
        '🏠 Logged! (+10 XP)',
      );
      expect(
        formatQuickLogToast(
          baseMessage: '💼 ${en.savedInstantToast}',
          log: workLog,
          hourlyRate: null,
          currencySymbol: '€',
        ),
        '💼 Logged! (+10 XP)',
      );
    });

    test('PushNotificationService handles sendTestNotification and onQuickReply events', () async {
      const channel = MethodChannel('com.trono.trono/push_v281_test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'sendTestNotification') return true;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = PushNotificationService(channel: channel);
      final sent = await service.sendTestNotification(
        locale: const Locale('es'),
      );
      expect(sent, isTrue);
      expect(calls.last.method, 'sendTestNotification');
      expect((calls.last.arguments as Map)['locale'], 'es');

      final replies = <(String, String)>[];
      service.startListening(
        onQuickReply: (logId, body) => replies.add((logId, body)),
      );

      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            codec.encodeMethodCall(
              const MethodCall('onQuickReply', {
                'logId': 'log-42',
                'body': 'Jajaja brutal',
              }),
            ),
            (_) {},
          );

      expect(replies, [('log-42', 'Jajaja brutal')]);
      service.dispose();
    });

    testWidgets(
      'SettingsScreen renders Test notification tile and triggers sendTestNotification',
      (tester) async {
        const channel = MethodChannel('com.trono.trono/push_v281_ui_test');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              if (call.method == 'sendTestNotification') return true;
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
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
              currentVersionProvider: () async => '2.8.1',
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
            service: SupabaseSyncService.forTesting(),
            pushService: PushNotificationService(channel: channel),
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

        final tile = find.byKey(const ValueKey('test_notification_tile'));
        await tester.scrollUntilVisible(
          tile,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(
          calls.any((c) => c.method == 'sendTestNotification'),
          isTrue,
        );
      },
    );

    testWidgets(
      'LogDetailSheet action bar clears Android 3-button navigation bar (48px bottom viewPadding)',
      (tester) async {
        final now = DateTime(2026, 11, 27, 15, 17);
        final initial = BathroomLog(
          id: 'edit-nav-1',
          type: BathroomType.poop,
          timestamp: now,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewPadding: EdgeInsets.only(bottom: 48),
              padding: EdgeInsets.only(bottom: 48),
            ),
            child: MaterialApp(
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
                      onPressed: () => showLogDetailSheet(
                        ctx,
                        mode: LogSheetMode.editExisting,
                        initialLog: initial,
                        defaultShareLevel: ShareLevel.full,
                      ),
                      child: const Text('Open Edit'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Edit'));
        await tester.pumpAndSettle();

        final saveRect = tester.getRect(find.text('GUARDAR'));
        // Must sit strictly above the 48px Android 3-button nav bar (y <= 752)
        expect(saveRect.bottom, lessThanOrEqualTo(800 - 48));
      },
    );

    test('InsightsEngine.calculateTodayPaid sums work & WFH earnings for today only', () {
      final now = DateTime(2026, 11, 27, 15, 0);
      final logs = [
        BathroomLog(
          id: 'w1',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.work,
          durationSeconds: 600, // 10 min @ 18/h = 3.00
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: 'w2',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.home,
          tags: const [BathroomLog.wfhTag],
          durationSeconds: 300, // 5 min @ 18/h = 1.50
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: 'h1',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.home,
          durationSeconds: 600,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(
        InsightsEngine.calculateTodayPaid(logs, hourlyRate: 18.0),
        closeTo(4.50, 0.001),
      );
      expect(InsightsEngine.calculateTodayPaid(logs, hourlyRate: null), 0.0);
    });

    test('AppStrings.levelBadge localizes LVL in EN and NV in ES', () {
      expect(AppStrings(const Locale('en')).levelBadge(3), 'LVL.3');
      expect(AppStrings(const Locale('es')).levelBadge(3), 'NV.3');
    });

    testWidgets(
      'HomeScreen shows LVL pill in header, today paid pill in strip, and clean hero button without subtitle',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'trono_hourly_rate': 18.0,
          'trono_currency_symbol': '€',
        });
        final now = DateTime.now();
        final repo = _MemoryRepo();
        await repo.upsertLog(
          BathroomLog(
            id: 'today-work',
            type: BathroomType.poop,
            timestamp: now,
            locationKind: LocationKind.work,
            durationSeconds: 600, // €3.00
            createdAt: now,
            updatedAt: now,
          ),
        );
        late TronoController ctrl;
        await tester.runAsync(() async {
          final settings = SettingsService();
          await settings.init();
          ctrl = TronoController(
            repository: repo,
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.4',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await ctrl.init();
          await ctrl.setSalaryConfig(hourlyRate: 18.0, currencySymbol: '€');
        });
        addTearDown(ctrl.dispose);

        var awardsOpened = false;
        var insightsOpened = false;
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
              body: HomeScreen(
                controller: ctrl,
                onOpenAwards: () => awardsOpened = true,
                onOpenInsights: () => insightsOpened = true,
                onOpenSettings: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top HUD shows LVL.1 (localized EN) instead of raw XP or NV.1
        expect(find.text('LVL.1'), findsOneWidget);
        expect(find.text('NV.1'), findsNothing);
        await tester.tap(find.text('LVL.1'));
        expect(awardsOpened, isTrue);

        // Top summary strip displays today's Paid on the Throne total & jumps to Insights on tap
        final paidPill = find.byKey(const ValueKey('home_today_paid_pill'));
        expect(paidPill, findsOneWidget);
        expect(find.text('💰 €3.00'), findsOneWidget);
        await tester.tap(paidPill);
        expect(insightsOpened, isTrue);

        // Hero-first layout: CLAIM THRONE sits above side-by-side [Location | Timer]
        final heroFinder = find.text('CLAIM THRONE');
        final locFinder = find.byKey(const ValueKey('home_location_picker_btn'));
        final timerFinder = find.byKey(const ValueKey('home_start_timer_btn'));
        expect(heroFinder, findsOneWidget);
        expect(find.textContaining('1 tap logs instantly'), findsNothing);
        final heroRect = tester.getRect(heroFinder);
        final locRect = tester.getRect(locFinder);
        final timerRect = tester.getRect(timerFinder);
        expect(heroRect.bottom, lessThan(locRect.top));
        expect((locRect.top - timerRect.top).abs(), lessThan(8));
        expect(locRect.right, lessThanOrEqualTo(timerRect.left));
      },
    );

    testWidgets(
      'HomeScreen shows discreet salary setup pill when hourlyRate is unset and opens dialog',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        late TronoController ctrl;
        await tester.runAsync(() async {
          final settings = SettingsService();
          await settings.init();
          ctrl = TronoController(
            repository: _MemoryRepo(),
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.4',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await ctrl.init();
        });
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: Scaffold(body: HomeScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        final setupPill = find.byKey(const ValueKey('home_setup_salary_pill'));
        expect(setupPill, findsOneWidget);
        expect(find.byKey(const ValueKey('home_today_paid_pill')), findsNothing);
        await tester.tap(setupPill);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

    testWidgets(
      'MapScreen replaces Home header button with My Location button and renders live location dot',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        late TronoController ctrl;
        await tester.runAsync(() async {
          final settings = SettingsService();
          await settings.init();
          ctrl = TronoController(
            repository: _MemoryRepo(),
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.4',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await ctrl.init();
        });
        addTearDown(ctrl.dispose);

        var requestedCurrent = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: MapScreen(
              controller: ctrl,
              isRootTab: true,
              silentPositionProvider: () async => null,
              currentPositionProvider: () async {
                requestedCurrent = true;
                return const GeoPoint(40.4168, -3.7038);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final locBtn = find.byKey(const ValueKey('map_my_location_btn'));
        expect(locBtn, findsOneWidget);
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.home_rounded),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('map_user_location_dot')),
          findsNothing,
        );

        await tester.tap(locBtn);
        await tester.pumpAndSettle();
        expect(requestedCurrent, isTrue);
        expect(
          find.byKey(const ValueKey('map_user_location_dot')),
          findsOneWidget,
        );
      },
    );
  });
}
