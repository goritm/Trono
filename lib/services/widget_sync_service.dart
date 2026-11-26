import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/bathroom_log.dart';
import '../models/stats_summary.dart';

const String kAndroidWidgetProvider = 'TronoWidgetProvider';

/// Background entrypoint invoked when the user taps a quick-log button
/// directly on the Android Home Screen Widget.
@pragma('vm:entry-point')
Future<void> tronoWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  WidgetsFlutterBinding.ensureInitialized();

  final typeParam = uri.queryParameters['type'];
  if (typeParam == null) return;

  final type = BathroomType.fromDb(typeParam);
  final now = DateTime.now();
  final log = BathroomLog(
    id: const Uuid().v4(),
    type: type,
    timestamp: now,
    createdAt: now,
    updatedAt: now,
  );

  final repo = LocalBathroomRepository.instance;
  await repo.upsertLog(log);
  final allLogs = await repo.getAllLogs();
  final stats = StatsCalculator.calculate(allLogs);
  await WidgetSyncService.syncStats(stats, lastType: type);
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
}
