import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/achievement.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/insights.dart';
import 'package:trono/models/stats_summary.dart';
import 'package:trono/screens/calendar_stats_screen.dart';
import 'package:trono/screens/home_screen.dart';
import 'package:trono/services/local_reminder_service.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/log_detail_sheet.dart';
import 'package:trono/widgets/log_tile.dart';

class _InMemoryRepo implements BathroomRepository {
  _InMemoryRepo([List<BathroomLog>? initial])
      : _logs = List<BathroomLog>.from(initial ?? const []);

  final List<BathroomLog> _logs;

  @override
  Future<List<BathroomLog>> getAllLogs() async =>
      _logs.where((l) => l.deletedAt == null).toList();

  @override
  Future<List<BathroomLog>> getAllLogsIncludingDeleted() async =>
      List<BathroomLog>.from(_logs);

  @override
  Future<List<BathroomLog>> getPendingSyncLogs() async =>
      _logs.where((l) => l.syncStatus != SyncStatus.synced).toList();

  @override
  Future<void> markLogsSynced(List<String> ids) async {}

  @override
  Future<void> upsertLog(BathroomLog log) async {
    _logs.removeWhere((l) => l.id == log.id);
    _logs.insert(0, log);
  }

  @override
  Future<void> upsertLogsBatch(List<BathroomLog> logs) async {
    for (final log in logs) {
      await upsertLog(log);
    }
  }

