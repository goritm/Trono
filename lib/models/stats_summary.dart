import 'package:material_ui/material_ui.dart';

import 'bathroom_log.dart';

enum StatsPeriod { week, month, allTime }

class PeriodAverage {
  const PeriodAverage({
    required this.totalVisits,
    required this.poopVisits,
    required this.daysSpan,
  });

  final int totalVisits;
  final int poopVisits;
  final int daysSpan;

  double get avgTotalPerDay => daysSpan <= 0 ? 0 : totalVisits / daysSpan;
  double get avgPoopPerDay => daysSpan <= 0 ? 0 : poopVisits / daysSpan;
}

class StatsSummary {
  const StatsSummary({
    required this.todayTotal,
    required this.todayPoop,
    required this.weeklyAvg,
    required this.monthlyAvg,
    required this.allTimeAvg,
    required this.dailyCounts,
    required this.hourlyCounts,
    required this.peakHour,
    required this.currentStreak,
    required this.longestStreak,
    required this.recordDayCount,
    required this.recordDayDate,
    required this.longestSessionSeconds,
    required this.longestSessionDate,
    required this.totalBathroomSeconds,
  });

  final int todayTotal;
  final int todayPoop;
  final PeriodAverage weeklyAvg;
  final PeriodAverage monthlyAvg;
  final PeriodAverage allTimeAvg;
  final Map<DateTime, int> dailyCounts;
  final List<int> hourlyCounts; // length 24
  final int? peakHour;
  final int currentStreak;
  final int longestStreak;
  final int recordDayCount;
  final DateTime? recordDayDate;
  final int longestSessionSeconds;
  final DateTime? longestSessionDate;
  final int totalBathroomSeconds;

  PeriodAverage averageFor(StatsPeriod period) => switch (period) {
    StatsPeriod.week => weeklyAvg,
    StatsPeriod.month => monthlyAvg,
    StatsPeriod.allTime => allTimeAvg,
  };
}

class StatsCalculator {
  /// Default estimated duration (in seconds) used when computing total
  /// estimated bathroom time for logs without an explicit duration.
  static int _estimatedSeconds(BathroomLog log) {
    if (log.durationSeconds != null && log.durationSeconds! > 0) {
      return log.durationSeconds!;
    }
    return switch (log.type) {
      BathroomType.poop => 300,
      BathroomType.falseAlarm => 120,
    };
  }

  static StatsSummary calculate(List<BathroomLog> logs, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateUtils.dateOnly(current);

    final dailyCounts = <DateTime, int>{};
    final hourlyCounts = List<int>.filled(24, 0);

    int todayTotal = 0;
    int todayPoop = 0;

    final weekStart = today.subtract(const Duration(days: 6));
    final monthStart = today.subtract(const Duration(days: 29));

    int weekTotal = 0;
    int weekPoop = 0;
    int monthTotal = 0;
    int monthPoop = 0;
    int allTotal = logs.length;
    int allPoop = 0;

    DateTime? firstDay;
    int longestSessionSeconds = 0;
    DateTime? longestSessionDate;
    int totalBathroomSeconds = 0;

    for (final log in logs) {
      final day = DateUtils.dateOnly(log.timestamp);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      hourlyCounts[log.timestamp.hour]++;

      if (firstDay == null || day.isBefore(firstDay)) {
        firstDay = day;
      }

      final isPoop = log.type.includesPoop;
      if (isPoop) allPoop++;

      if (day == today) {
        todayTotal++;
        if (isPoop) todayPoop++;
      }

      if (!day.isBefore(weekStart) && !day.isAfter(today)) {
        weekTotal++;
        if (isPoop) weekPoop++;
      }

      if (!day.isBefore(monthStart) && !day.isAfter(today)) {
        monthTotal++;
        if (isPoop) monthPoop++;
      }

      final dur = log.durationSeconds ?? 0;
      if (dur > longestSessionSeconds) {
        longestSessionSeconds = dur;
        longestSessionDate = log.timestamp;
      }
      totalBathroomSeconds += _estimatedSeconds(log);
    }

    // Active days span for averages: if user just started 2 days ago, use
    // actual days since first log (capped to 7 / 30) so averages are honest!
    final daysSinceFirst = firstDay == null
        ? 0
        : today.difference(firstDay).inDays + 1;
    final weekSpan = daysSinceFirst == 0 ? 0 : daysSinceFirst.clamp(1, 7);
    final monthSpan = daysSinceFirst == 0 ? 0 : daysSinceFirst.clamp(1, 30);

    // Record day
    int recordDayCount = 0;
    DateTime? recordDayDate;
    dailyCounts.forEach((date, count) {
      if (count > recordDayCount ||
          (count == recordDayCount &&
              (recordDayDate == null || date.isAfter(recordDayDate!)))) {
        recordDayCount = count;
        recordDayDate = date;
      }
    });

    // Peak hour
    int? peakHour;
    int maxHourCount = 0;
    for (int h = 0; h < 24; h++) {
      if (hourlyCounts[h] > maxHourCount) {
        maxHourCount = hourlyCounts[h];
        peakHour = h;
      }
    }

    // Streaks
    final sortedDays = dailyCounts.keys.toList()..sort();
    int longestStreak = 0;
    int run = 0;
    for (int i = 0; i < sortedDays.length; i++) {
      if (i == 0 || sortedDays[i].difference(sortedDays[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longestStreak) longestStreak = run;
    }

    int currentStreak = 0;
    DateTime cursor = dailyCounts.containsKey(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (dailyCounts.containsKey(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return StatsSummary(
      todayTotal: todayTotal,
      todayPoop: todayPoop,
      weeklyAvg: PeriodAverage(
        totalVisits: weekTotal,
        poopVisits: weekPoop,
        daysSpan: weekSpan,
      ),
      monthlyAvg: PeriodAverage(
        totalVisits: monthTotal,
        poopVisits: monthPoop,
        daysSpan: monthSpan,
      ),
      allTimeAvg: PeriodAverage(
        totalVisits: allTotal,
        poopVisits: allPoop,
        daysSpan: daysSinceFirst,
      ),
      dailyCounts: dailyCounts,
      hourlyCounts: hourlyCounts,
      peakHour: peakHour,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      recordDayCount: recordDayCount,
      recordDayDate: recordDayDate,
      longestSessionSeconds: longestSessionSeconds,
      longestSessionDate: longestSessionDate,
      totalBathroomSeconds: totalBathroomSeconds,
    );
  }
}
