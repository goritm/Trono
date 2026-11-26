import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../services/location_service.dart';
import 'bathroom_log.dart';

/// Single Monday–Sunday calendar week bucket for the 8-week trend chart.
class WeeklyTrendBucket {
  const WeeklyTrendBucket({
    required this.weekStart,
    required this.poopCount,
    required this.avgPerDay,
    required this.avgBristol,
    required this.isCurrentWeek,
  });

  /// Local midnight on Monday of this calendar week.
  final DateTime weekStart;
  final int poopCount;
  final double avgPerDay;
  final double? avgBristol;
  final bool isCurrentWeek;

  /// Local midnight on Sunday of this calendar week.
  DateTime get weekEnd =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
}

/// Pure snapshot comparing the current calendar month against the previous month,
/// plus an 8-week rolling Monday–Sunday trend.
class MonthlyComparisonSnapshot {
  const MonthlyComparisonSnapshot({
    required this.currentMonth,
    required this.previousMonth,
    required this.currentMonthPoops,
    required this.previousMonthPoops,
    required this.poopsDeltaPercent,
    required this.currentMonthAvgPerDay,
    required this.previousMonthAvgPerDay,
    required this.currentMonthAwayPercent,
    required this.previousMonthAwayPercent,
    required this.currentMonthAvgBristol,
    required this.previousMonthAvgBristol,
    required this.idealBristolPercent,
    required this.weeklyTrend,
  });

  final DateTime currentMonth;
  final DateTime previousMonth;
  final int currentMonthPoops;
  final int previousMonthPoops;

  /// Rounded percentage change vs previous month, or `null` when previous month has 0 poops.
  final int? poopsDeltaPercent;
  final double currentMonthAvgPerDay;
  final double previousMonthAvgPerDay;

  /// Rounded away-from-home percentage (0..100), or `null` if no logs had location data.
  final int? currentMonthAwayPercent;
  final int? previousMonthAwayPercent;

  final double? currentMonthAvgBristol;
  final double? previousMonthAvgBristol;

  /// Percentage of current-month Bristol-tagged poops in types 3 or 4, or `null` if none.
  final int? idealBristolPercent;

  /// Exactly 8 Monday–Sunday buckets ordered oldest to newest.
  final List<WeeklyTrendBucket> weeklyTrend;

  double get weeklyAveragePoops {
    if (weeklyTrend.isEmpty) return 0;
    final total = weeklyTrend.fold<int>(0, (sum, b) => sum + b.poopCount);
    return total / weeklyTrend.length;
  }

  bool get hasMonthlyData => currentMonthPoops > 0 || previousMonthPoops > 0;
}

class MonthlyComparisonEngine {
  static const int trendWeeksCount = 8;

  static LocationKind? _resolveLocation(
    BathroomLog log, {
    double? homeLat,
    double? homeLng,
  }) {
    return log.effectiveLocationKind ??
        (log.hasCoordinates
            ? LocationService.classifyAgainstHome(
                log.latitude!,
                log.longitude!,
                homeLat: homeLat,
                homeLng: homeLng,
              )
            : null);
  }

