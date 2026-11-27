import 'package:material_ui/material_ui.dart';

import 'bathroom_log.dart';
import 'stats_summary.dart';

class LogEarnings {
  const LogEarnings({
    required this.amount,
    required this.isEstimated,
    required this.secondsUsed,
  });

  final double amount;
  final bool isEstimated;
  final int secondsUsed;
}

class PaidOnThroneSummary {
  const PaidOnThroneSummary({
    required this.workVisitsTotal,
    required this.workVisitsThisMonth,
    required this.workSecondsTotal,
    required this.workSecondsThisMonth,
    required this.earnedThisMonth,
    required this.earnedAllTime,
  });

  final int workVisitsTotal;
  final int workVisitsThisMonth;
  final int workSecondsTotal;
  final int workSecondsThisMonth;
  final double earnedThisMonth;
  final double earnedAllTime;
}

enum InsightType {
  busiestWeekday,
  topBristol,
  topTriggerTag,
  awaySuperpower,
  timeMovies,
}

class TronoInsight {
  const TronoInsight({
    required this.type,
    required this.emoji,
    this.intValue = 0,
    this.intValue2 = 0,
    this.stringValue = '',
  });

  final InsightType type;
  final String emoji;
  final int intValue;
  final int intValue2;
  final String stringValue;
}

enum WrappedPeriod { thisMonth, allTime }

enum WrappedArchetype {
  nomad,
  officeKing,
  nightOwl,
  coffeeRocket,
  swissClock,
  throneRegular,
}

class WrappedSnapshot {
  const WrappedSnapshot({
    required this.period,
    required this.totalPoops,
    required this.avgPerDay,
    required this.awayPercent,
    required this.hasLocationRatio,
    required this.peakHour,
    required this.topBristol,
    required this.totalSeconds,
    required this.earnedAtWork,
    required this.distinctSpots,
    required this.archetype,
  });

  final WrappedPeriod period;
  final int totalPoops;
  final double avgPerDay;
  final int awayPercent;
  final bool hasLocationRatio;
  final int? peakHour;
  final int? topBristol;
  final int totalSeconds;
  final double earnedAtWork;
  final int distinctSpots;
  final WrappedArchetype archetype;
}

class InsightsEngine {
  static int _estimatedSeconds(BathroomLog log) {
    if (log.durationSeconds != null && log.durationSeconds! > 0) {
      return log.durationSeconds!;
    }
    return log.type == BathroomType.poop ? 300 : 120;
  }

  /// Calculates local-only Paid on the Throne earnings for a single log.
  /// Returns `null` when the log is not a work/WFH visit or no pay rate is set.
  static LogEarnings? calculateLogEarnings(
    BathroomLog log, {
    required double? hourlyRate,
  }) {
    if (!log.isWorkVisit || hourlyRate == null || hourlyRate <= 0) {
      return null;
    }
    final hasExact = log.durationSeconds != null && log.durationSeconds! > 0;
    final secs = hasExact ? log.durationSeconds! : _estimatedSeconds(log);
    return LogEarnings(
      amount: (secs / 3600.0) * hourlyRate,
      isEstimated: !hasExact,
      secondsUsed: secs,
    );
  }

  /// Sums local-only Paid on the Throne earnings across a day's logs.
  /// Returns `0.0` when `hourlyRate` is unset or non-positive.
  static double calculateTodayPaid(
    List<BathroomLog> todayLogs, {
    required double? hourlyRate,
  }) {
    if (hourlyRate == null || hourlyRate <= 0) return 0.0;
    double sum = 0.0;
    for (final log in todayLogs) {
      final earned = calculateLogEarnings(log, hourlyRate: hourlyRate);
      if (earned != null) sum += earned.amount;
    }
    return sum;
  }

