import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/bathroom_log.dart';
import '../models/favorite_place.dart';
import '../models/stats_summary.dart';
import 'location_service.dart';
import 'settings_service.dart';

const String kAndroidWidgetProvider = 'TronoWidgetProvider';
const String kWidgetTimerStartKey = 'timer_start_ms';
const String kWidgetTodayDateKey = 'today_date';

/// Parsed payload from Android Home Screen Widget background callback URIs,
/// e.g. `trono://log?type=poop` or `trono://log?type=poop&duration=245`.
class WidgetLogPayload {
  const WidgetLogPayload({
    required this.type,
    this.durationSeconds,
  });

  /// Cap recorded durations at 4 hours to protect against forgotten timers.
  static const int maxDurationSeconds = 14400;

  final BathroomType type;
  final int? durationSeconds;

  static WidgetLogPayload? tryParseUri(Uri? uri) {
    if (uri == null) return null;
    final typeParam = uri.queryParameters['type'];
    if (typeParam == null || typeParam.trim().isEmpty) return null;

    int? duration;
    final rawDuration = uri.queryParameters['duration'];
    if (rawDuration != null) {
      final parsed = int.tryParse(rawDuration.trim());
      if (parsed != null && parsed > 0) {
        duration = parsed > maxDurationSeconds ? maxDurationSeconds : parsed;
      }
    }

    return WidgetLogPayload(
      type: BathroomType.fromDb(typeParam),
      durationSeconds: duration,
    );
  }
}

/// Background entrypoint invoked when the user taps "+1" or finishes the live
/// timer directly on the Android Home Screen Widget.
///
/// Performance-first order:
/// 1. Writes the BathroomLog to SQLite immediately (0ms) so it is never lost.
/// 2. Syncs updated widget stats right away.
/// 3. Enriches the saved row with silent GPS + Favorite Place match afterwards.
@pragma('vm:entry-point')
Future<void> tronoWidgetBackgroundCallback(Uri? uri) async {
  final payload = WidgetLogPayload.tryParseUri(uri);
  if (payload == null) return;
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.init();

  final now = DateTime.now();
  final log = BathroomLog(
    id: const Uuid().v4(),
    type: payload.type,
    timestamp: now,
    durationSeconds: payload.durationSeconds,
    shareLevel: settings.defaultShareLevel,
    createdAt: now,
    updatedAt: now,
  );

  // 1. Persist immediately to SQLite before any slow GPS work
  final repo = LocalBathroomRepository.instance;
  await repo.upsertLog(log);

  // 2. Sync accurate stats + today_date back to the widget immediately
  final allLogs = await repo.getAllLogs();
  final stats = StatsCalculator.calculate(
    allLogs,
    homeLat: settings.homeLat,
    homeLng: settings.homeLng,
  );
  await WidgetSyncService.syncStats(stats, lastType: payload.type);

  // 3. Optional non-blocking silent GPS + Favorite Place enrichment
  if (settings.autoGpsEnabled) {
    final pos = await LocationService.tryGetPositionSilently();
    if (pos != null) {
      final matched = FavoritePlacesEngine.matchPlace(
        pos.latitude,
        pos.longitude,
        settings.favoritePlaces,
      );
      final locKind = matched?.locationKind ??
          LocationService.classifyAgainstHome(
            pos.latitude,
            pos.longitude,
            homeLat: settings.homeLat,
            homeLng: settings.homeLng,
          );
      final enriched = log.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        locationKind: locKind,
        placeLabel: matched?.name,
        updatedAt: DateTime.now(),
      );
      await repo.upsertLog(enriched);
    }
  }
}

class WidgetSyncService {
  static String? _lastStatsSignature;

  static String formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<void> initialize() async {
    try {
      await HomeWidget.registerInteractivityCallback(
        tronoWidgetBackgroundCallback,
      );
    } catch (e) {
      debugPrint('HomeWidget init skipped: $e');
    }
  }

  static Future<void> syncStats(
    StatsSummary stats, {
    BathroomType? lastType,
    DateTime? now,
  }) async {
    final dateKey = formatDateKey(now ?? DateTime.now());
    final avgStr = stats.weeklyAvg.avgPoopPerDay.toStringAsFixed(1);
    final signature =
        '$dateKey|${stats.todayTotal}|${stats.todayPoop}|$avgStr|${stats.currentStreak}|${lastType?.dbValue}';
    if (_lastStatsSignature == signature) return;

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(kWidgetTodayDateKey, dateKey),
        HomeWidget.saveWidgetData<int>('today_count', stats.todayTotal),
        HomeWidget.saveWidgetData<int>('today_poop', stats.todayPoop),
        HomeWidget.saveWidgetData<String>('avg_daily', avgStr),
        HomeWidget.saveWidgetData<int>('streak', stats.currentStreak),
        if (lastType != null)
          HomeWidget.saveWidgetData<String>('last_emoji', lastType.emoji),
      ]);
      await HomeWidget.updateWidget(
        androidName: kAndroidWidgetProvider,
        qualifiedAndroidName: 'com.trono.trono.$kAndroidWidgetProvider',
      );
      _lastStatsSignature = signature;
    } catch (e) {
      debugPrint('HomeWidget sync skipped: $e');
    }
  }

  /// Syncs the active live timer start timestamp (epoch ms) to the Android
  /// Home Screen Widget so its native `<Chronometer>` stays 2-way synced.
  static Future<void> syncTimerState(DateTime? timerStart) async {
    try {
      await HomeWidget.saveWidgetData<int>(
        kWidgetTimerStartKey,
        timerStart?.millisecondsSinceEpoch ?? 0,
      );
      await HomeWidget.updateWidget(
        androidName: kAndroidWidgetProvider,
        qualifiedAndroidName: 'com.trono.trono.$kAndroidWidgetProvider',
      );
    } catch (e) {
      debugPrint('HomeWidget timer sync skipped: $e');
    }
  }

  /// Reads the active timer start timestamp stored by the Android widget, or
  /// `null` if no widget timer is running.
  static Future<DateTime?> readWidgetTimerStart() async {
    try {
      final raw = await HomeWidget.getWidgetData<int>(kWidgetTimerStartKey);
      if (raw == null || raw <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {
      return null;
    }
  }
}
