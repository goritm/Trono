import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/reminder_schedule.dart';
import 'package:trono/screens/settings_screen.dart';
import 'package:trono/services/local_reminder_service.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';

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
    _logs.add(log);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderScheduleCalculator (V2.5)', () {
    test('schedules Streak Guard for today when not logged today and before hour', () {
      final now = DateTime(2026, 11, 26, 15, 30);
      final next = ReminderScheduleCalculator.nextStreakReminder(
        now: now,
        hour: 20,
        loggedToday: false,
        currentStreak: 4,
      );
      expect(next, DateTime(2026, 11, 26, 20, 0));
    });

    test('suppresses today and schedules tomorrow when already logged today', () {
      final now = DateTime(2026, 11, 26, 10, 0);
      final next = ReminderScheduleCalculator.nextStreakReminder(
        now: now,
        hour: 20,
        loggedToday: true,
        currentStreak: 5,
      );
      expect(next, DateTime(2026, 11, 27, 20, 0));
    });

    test('rolls over to tomorrow when chosen hour already passed or equals now', () {
      final atExactHour = DateTime(2026, 11, 26, 20, 0);
      expect(
        ReminderScheduleCalculator.nextStreakReminder(
          now: atExactHour,
          hour: 20,
          loggedToday: false,
          currentStreak: 2,
        ),
        DateTime(2026, 11, 27, 20, 0),
      );

      final lateNight = DateTime(2026, 12, 31, 22, 15);
      expect(
        ReminderScheduleCalculator.nextStreakReminder(
          now: lateNight,
          hour: 20,
          loggedToday: false,
          currentStreak: 1,
        ),
        DateTime(2027, 1, 1, 20, 0),
      );
    });

    test('schedules Weekly Recap for next Sunday at 19:00 strictly after now', () {
      // Thursday 2026-11-26 -> Sunday 2026-11-29 19:00
      final thursday = DateTime(2026, 11, 26, 14, 0);
      expect(
        ReminderScheduleCalculator.nextWeeklyRecap(now: thursday),
        DateTime(2026, 11, 29, 19, 0),
      );

      // Sunday morning -> same day at 19:00
      final sundayMorning = DateTime(2026, 11, 29, 11, 30);
      expect(
        ReminderScheduleCalculator.nextWeeklyRecap(now: sundayMorning),
        DateTime(2026, 11, 29, 19, 0),
      );

      // Sunday at exact 19:00 -> next Sunday 2026-12-06 19:00
      final sundayExact = DateTime(2026, 11, 29, 19, 0);
      expect(
        ReminderScheduleCalculator.nextWeeklyRecap(now: sundayExact),
        DateTime(2026, 12, 6, 19, 0),
      );

      // Sunday night 21:00 -> next Sunday 2026-12-06 19:00
      final sundayNight = DateTime(2026, 11, 29, 21, 0);
      expect(
        ReminderScheduleCalculator.nextWeeklyRecap(now: sundayNight),
        DateTime(2026, 12, 6, 19, 0),
      );
    });

    test('ReminderConfig defaults are opt-in OFF at 20:00 and copyWith works', () {
      const cfg = ReminderConfig();
      expect(cfg.streakEnabled, isFalse);
      expect(cfg.streakHour, 20);
      expect(cfg.weeklyEnabled, isFalse);

      final updated = cfg.copyWith(streakEnabled: true, streakHour: 21);
      expect(updated.streakEnabled, isTrue);
      expect(updated.streakHour, 21);
      expect(updated.weeklyEnabled, isFalse);
    });
  });

  group('LocalReminderService MethodChannel bridge (V2.5)', () {
    test('invokes scheduleReminder and cancelReminder properly via syncReminders', () async {
      final calls = <MethodCall>[];
      const testChannel = MethodChannel('com.trono.trono/reminders_test');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
            calls.add(call);
            if (call.method == 'requestPermission') return true;
            if (call.method == 'scheduleReminder') return true;
            return null;
          });

      final service = LocalReminderService(channel: testChannel);
      expect(await service.requestPermission(), isTrue);

      final now = DateTime(2026, 11, 26, 16, 0);
      await service.syncReminders(
        config: const ReminderConfig(
          streakEnabled: true,
          streakHour: 21,
          weeklyEnabled: false,
        ),
        loggedToday: false,
        currentStreak: 3,
        streakTitle: 'Keep your Trono streak alive? 👑',
        streakBody: 'Claim your throne before midnight.',
        weeklyTitle: 'Weekly Wrapped',
        weeklyBody: 'Check your stats',
        now: now,
      );

      expect(calls.map((c) => c.method), [
        'requestPermission',
        'scheduleReminder',
        'cancelReminder',
      ]);

      final schedArgs = Map<String, dynamic>.from(calls[1].arguments as Map);
      expect(schedArgs['id'], LocalReminderService.streakReminderId);
      expect(
        schedArgs['triggerAtMillis'],
        DateTime(2026, 11, 26, 21, 0).millisecondsSinceEpoch,
      );
      expect(schedArgs['title'], 'Keep your Trono streak alive? 👑');
      expect(schedArgs['body'], 'Claim your throne before midnight.');

      final cancelArgs = Map<String, dynamic>.from(calls[2].arguments as Map);
      expect(cancelArgs['id'], LocalReminderService.weeklyRecapReminderId);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });

    test('handles MissingPluginException gracefully without throwing', () async {
      const missingChannel = MethodChannel('com.trono.trono/missing_reminders');
      final service = LocalReminderService(channel: missingChannel);

      expect(await service.requestPermission(), isFalse);
      expect(
        await service.scheduleReminder(
          ScheduledReminder(
            id: 1001,
            triggerAt: DateTime(2026, 11, 26, 20, 0),
            title: 'Test',
            body: 'Body',
          ),
        ),
        isFalse,
      );
      await expectLater(service.cancelReminder(1001), completes);
    });

    test('handles PlatformException gracefully without throwing', () async {
      const errChannel = MethodChannel('com.trono.trono/error_reminders');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errChannel, (call) async {
            throw PlatformException(code: 'ERR', message: 'boom');
          });
      final service = LocalReminderService(channel: errChannel);

      expect(await service.requestPermission(), isFalse);
      expect(
        await service.scheduleReminder(
          ScheduledReminder(
            id: 1001,
            triggerAt: DateTime(2026, 11, 26, 20, 0),
            title: 'Test',
            body: 'Body',
          ),
        ),
        isFalse,
      );
      await expectLater(service.cancelReminder(1001), completes);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errChannel, null);
    });
  });

  group('TronoController reminder persistence & auto-reschedule (V2.5)', () {
    test('persists settings and reschedules after quickLog, saveLog, deleteLog, and setLocale', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      const testChannel = MethodChannel('com.trono.trono/reminders_ctrl_test');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
            calls.add(call);
            if (call.method == 'requestPermission') return true;
            if (call.method == 'scheduleReminder') return true;
            return null;
          });

      final settings = SettingsService();
      await settings.init();
      final repo = _InMemoryRepo();
      final controller = TronoController(
        repository: repo,
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.5.0',
          httpGet: (_) async => null,
        ),
        reminderService: LocalReminderService(channel: testChannel),
      );
      await controller.init();

      expect(controller.streakReminderEnabled, isFalse);
      expect(controller.streakReminderHour, 20);
      expect(controller.weeklyRecapReminderEnabled, isFalse);

      // Enable streak reminder
      calls.clear();
      final enabled = await controller.setStreakReminderEnabled(true);
      expect(enabled, isTrue);
      expect(controller.streakReminderEnabled, isTrue);
      expect(settings.streakReminderEnabled, isTrue);

      await controller.setStreakReminderHour(22);
      expect(controller.streakReminderHour, 22);
      expect(settings.streakReminderHour, 22);

      // Quick log today -> Streak Guard should reschedule for tomorrow at 22:00!
      calls.clear();
      final (log, _) = await controller.quickLog(BathroomType.poop);
      final afterLogSchedule = calls.where((c) => c.method == 'scheduleReminder').toList();
      expect(afterLogSchedule, isNotEmpty);
      final afterLogArgs = Map<String, dynamic>.from(afterLogSchedule.last.arguments as Map);
      final scheduledDt = DateTime.fromMillisecondsSinceEpoch(
        afterLogArgs['triggerAtMillis'] as int,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(scheduledDt.year, tomorrow.year);
      expect(scheduledDt.month, tomorrow.month);
      expect(scheduledDt.day, tomorrow.day);
      expect(scheduledDt.hour, 22);

      // Switch locale to Spanish -> reschedules with Spanish title/body
      calls.clear();
      await controller.setLocale(const Locale('es'));
      final afterLocaleSchedule = calls.where((c) => c.method == 'scheduleReminder').toList();
      expect(afterLocaleSchedule, isNotEmpty);
      final esArgs = Map<String, dynamic>.from(afterLocaleSchedule.last.arguments as Map);
      expect((esArgs['title'] as String).contains('Trono'), isTrue);
      expect((esArgs['title'] as String).contains('racha'), isTrue);

      // Update log via saveLog -> triggers resync
      calls.clear();
      await controller.saveLog(log.copyWith(bristolType: 4));
      expect(calls.where((c) => c.method == 'scheduleReminder'), isNotEmpty);

      // Delete today's log -> triggers resync
      calls.clear();
      await controller.deleteLog(log.id);
      expect(calls.where((c) => c.method == 'scheduleReminder'), isNotEmpty);

      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });
  });

  group('SettingsScreen Reminders UI (V2.5)', () {
    Future<(TronoController, SocialController)> makeControllers(
      WidgetTester tester,
      MethodChannel channel, {
      Locale locale = const Locale('en'),
    }) async {
      SharedPreferences.setMockInitialValues({
        'locale_code': locale.languageCode,
        'update_last_checked_ms': DateTime.now().millisecondsSinceEpoch,
      });
      late TronoController ctrl;
      late SocialController social;
      await tester.runAsync(() async {
        final settings = SettingsService();
        await settings.init();
        final repo = _InMemoryRepo();
        ctrl = TronoController(
          repository: repo,
          settings: settings,
          updateChecker: UpdateCheckerService(
            settings: settings,
            currentVersionProvider: () async => '2.5.0',
            httpGet: (_) async => null,
          ),
          reminderService: LocalReminderService(channel: channel),
        );
        await ctrl.init();
        social = SocialController(
          tronoController: ctrl,
          repository: repo,
          settings: settings,
        );
      });
      return (ctrl, social);
    }

    testWidgets('enabling Streak Guard shows hour chips and updates hour', (tester) async {
      const channel = MethodChannel('com.trono.trono/reminders_ui_allow');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'requestPermission') return true;
            if (call.method == 'scheduleReminder') return true;
            return null;
          });

      final (ctrl, social) = await makeControllers(tester, channel);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: ctrl.locale,
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: SettingsScreen(controller: ctrl, social: social),
        ),
      );
      await tester.pumpAndSettle();

      final streakSwitch = find.byKey(const ValueKey('streak_reminder_switch'));
      await tester.scrollUntilVisible(streakSwitch, 300);
      expect(streakSwitch, findsOneWidget);
      expect(find.byKey(const ValueKey('streak_hour_chip_21')), findsNothing);

      await tester.tap(streakSwitch);
      await tester.pumpAndSettle();

      expect(ctrl.streakReminderEnabled, isTrue);
      final chip21 = find.byKey(const ValueKey('streak_hour_chip_21'));
      await tester.scrollUntilVisible(chip21, 150);
      expect(chip21, findsOneWidget);

      await tester.tap(chip21);
      await tester.pumpAndSettle();
      expect(ctrl.streakReminderHour, 21);

      ctrl.dispose();
      social.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('when notification permission is denied, toggle stays OFF and toast shows', (tester) async {
      const channel = MethodChannel('com.trono.trono/reminders_ui_deny');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'requestPermission') return false;
            return null;
          });

      final (ctrl, social) = await makeControllers(tester, channel);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: ctrl.locale,
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: SettingsScreen(controller: ctrl, social: social),
        ),
      );
      await tester.pumpAndSettle();

      final weeklySwitch = find.byKey(const ValueKey('weekly_recap_switch'));
      await tester.scrollUntilVisible(weeklySwitch, 300);
      await tester.tap(weeklySwitch);
      await tester.pumpAndSettle();

      expect(ctrl.weeklyRecapReminderEnabled, isFalse);
      expect(
        find.text('Enable notifications in Android settings to use reminders'),
        findsOneWidget,
      );

      ctrl.dispose();
      social.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('renders Spanish parity labels cleanly in SettingsScreen', (tester) async {
      const channel = MethodChannel('com.trono.trono/reminders_ui_es');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'requestPermission') return true;
            if (call.method == 'scheduleReminder') return true;
            return null;
          });

      final (ctrl, social) = await makeControllers(
        tester,
        channel,
        locale: const Locale('es'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: ctrl.locale,
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: SettingsScreen(controller: ctrl, social: social),
        ),
      );
      await tester.pumpAndSettle();

      final streakSwitch = find.byKey(const ValueKey('streak_reminder_switch'));
      await tester.scrollUntilVisible(streakSwitch, 300);
      expect(find.text('🔥 Recordatorio de racha'), findsOneWidget);
      expect(find.text('✨ Resumen semanal del domingo'), findsOneWidget);

      ctrl.dispose();
      social.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