  @override
  Future<void> softDeleteLog(String id) async {
    _logs.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> clearAll() async => _logs.clear();
}

Widget _wrapApp(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('es')],
    localizationsDelegates: [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: theme ?? AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  final now = DateTime(2026, 11, 27, 10, 30);

  group('BathroomLog WFH & isWorkVisit', () {
    test('Home + wfh tag is both Home territory and a work visit', () {
      final wfhLog = BathroomLog(
        id: 'wfh-1',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        tags: const [BathroomLog.wfhTag, 'coffee'],
        createdAt: now,
        updatedAt: now,
      );

      expect(wfhLog.isWfh, isTrue);
      expect(wfhLog.effectiveLocationKind, LocationKind.home);
      expect(wfhLog.effectiveLocationKind!.isAwayFromHome, isFalse);
      expect(wfhLog.isWorkVisit, isTrue);
    });

    test('plain Home log is NOT a work visit and NOT WFH', () {
      final homeLog = BathroomLog(
        id: 'home-1',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        tags: const ['coffee'],
        createdAt: now,
        updatedAt: now,
      );

      expect(homeLog.isWfh, isFalse);
      expect(homeLog.effectiveLocationKind, LocationKind.home);
      expect(homeLog.isWorkVisit, isFalse);
    });

    test('Work log is a work visit but NOT WFH', () {
      final workLog = BathroomLog(
        id: 'work-1',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        createdAt: now,
        updatedAt: now,
      );

      expect(workLog.isWfh, isFalse);
      expect(workLog.effectiveLocationKind, LocationKind.work);
      expect(workLog.isWorkVisit, isTrue);
    });

    test('StatsCalculator counts WFH under Home while Gamification counts it under Work', () {
      final logs = List.generate(
        5,
        (i) => BathroomLog(
          id: 'wfh-$i',
          type: BathroomType.poop,
          timestamp: now.subtract(Duration(hours: i)),
          locationKind: LocationKind.home,
          durationSeconds: 720, // 12 min x 5 = 60 min
          tags: const [BathroomLog.wfhTag],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final stats = StatsCalculator.calculate(logs, now: now);
      expect(stats.homePoopCount, 5);
      expect(stats.awayPoopCount, 0);

      final gam = GamificationEngine.evaluate(logs);
      final paidBadge =
          gam.achievements.firstWhere((a) => a.id == 'paid_to_poop');
      final proBadge =
          gam.achievements.firstWhere((a) => a.id == 'paid_throne_pro');
      expect(paidBadge.isUnlocked, isTrue);
      expect(proBadge.isUnlocked, isTrue);
    });
  });

  group('InsightsEngine.calculateLogEarnings & calculatePaidOnThrone', () {
    test('returns exact earnings when durationSeconds > 0 for Office and WFH', () {
      final officeLog = BathroomLog(
        id: 'office-exact',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        durationSeconds: 300, // 5 min at €30/h = €2.50
        createdAt: now,
        updatedAt: now,
      );
      final wfhLog = BathroomLog(
        id: 'wfh-exact',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        durationSeconds: 600, // 10 min at €30/h = €5.00
        tags: const [BathroomLog.wfhTag],
        createdAt: now,
        updatedAt: now,
      );

      final officeEarnings = InsightsEngine.calculateLogEarnings(
        officeLog,
        hourlyRate: 30.0,
      );
      expect(officeEarnings, isNotNull);
      expect(officeEarnings!.amount, closeTo(2.50, 0.001));
      expect(officeEarnings.isEstimated, isFalse);
      expect(officeEarnings.secondsUsed, 300);

      final wfhEarnings = InsightsEngine.calculateLogEarnings(
        wfhLog,
        hourlyRate: 30.0,
      );
      expect(wfhEarnings, isNotNull);
      expect(wfhEarnings!.amount, closeTo(5.00, 0.001));
      expect(wfhEarnings.isEstimated, isFalse);
      expect(wfhEarnings.secondsUsed, 600);
    });

    test('falls back to estimated duration (300s throne / 120s false alarm)', () {
      final wfhNoDuration = BathroomLog(
        id: 'wfh-est',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        tags: const [BathroomLog.wfhTag],
        createdAt: now,
        updatedAt: now,
      );
      final workFalseAlarm = BathroomLog(
        id: 'work-fa',
        type: BathroomType.falseAlarm,
        timestamp: now,
        locationKind: LocationKind.work,
        createdAt: now,
        updatedAt: now,
      );

      final throneEst = InsightsEngine.calculateLogEarnings(
        wfhNoDuration,
        hourlyRate: 18.0, // 300/3600 * 18 = 1.50
      );
      expect(throneEst, isNotNull);
      expect(throneEst!.amount, closeTo(1.50, 0.001));
      expect(throneEst.isEstimated, isTrue);
      expect(throneEst.secondsUsed, 300);

      final faEst = InsightsEngine.calculateLogEarnings(
        workFalseAlarm,
        hourlyRate: 30.0, // 120/3600 * 30 = 1.00
      );
      expect(faEst, isNotNull);
      expect(faEst!.amount, closeTo(1.00, 0.001));
      expect(faEst.isEstimated, isTrue);
      expect(faEst.secondsUsed, 120);
    });

    test('returns null when hourlyRate is null/zero or visit is non-work', () {
      final homeLog = BathroomLog(
        id: 'home-only',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        durationSeconds: 300,
        createdAt: now,
        updatedAt: now,
      );
      final workLog = BathroomLog(
        id: 'work-no-pay',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        durationSeconds: 300,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        InsightsEngine.calculateLogEarnings(homeLog, hourlyRate: 30.0),
        isNull,
      );
      expect(
        InsightsEngine.calculateLogEarnings(workLog, hourlyRate: null),
        isNull,
      );
      expect(
        InsightsEngine.calculateLogEarnings(workLog, hourlyRate: 0),
        isNull,
      );
    });

    test('calculatePaidOnThrone combines both Office and WFH visits', () {
      final logs = [
        BathroomLog(
          id: 'office-1',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.work,
          durationSeconds: 300, // €2.50 at €30/h
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: 'wfh-1',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.home,
          durationSeconds: 600, // €5.00 at €30/h
          tags: const [BathroomLog.wfhTag],
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: 'home-1',
          type: BathroomType.poop,
          timestamp: now,
          locationKind: LocationKind.home,
          durationSeconds: 600, // excluded
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final paid = InsightsEngine.calculatePaidOnThrone(
        logs,
        hourlyRate: 30.0,
        now: now,
      );

      expect(paid.workVisitsTotal, 2);
      expect(paid.workVisitsThisMonth, 2);
      expect(paid.workSecondsTotal, 900);
      expect(paid.earnedThisMonth, closeTo(7.50, 0.001));
      expect(paid.earnedAllTime, closeTo(7.50, 0.001));
    });
  });

  group('LogTile widget (WFH badge & golden earnings pill)', () {
    testWidgets('renders exact earnings pill and WFH badge without duplicate wfh tag', (tester) async {
      final log = BathroomLog(
        id: 'tile-wfh-exact',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        durationSeconds: 300, // €2.50 at €30/h
        tags: const [BathroomLog.wfhTag, 'coffee'],
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _wrapApp(
          LogTile(
            log: log,
            hourlyRate: 30.0,
            currencySymbol: '€',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('log_tile_earnings_tile-wfh-exact')), findsOneWidget);
      expect(find.text('💰 +€2.50'), findsOneWidget);
      expect(find.text('💻 WFH'), findsOneWidget);
      expect(find.text('☕ Coffee'), findsOneWidget);
      // Must NOT show "🏠 At home" or a raw/duplicate "wfh" chip
      expect(find.text('🏠 At home'), findsNothing);
      expect(find.text('wfh'), findsNothing);
    });

    testWidgets('renders estimated earnings pill (~) when duration is missing', (tester) async {
      final log = BathroomLog(
        id: 'tile-work-est',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _wrapApp(
          LogTile(
            log: log,
            hourlyRate: 18.0, // 300s fallback => €1.50
            currencySymbol: '€',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('log_tile_earnings_tile-work-est')), findsOneWidget);
      expect(find.text('💰 ~€1.50'), findsOneWidget);
    });

    testWidgets('hides earnings pill when hourlyRate is null or log is non-work', (tester) async {
      final workLog = BathroomLog(
        id: 'tile-no-salary',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.work,
        durationSeconds: 300,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _wrapApp(
          LogTile(
            log: workLog,
            hourlyRate: null,
            currencySymbol: '€',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('log_tile_earnings_tile-no-salary')), findsNothing);

      final homeLog = BathroomLog(
        id: 'tile-home-only',
        type: BathroomType.poop,
        timestamp: now,
        locationKind: LocationKind.home,
        durationSeconds: 300,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _wrapApp(
          LogTile(
            log: homeLog,
            hourlyRate: 30.0,
            currencySymbol: '€',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('log_tile_earnings_tile-home-only')), findsNothing);
    });
  });

  group('HomeScreen WFH selector & narrow 360dp viewport', () {
    testWidgets('fits 5 location tabs without overflow on 360dp (EN & ES) and logs WFH with home + wfh tag', (tester) async {
      const homeWidgetChannel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, (_) async => true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            LocalReminderService.defaultChannel,
            (_) async => true,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(homeWidgetChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(LocalReminderService.defaultChannel, null);
      });

      SharedPreferences.setMockInitialValues({
        'auto_gps': false,
        'update_last_checked_ms': DateTime.now().millisecondsSinceEpoch,
        'unlocked_achievements': ['first_visit'],
        'highest_rank_level': 1,
      });
      final settings = SettingsService();
      final repo = _InMemoryRepo();
      late TronoController controller;

      await tester.runAsync(() async {
        await settings.init();
        controller = TronoController(repository: repo, settings: settings);
        await controller.init();
        await controller.setSalaryConfig(hourlyRate: 30.0, currencySymbol: '€');
      });

      // Narrow 360dp viewport
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify Spanish narrow layout opens full unabbreviated location sheet (Teletrabajo, Trabajo)
      await tester.pumpWidget(
        _wrapApp(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => HomeScreen(controller: controller),
          ),
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('home_location_picker_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Teletrabajo'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      Navigator.of(tester.element(find.text('Teletrabajo'))).pop();
      await tester.pumpAndSettle();

      // Switch to EN, pick WFH from location sheet & tap Hero button
      await tester.pumpWidget(
        _wrapApp(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => HomeScreen(controller: controller),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('home_location_picker_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick_loc_wfh')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLAIM THRONE'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Dismiss the quick follow-up bottom sheet
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(controller.logs.length, 1);
      final saved = controller.logs.first;
      expect(saved.locationKind, LocationKind.home);
      expect(saved.isWfh, isTrue);
      expect(saved.isWorkVisit, isTrue);
      expect(saved.tags, contains(BathroomLog.wfhTag));

      // HomeScreen LogTile should render the golden earnings pill & WFH badge
      expect(find.text('💻 WFH'), findsOneWidget);
      expect(find.byKey(ValueKey('log_tile_earnings_${saved.id}')), findsOneWidget);

      controller.dispose();
    });

    testWidgets('CalendarStatsScreen day sheet renders golden earnings pill on WFH log', (tester) async {
      const homeWidgetChannel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, (_) async => true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            LocalReminderService.defaultChannel,
            (_) async => true,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(homeWidgetChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(LocalReminderService.defaultChannel, null);
      });

      final today = DateTime.now();
      final wfhLog = BathroomLog(
        id: 'cal-wfh-1',
        type: BathroomType.poop,
        timestamp: today,
        durationSeconds: 300, // €2.50 at €30/h
        locationKind: LocationKind.home,
        tags: const [BathroomLog.wfhTag],
        createdAt: today,
        updatedAt: today,
      );

      SharedPreferences.setMockInitialValues({
        'auto_gps': false,
        'update_last_checked_ms': DateTime.now().millisecondsSinceEpoch,
      });
      final settings = SettingsService();
      final repo = _InMemoryRepo([wfhLog]);
      late TronoController controller;

      await tester.runAsync(() async {
        await settings.init();
        controller = TronoController(repository: repo, settings: settings);
        await controller.init();
        await controller.setSalaryConfig(hourlyRate: 30.0, currencySymbol: '€');
      });

      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapApp(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => CalendarStatsScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap today's day number in the monthly heatmap grid to open the day sheet
      final dayFinder = find.text('${today.day}').first;
      await tester.ensureVisible(dayFinder);
      await tester.pumpAndSettle();
      await tester.tap(dayFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('log_tile_earnings_cal-wfh-1')), findsOneWidget);
      expect(find.text('💰 +€2.50'), findsOneWidget);
      expect(find.text('💻 WFH'), findsOneWidget);

      controller.dispose();
    });
  });

  group('LogDetailSheet WFH location chip', () {
    testWidgets('selecting WFH saves home + wfh tag, and switching to Away removes wfh tag', (tester) async {
      LogDetailSheetResult? result;

      await tester.pumpWidget(
        _wrapApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showLogDetailSheet(
                  context,
                  mode: LogSheetMode.createPast,
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap WFH chip in location section (first Scrollable is the sheet's vertical ListView)
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('location_chip_wfh')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('location_chip_wfh')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(result?.savedLog, isNotNull);
      expect(result!.savedLog!.locationKind, LocationKind.home);
      expect(result!.savedLog!.tags, contains(BathroomLog.wfhTag));
      expect(result!.savedLog!.isWfh, isTrue);

      // Now edit that saved WFH log and switch location to Away
      LogDetailSheetResult? editResult;
      await tester.pumpWidget(
        _wrapApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                editResult = await showLogDetailSheet(
                  context,
                  mode: LogSheetMode.editExisting,
                  initialLog: result!.savedLog,
                );
              },
              child: const Text('Edit Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Sheet'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('🌍 Away'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('🌍 Away'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(editResult?.savedLog, isNotNull);
      expect(editResult!.savedLog!.locationKind, LocationKind.away);
      expect(editResult!.savedLog!.tags, isNot(contains(BathroomLog.wfhTag)));
      expect(editResult!.savedLog!.isWfh, isFalse);
    });
  });
}