  static MonthlyComparisonSnapshot compute(
    List<BathroomLog> logs, {
    DateTime? now,
    double? homeLat,
    double? homeLng,
  }) {
    final current = now ?? DateTime.now();
    final today = DateUtils.dateOnly(current);

    final currentMonth = DateTime(today.year, today.month, 1);
    final previousMonth = DateTime(today.year, today.month - 1, 1);
    final daysElapsedCurrentMonth = math.max(1, today.day);
    final daysInPreviousMonth =
        DateUtils.getDaysInMonth(previousMonth.year, previousMonth.month);

    int curPoops = 0;
    int prevPoops = 0;

    int curHome = 0;
    int curAway = 0;
    int prevHome = 0;
    int prevAway = 0;

    int curBristolSum = 0;
    int curBristolCount = 0;
    int curIdealBristolCount = 0;

    int prevBristolSum = 0;
    int prevBristolCount = 0;

    // 8 calendar weeks (Monday–Sunday), oldest (index 0) to current week (index 7).
    final currentWeekMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final weekStarts = List<DateTime>.generate(
      trendWeeksCount,
      (i) => DateTime(
        currentWeekMonday.year,
        currentWeekMonday.month,
        currentWeekMonday.day - (trendWeeksCount - 1 - i) * 7,
      ),
    );
    final weekPoopCounts = List<int>.filled(trendWeeksCount, 0);
    final weekBristolSums = List<int>.filled(trendWeeksCount, 0);
    final weekBristolCounts = List<int>.filled(trendWeeksCount, 0);
    final oldestWeekStart = weekStarts.first;
    final currentWeekEnd = DateTime(
      currentWeekMonday.year,
      currentWeekMonday.month,
      currentWeekMonday.day + 6,
    );

    for (final log in logs) {
      if (log.deletedAt != null) continue;
      if (!log.type.includesPoop) continue;

      final ts = log.timestamp;
      final logDay = DateUtils.dateOnly(ts);
      final bristol = log.bristolType;
      final hasValidBristol = bristol != null && bristol >= 1 && bristol <= 7;

      // Current month aggregation
      if (ts.year == currentMonth.year && ts.month == currentMonth.month) {
        curPoops++;
        final loc = _resolveLocation(log, homeLat: homeLat, homeLng: homeLng);
        if (loc == LocationKind.home) {
          curHome++;
        } else if (loc != null && loc.isAwayFromHome) {
          curAway++;
        }
        if (hasValidBristol) {
          curBristolSum += bristol;
          curBristolCount++;
          if (bristol == 3 || bristol == 4) {
            curIdealBristolCount++;
          }
        }
      } else if (ts.year == previousMonth.year &&
          ts.month == previousMonth.month) {
        // Previous month aggregation
        prevPoops++;
        final loc = _resolveLocation(log, homeLat: homeLat, homeLng: homeLng);
        if (loc == LocationKind.home) {
          prevHome++;
        } else if (loc != null && loc.isAwayFromHome) {
          prevAway++;
        }
        if (hasValidBristol) {
          prevBristolSum += bristol;
          prevBristolCount++;
        }
      }

      // 8-week Monday–Sunday bucketing (DST-safe via UTC day difference)
      if (!logDay.isBefore(oldestWeekStart) && !logDay.isAfter(currentWeekEnd)) {
        final daysFromOldest = DateTime.utc(logDay.year, logDay.month, logDay.day)
            .difference(
              DateTime.utc(
                oldestWeekStart.year,
                oldestWeekStart.month,
                oldestWeekStart.day,
              ),
            )
            .inDays;
        final bucketIdx = daysFromOldest ~/ 7;
        if (bucketIdx >= 0 && bucketIdx < trendWeeksCount) {
          weekPoopCounts[bucketIdx]++;
          if (hasValidBristol) {
            weekBristolSums[bucketIdx] += bristol;
            weekBristolCounts[bucketIdx]++;
          }
        }
      }
    }

    final int? poopsDeltaPercent = prevPoops == 0
        ? null
        : (((curPoops - prevPoops) * 100) / prevPoops).round();

    final curClassified = curHome + curAway;
    final prevClassified = prevHome + prevAway;

    final int? curAwayPercent = curClassified == 0
        ? null
        : ((curAway * 100) / curClassified).round();
    final int? prevAwayPercent = prevClassified == 0
        ? null
        : ((prevAway * 100) / prevClassified).round();

    final double? curAvgBristol =
        curBristolCount == 0 ? null : curBristolSum / curBristolCount;
    final double? prevAvgBristol =
        prevBristolCount == 0 ? null : prevBristolSum / prevBristolCount;
    final int? idealBristolPercent = curBristolCount == 0
        ? null
        : ((curIdealBristolCount * 100) / curBristolCount).round();

    final daysElapsedCurrentWeek = math.max(1, today.weekday);
    final weeklyTrend = List<WeeklyTrendBucket>.generate(trendWeeksCount, (i) {
      final isCurrent = i == trendWeeksCount - 1;
      final daysDivisor = isCurrent ? daysElapsedCurrentWeek : 7;
      final count = weekPoopCounts[i];
      final bCount = weekBristolCounts[i];
      return WeeklyTrendBucket(
        weekStart: weekStarts[i],
        poopCount: count,
        avgPerDay: count / daysDivisor,
        avgBristol: bCount == 0 ? null : weekBristolSums[i] / bCount,
        isCurrentWeek: isCurrent,
      );
    });

    return MonthlyComparisonSnapshot(
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      currentMonthPoops: curPoops,
      previousMonthPoops: prevPoops,
      poopsDeltaPercent: poopsDeltaPercent,
      currentMonthAvgPerDay: curPoops / daysElapsedCurrentMonth,
      previousMonthAvgPerDay: prevPoops / daysInPreviousMonth,
      currentMonthAwayPercent: curAwayPercent,
      previousMonthAwayPercent: prevAwayPercent,
      currentMonthAvgBristol: curAvgBristol,
      previousMonthAvgBristol: prevAvgBristol,
      idealBristolPercent: idealBristolPercent,
      weeklyTrend: weeklyTrend,
    );
  }
}