  static PaidOnThroneSummary calculatePaidOnThrone(
    List<BathroomLog> logs, {
    required double? hourlyRate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    int totalVisits = 0;
    int monthVisits = 0;
    int totalSecs = 0;
    int monthSecs = 0;

    for (final l in logs) {
      if (!l.isWorkVisit) continue;
      final secs = _estimatedSeconds(l);
      totalVisits++;
      totalSecs += secs;
      if (l.timestamp.year == current.year &&
          l.timestamp.month == current.month) {
        monthVisits++;
        monthSecs += secs;
      }
    }

    final rate = hourlyRate ?? 0.0;
    return PaidOnThroneSummary(
      workVisitsTotal: totalVisits,
      workVisitsThisMonth: monthVisits,
      workSecondsTotal: totalSecs,
      workSecondsThisMonth: monthSecs,
      earnedThisMonth: rate > 0 ? (monthSecs / 3600.0) * rate : 0.0,
      earnedAllTime: rate > 0 ? (totalSecs / 3600.0) * rate : 0.0,
    );
  }

  static List<TronoInsight> generateInsights(
    List<BathroomLog> logs,
    StatsSummary stats,
  ) {
    final poops = logs.where((l) => l.type.includesPoop).toList();
    if (poops.isEmpty) return const [];

    final insights = <TronoInsight>[];

    // 1. Busiest weekday (1=Mon .. 7=Sun)
    final weekdayCounts = List<int>.filled(8, 0);
    for (final l in poops) {
      weekdayCounts[l.timestamp.weekday]++;
    }
    int topWeekday = 1;
    for (int d = 2; d <= 7; d++) {
      if (weekdayCounts[d] > weekdayCounts[topWeekday]) topWeekday = d;
    }
    if (poops.length >= 3) {
      insights.add(
        TronoInsight(
          type: InsightType.busiestWeekday,
          emoji: '📆',
          intValue: topWeekday,
          intValue2: weekdayCounts[topWeekday],
        ),
      );
    }

    // 2. Top Bristol type
    final bristolCounts = <int, int>{};
    int bristolTotal = 0;
    for (final l in poops) {
      if (l.bristolType != null) {
        bristolCounts[l.bristolType!] = (bristolCounts[l.bristolType!] ?? 0) + 1;
        bristolTotal++;
      }
    }
    if (bristolTotal >= 2) {
      final top = bristolCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final pct = ((top.value / bristolTotal) * 100).round();
      insights.add(
        TronoInsight(
          type: InsightType.topBristol,
          emoji: '🎯',
          intValue: top.key,
          intValue2: pct,
        ),
      );
    }

    // 3. Top food / digestive trigger tag
    const triggerKeys = [
      'coffee',
      'spicy',
      'dairy',
      'alcohol',
      'fast_food',
      'fiber',
      'sweets',
      'stress',
    ];
    final tagCounts = <String, int>{};
    for (final l in poops) {
      for (final t in l.tags) {
        if (triggerKeys.contains(t)) {
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
      }
    }
    if (tagCounts.isNotEmpty) {
      final topTag = tagCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      if (topTag.value >= 2) {
        final pct = ((topTag.value / poops.length) * 100).round();
        insights.add(
          TronoInsight(
            type: InsightType.topTriggerTag,
            emoji: '⚡',
            stringValue: topTag.key,
            intValue: pct,
            intValue2: topTag.value,
          ),
        );
      }
    }

    // 4. Away survival superpower
    if (stats.classifiedLocationCount >= 3 && stats.awayPercent >= 40) {
      insights.add(
        TronoInsight(
          type: InsightType.awaySuperpower,
          emoji: '🏕️',
          intValue: stats.awayPercent.round(),
          intValue2: stats.awayPoopCount,
        ),
      );
    }

    // 5. Total time equivalent in 90-min movies
    final totalMins = stats.totalBathroomSeconds ~/ 60;
    if (totalMins >= 30) {
      final movies = (totalMins / 90.0).round().clamp(1, 999);
      insights.add(
        TronoInsight(
          type: InsightType.timeMovies,
          emoji: '🎬',
          intValue: totalMins,
          intValue2: movies,
        ),
      );
    }

    return insights;
  }

  static WrappedSnapshot buildWrapped(
    List<BathroomLog> allLogs, {
    required WrappedPeriod period,
    double? homeLat,
    double? homeLng,
    double? hourlyRate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final filtered = period == WrappedPeriod.allTime
        ? allLogs
        : allLogs
            .where(
              (l) =>
                  l.timestamp.year == current.year &&
                  l.timestamp.month == current.month,
            )
            .toList();

    final periodStats = StatsCalculator.calculate(
      filtered,
      now: current,
      homeLat: homeLat,
      homeLng: homeLng,
    );
    final paid = calculatePaidOnThrone(
      filtered,
      hourlyRate: hourlyRate,
      now: current,
    );

    final poops = filtered.where((l) => l.type.includesPoop).toList();
    final bristolCounts = <int, int>{};
    int nightLogs = 0;
    int coffeeLogs = 0;
    int workLogs = 0;
    for (final l in poops) {
      if (l.bristolType != null) {
        bristolCounts[l.bristolType!] = (bristolCounts[l.bristolType!] ?? 0) + 1;
      }
      if (l.timestamp.hour >= 0 && l.timestamp.hour < 5) nightLogs++;
      if (l.tags.contains('coffee')) coffeeLogs++;
      if (l.isWorkVisit) workLogs++;
    }
    final topBristol = bristolCounts.isEmpty
        ? null
        : bristolCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    // Pick a fun, accurate archetype title
    final WrappedArchetype archetype;
    if (periodStats.classifiedLocationCount >= 3 &&
        periodStats.awayPercent >= 50) {
      archetype = WrappedArchetype.nomad;
    } else if (workLogs >= 3 && workLogs >= poops.length * 0.35) {
      archetype = WrappedArchetype.officeKing;
    } else if (coffeeLogs >= 3 && coffeeLogs >= poops.length * 0.3) {
      archetype = WrappedArchetype.coffeeRocket;
    } else if (nightLogs >= 2) {
      archetype = WrappedArchetype.nightOwl;
    } else if (topBristol == 4 && poops.length >= 3) {
      archetype = WrappedArchetype.swissClock;
    } else {
      archetype = WrappedArchetype.throneRegular;
    }

    // Honest daily average for the selected period
    final double avgPerDay;
    if (period == WrappedPeriod.thisMonth) {
      final firstOfMonth = DateTime(current.year, current.month, 1);
      final daysInMonthSoFar =
          DateUtils.dateOnly(current).difference(firstOfMonth).inDays + 1;
      avgPerDay = daysInMonthSoFar <= 0 ? 0 : poops.length / daysInMonthSoFar;
    } else {
      avgPerDay = periodStats.allTimeAvg.avgPoopPerDay;
    }

    return WrappedSnapshot(
      period: period,
      totalPoops: poops.length,
      avgPerDay: avgPerDay,
      awayPercent: periodStats.awayPercent.round(),
      hasLocationRatio: periodStats.classifiedLocationCount > 0,
      peakHour: periodStats.peakHour,
      topBristol: topBristol,
      totalSeconds: periodStats.totalBathroomSeconds,
      earnedAtWork: period == WrappedPeriod.thisMonth
          ? paid.earnedThisMonth
          : paid.earnedAllTime,
      distinctSpots: periodStats.distinctSpotsCount,
      archetype: archetype,
    );
  }
}
