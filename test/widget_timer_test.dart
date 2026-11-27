import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/services/widget_sync_service.dart';
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

  group('WidgetLogPayload URI parsing (V2.7 Widget Timer)', () {
    test('parses type and valid positive duration seconds', () {
      final p = WidgetLogPayload.tryParseUri(
        Uri.parse('trono://log?type=poop&duration=245'),
      );
      expect(p, isNotNull);
      expect(p!.type, BathroomType.poop);
      expect(p.durationSeconds, 245);
    });

    test('handles missing, zero, negative, or malformed duration safely', () {
      final noDur = WidgetLogPayload.tryParseUri(
        Uri.parse('trono://log?type=poop'),
      );
      expect(noDur?.type, BathroomType.poop);
      expect(noDur?.durationSeconds, isNull);

      expect(
        WidgetLogPayload.tryParseUri(
          Uri.parse('trono://log?type=poop&duration=0'),
        )?.durationSeconds,
        isNull,
      );
      expect(
        WidgetLogPayload.tryParseUri(
          Uri.parse('trono://log?type=poop&duration=-12'),
        )?.durationSeconds,
        isNull,
      );
      expect(
        WidgetLogPayload.tryParseUri(
          Uri.parse('trono://log?type=poop&duration=notanumber'),
        )?.durationSeconds,
        isNull,
      );
    });

    test('clamps extreme durations and rejects null/missing type URIs', () {
      final clamped = WidgetLogPayload.tryParseUri(
        Uri.parse('trono://log?type=poop&duration=999999'),
      );
      expect(clamped?.durationSeconds, WidgetLogPayload.maxDurationSeconds);

      expect(WidgetLogPayload.tryParseUri(null), isNull);
      expect(
        WidgetLogPayload.tryParseUri(Uri.parse('trono://log?duration=60')),
        isNull,
      );
    });

    test('formats YYYY-MM-DD date key for midnight widget auto-reset', () {
      expect(
        WidgetSyncService.formatDateKey(DateTime(2026, 3, 5, 23, 59)),
        '2026-03-05',
      );
      expect(
        WidgetSyncService.formatDateKey(DateTime(2026, 11, 27, 0, 1)),
        '2026-11-27',
      );
    });
  });

  group('TronoController 2-Way Widget Timer Sync (V2.7)', () {
    test('hydrates active timer from external start, clears on external null, and ignores stale >12h timers', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final syncedStarts = <DateTime?>[];

      final ctrl = TronoController(
        repository: _MemoryRepo(),
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.6.0',
          httpGet: (_) async => null,
        ),
        onTimerSynced: (dt) async => syncedStarts.add(dt),
        readExternalTimerStart: () async => null,
      );
      await ctrl.init();

      // 1. Hydrate from widget timer started 95s ago
      final startedAgo = DateTime.now().subtract(const Duration(seconds: 95));
      ctrl.syncTimerFromExternal(startedAgo);
      expect(ctrl.isTimerRunning, isTrue);
      expect(ctrl.elapsedTimerSeconds, greaterThanOrEqualTo(94));

      // 2. External null (finished/cancelled from widget) stops in-app timer cleanly
      ctrl.syncTimerFromExternal(null);
      expect(ctrl.isTimerRunning, isFalse);
      expect(ctrl.elapsedTimerSeconds, 0);

      // 3. Stale timer (>12h old) is ignored safely
      final stale = DateTime.now().subtract(const Duration(hours: 15));
      ctrl.syncTimerFromExternal(stale);
      expect(ctrl.isTimerRunning, isFalse);

      // 4. Starting & cancelling in-app notifies widget sync callback
      syncedStarts.clear();
      await ctrl.startTimer();
      expect(ctrl.isTimerRunning, isTrue);
      expect(syncedStarts.length, 1);
      expect(syncedStarts.last, isNotNull);

      await ctrl.cancelTimer();
      expect(ctrl.isTimerRunning, isFalse);
      expect(syncedStarts.length, 2);
      expect(syncedStarts.last, isNull);

      // 5. Starting and finishing via quickLog clears widget timer & saves duration
      syncedStarts.clear();
      await ctrl.startTimer();
      final (log, _) = await ctrl.quickLog(BathroomType.poop);
      expect(ctrl.isTimerRunning, isFalse);
      expect(log.durationSeconds, greaterThanOrEqualTo(1));
      expect(syncedStarts.last, isNull);

      ctrl.dispose();
    });
  });
}
