import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/services/live_timer_notification_service.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/trono_controller.dart';

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

  group('LiveTimerNotificationPayload & Copy (V2.7 PR #26)', () {
    test('builds EN default and ES parity payloads with brand-first copy', () {
      final start = DateTime.utc(2026, 11, 27, 10, 30, 0);

      final en = LiveTimerNotificationPayload.forLocale(
        start,
        const Locale('en'),
      );
      final enMap = en.toPlatformMap();
      expect(enMap['startMillis'], start.millisecondsSinceEpoch);
      expect(enMap['locale'], 'en');
      expect(enMap['title'], contains('Throne'));
      expect(enMap['saveLabel'], contains('Save'));
      expect(enMap['cancelLabel'], contains('Cancel'));

      final es = LiveTimerNotificationPayload.forLocale(
        start,
        const Locale('es'),
      );
      final esMap = es.toPlatformMap();
      expect(esMap['startMillis'], start.millisecondsSinceEpoch);
      expect(esMap['locale'], 'es');
      expect(esMap['title'], contains('Cronómetro'));
      expect(esMap['saveLabel'], contains('Guardar'));
      expect(esMap['cancelLabel'], contains('Cancelar'));
    });

    test('parses valid native action names and rejects unknown values', () {
      expect(LiveTimerAction.tryParse('finish'), LiveTimerAction.finish);
      expect(LiveTimerAction.tryParse('cancel'), LiveTimerAction.cancel);
      expect(LiveTimerAction.tryParse('FINISH'), LiveTimerAction.finish);
      expect(LiveTimerAction.tryParse('unknown'), isNull);
      expect(LiveTimerAction.tryParse(null), isNull);
    });
  });

  group('LiveTimerNotificationService MethodChannel bridge (V2.7 PR #26)', () {
    const channel = MethodChannel('com.trono.trono/live_timer_test');
    final recordedCalls = <MethodCall>[];

    setUp(() {
      recordedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            recordedCalls.add(call);
            if (call.method == 'showLiveTimer') return true;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes showLiveTimer and dismissLiveTimer with expected args', () async {
      final service = LiveTimerNotificationService(channel: channel);
      final start = DateTime.utc(2026, 11, 27, 12, 0, 0);

      final shown = await service.showTimer(start, locale: const Locale('es'));
      expect(shown, isTrue);
      expect(recordedCalls.length, 1);
      expect(recordedCalls.first.method, 'showLiveTimer');
      final args = Map<String, Object?>.from(
        recordedCalls.first.arguments as Map,
      );
      expect(args['startMillis'], start.millisecondsSinceEpoch);
      expect(args['locale'], 'es');
      expect(args['saveLabel'], contains('Guardar'));

      await service.dismissTimer();
      expect(recordedCalls.length, 2);
      expect(recordedCalls.last.method, 'dismissLiveTimer');
    });

    test('gracefully no-ops when platform channel is missing', () async {
      const missingChannel = MethodChannel('com.trono.trono/missing_live_timer');
      final service = LiveTimerNotificationService(channel: missingChannel);

      final shown = await service.showTimer(
        DateTime.now(),
        locale: const Locale('en'),
      );
      expect(shown, isFalse);
      await expectLater(service.dismissTimer(), completes);
    });

    test('delivers native onTimerAction callbacks for finish and cancel', () async {
      final service = LiveTimerNotificationService(channel: channel);
      final received = <LiveTimerAction>[];
      service.startListening(received.add);

      final codec = const StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('onTimerAction', 'finish')),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('onTimerAction', 'cancel')),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('onTimerAction', 'bogus')),
        (_) {},
      );

      expect(received, [LiveTimerAction.finish, LiveTimerAction.cancel]);
      service.dispose();
    });
  });

  group('TronoController Live Timer Notification sync (V2.7 PR #26)', () {
    test(
      'shows, re-localizes, and dismisses ongoing notification across timer lifecycle',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsService();
        await settings.init();

        const testChannel = MethodChannel(
          'com.trono.trono/live_timer_ctrl_test',
        );
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              calls.add(call);
              return true;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(testChannel, null);
        });

        final ctrl = TronoController(
          repository: _MemoryRepo(),
          settings: settings,
          updateChecker: UpdateCheckerService(
            settings: settings,
            currentVersionProvider: () async => '2.7.0',
            httpGet: (_) async => null,
          ),
          liveTimerNotificationService: LiveTimerNotificationService(
            channel: testChannel,
          ),
          onTimerSynced: (_) async {},
          readExternalTimerStart: () async => null,
        );
        await ctrl.init();
        calls.clear();

        // 1. Start timer -> shows ongoing notification in EN
        await ctrl.startTimer();
        expect(calls.map((c) => c.method), ['showLiveTimer']);
        expect((calls.last.arguments as Map)['locale'], 'en');

        // 2. Switch locale while running -> updates notification copy to ES
        await ctrl.setLocale(const Locale('es'));
        expect(calls.map((c) => c.method), ['showLiveTimer', 'showLiveTimer']);
        expect((calls.last.arguments as Map)['locale'], 'es');

        // 3. Finish via quickLog -> dismisses notification
        await ctrl.quickLog(BathroomType.poop);
        expect(calls.last.method, 'dismissLiveTimer');

        // 4. External hydrate from widget -> shows notification; external null -> dismisses
        calls.clear();
        ctrl.syncTimerFromExternal(
          DateTime.now().subtract(const Duration(seconds: 40)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(calls.map((c) => c.method), ['showLiveTimer']);

        ctrl.syncTimerFromExternal(null);
        await Future<void>.delayed(Duration.zero);
        expect(calls.last.method, 'dismissLiveTimer');

        ctrl.dispose();
      },
    );
  });
}
