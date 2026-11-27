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
/// timer directly on the Android Home Screen Widget. Also captures GPS silently
/// and matches Favorite Places / Home if enabled.
@pragma('vm:entry-point')
Future<void> tronoWidgetBackgroundCallback(Uri? uri) async {
  final payload = WidgetLogPayload.tryParseUri(uri);
  if (payload == null) return;
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.init();

  double? lat;
  double? lng;
  LocationKind? locKind;
  String? placeLabel;

  if (settings.autoGpsEnabled) {
    final pos = await LocationService.tryGetPositionSilently();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      final matched = FavoritePlacesEngine.matchPlace(
        lat,
        lng,
        settings.favoritePlaces,
      );
      if (matched != null) {
        locKind = matched.locationKind;
        placeLabel = matched.name;
      } else {
        locKind = LocationService.classifyAgainstHome(
          lat,
          lng,
          homeLat: settings.homeLat,
          homeLng: settings.homeLng,
        );
      }
    }
  }

  final now = DateTime.now();
  final log = BathroomLog(
    id: const Uuid().v4(),
    type: payload.type,
    timestamp: now,
    durationSeconds: payload.durationSeconds,
    locationKind: locKind,
    latitude: lat,
    longitude: lng,
    placeLabel: placeLabel,
    shareLevel: settings.defaultShareLevel,
    createdAt: now,
    updatedAt: now,
  );

  final repo = LocalBathroomRepository.instance;
  await repo.upsertLog(log);
  final allLogs = await repo.getAllLogs();
  final stats = StatsCalculator.calculate(
    allLogs,
    homeLat: settings.homeLat,
    homeLng: settings.homeLng,
  );
  await WidgetSyncService.syncStats(stats, lastType: payload.type);
}

class WidgetSyncService {
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
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<int>('today_count', stats.todayTotal),
        HomeWidget.saveWidgetData<int>('today_poop', stats.todayPoop),
        HomeWidget.saveWidgetData<String>(
          'avg_daily',
          stats.weeklyAvg.avgPoopPerDay.toStringAsFixed(1),
        ),
        HomeWidget.saveWidgetData<int>('streak', stats.currentStreak),
        if (lastType != null)
          HomeWidget.saveWidgetData<String>('last_emoji', lastType.emoji),
      ]);
      await HomeWidget.updateWidget(
        androidName: kAndroidWidgetProvider,
        qualifiedAndroidName: 'com.trono.trono.$kAndroidWidgetProvider',
      );
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
