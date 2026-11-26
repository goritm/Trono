import 'package:material_ui/material_ui.dart';

import '../services/location_service.dart';
import 'bathroom_log.dart';

class UserRank {
  const UserRank({
    required this.level,
    required this.id,
    required this.minXp,
    required this.emoji,
  });

  final int level;
  final String id;
  final int minXp;
  final String emoji;
}

class AchievementProgress {
  const AchievementProgress({
    required this.id,
    required this.emoji,
    required this.current,
    required this.target,
    required this.xpReward,
  });

  final String id;
  final String emoji;
  final int current;
  final int target;
  final int xpReward;

  bool get isUnlocked => current >= target;
  double get progress => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
}

class GamificationSnapshot {
  const GamificationSnapshot({
    required this.totalXp,
    required this.currentRank,
    required this.nextRank,
    required this.rankProgress,
    required this.achievements,
  });

  final int totalXp;
  final UserRank currentRank;
  final UserRank? nextRank;
  final double rankProgress;
  final List<AchievementProgress> achievements;

  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;
}

class GamificationEngine {
  static const List<UserRank> ranks = [
    UserRank(level: 1, id: 'rookie', minXp: 0, emoji: '🧻'),
    UserRank(level: 2, id: 'regular', minXp: 100, emoji: '🚽'),
    UserRank(level: 3, id: 'navigator', minXp: 300, emoji: '🧭'),
    UserRank(level: 4, id: 'duke', minXp: 700, emoji: '🎩'),
    UserRank(level: 5, id: 'master', minXp: 1400, emoji: '👑'),
    UserRank(level: 6, id: 'legend', minXp: 2800, emoji: '🏆'),
    UserRank(level: 7, id: 'deity', minXp: 5000, emoji: '✨'),
  ];

  static GamificationSnapshot evaluate(
    List<BathroomLog> logs, {
    double? homeLat,
    double? homeLng,
  }) {
    final totalLogs = logs.length;
    final poopLogs = logs.where((l) => l.type.includesPoop).length;
    final spicyLogs = logs.where((l) => l.tags.contains('spicy')).length;
    final falseAlarms =
        logs.where((l) => l.type == BathroomType.falseAlarm).length;
    final detailedLogs = logs.where((l) => l.hasDetails).length;
    final nightOwlLogs = logs
        .where((l) => l.timestamp.hour >= 0 && l.timestamp.hour < 5)
        .length;
    final earlyBirdLogs = logs
        .where((l) => l.timestamp.hour >= 5 && l.timestamp.hour < 8)
        .length;
    final workLogs = logs.where((l) => l.isWorkVisit).length;
    final workMinutes = logs
            .where((l) => l.isWorkVisit)
            .fold<int>(
              0,
              (sum, l) =>
                  sum +
                  ((l.durationSeconds != null && l.durationSeconds! > 0)
                      ? l.durationSeconds!
                      : (l.type.includesPoop ? 300 : 120)),
            ) ~/
        60;
    final coffeeLogs = logs.where((l) => l.tags.contains('coffee')).length;
    final perfectBristolLogs = logs.where((l) => l.bristolType == 4).length;
    final epicSizeLogs = logs.where((l) => l.size == PoopSize.epic).length;
    final marathonLogs =
        logs.where((l) => (l.durationSeconds ?? 0) >= 900).length;

    // V1.5 Territory metrics
    int awayPoopLogs = 0;
    double maxDistKm = 0;
    for (final l in logs) {
      if (l.type.includesPoop) {
        final loc = l.effectiveLocationKind ??
            (l.hasCoordinates
                ? LocationService.classifyAgainstHome(
                    l.latitude!,
                    l.longitude!,
                    homeLat: homeLat,
                    homeLng: homeLng,
                  )
                : null);
        if (loc != null && loc.isAwayFromHome) awayPoopLogs++;
      }
      if (l.hasCoordinates && homeLat != null && homeLng != null) {
        final dKm = LocationService.distanceMeters(
              homeLat,
              homeLng,
              l.latitude!,
              l.longitude!,
            ) /
            1000.0;
        if (dKm > maxDistKm) maxDistKm = dKm;
      }
    }
    final distinctSpots = LocationService.countDistinctSpots(logs);

    // Visits per day & max streak
    final dayCounts = <DateTime, int>{};
    for (final log in logs) {
      final d = DateUtils.dateOnly(log.timestamp);
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }
    final maxInOneDay = dayCounts.values.isEmpty
        ? 0
        : dayCounts.values.reduce((a, b) => a > b ? a : b);
    final longestStreak = _computeLongestStreak(dayCounts.keys);

    final achievements = <AchievementProgress>[
      AchievementProgress(
        id: 'first_visit',
        emoji: '🎉',
        current: totalLogs,
        target: 1,
        xpReward: 25,
      ),
      AchievementProgress(
        id: 'survival_fittest',
        emoji: '🏕️',
        current: awayPoopLogs,
        target: 5,
        xpReward: 80,
      ),
      AchievementProgress(
        id: 'throne_nomad',
        emoji: '🌍',
        current: awayPoopLogs,
        target: 15,
        xpReward: 150,
      ),
      AchievementProgress(
        id: 'territory_conqueror',
        emoji: '🗺️',
        current: distinctSpots,
        target: 5,
        xpReward: 120,
      ),
      AchievementProgress(
        id: 'international_drop',
        emoji: '✈️',
        current: maxDistKm.floor(),
        target: 50,
        xpReward: 200,
      ),
      AchievementProgress(
        id: 'hat_trick',
        emoji: '🎩',
        current: maxInOneDay,
        target: 3,
        xpReward: 40,
      ),
      AchievementProgress(
        id: 'turbo_day',
        emoji: '🚀',
        current: maxInOneDay,
        target: 6,
        xpReward: 80,
      ),
      AchievementProgress(
        id: 'streak_7',
        emoji: '🔥',
        current: longestStreak,
        target: 7,
        xpReward: 100,
      ),
      AchievementProgress(
        id: 'streak_30',
        emoji: '💎',
        current: longestStreak,
        target: 30,
        xpReward: 300,
      ),
      AchievementProgress(
        id: 'night_owl',
        emoji: '🦉',
        current: nightOwlLogs,
        target: 1,
        xpReward: 40,
      ),
      AchievementProgress(
        id: 'early_bird',
        emoji: '🌅',
        current: earlyBirdLogs,
        target: 5,
        xpReward: 60,
      ),
      AchievementProgress(
        id: 'perfect_four',
        emoji: '⭐',
        current: perfectBristolLogs,
        target: 5,
        xpReward: 75,
      ),
      AchievementProgress(
        id: 'false_alarm_pro',
        emoji: '💨',
        current: falseAlarms,
        target: 5,
        xpReward: 50,
      ),
      AchievementProgress(
        id: 'paid_to_poop',
        emoji: '💼',
        current: workLogs,
        target: 5,
        xpReward: 70,
      ),
      AchievementProgress(
        id: 'paid_throne_pro',
        emoji: '🤑',
        current: workMinutes,
        target: 60,
        xpReward: 110,
      ),
      AchievementProgress(
        id: 'coffee_effect',
        emoji: '☕',
        current: coffeeLogs,
        target: 5,
        xpReward: 60,
      ),
      AchievementProgress(
        id: 'marathoner',
        emoji: '⏱️',
        current: marathonLogs,
        target: 1,
        xpReward: 50,
      ),
      AchievementProgress(
        id: 'epic_drop',
        emoji: '🌋',
        current: epicSizeLogs,
        target: 3,
        xpReward: 75,
      ),
      AchievementProgress(
        id: 'detail_scientist',
        emoji: '🔬',
        current: detailedLogs,
        target: 15,
        xpReward: 90,
      ),
      AchievementProgress(
        id: 'spicy_survivor',
        emoji: '🌶️',
        current: spicyLogs,
        target: 5,
        xpReward: 70,
      ),
      AchievementProgress(
        id: 'century_club',
        emoji: '💯',
        current: totalLogs,
        target: 100,
        xpReward: 250,
      ),
      AchievementProgress(
        id: 'poop_veteran',
        emoji: '🏅',
        current: poopLogs,
        target: 50,
        xpReward: 180,
      ),
    ];

    final logXp = totalLogs * 10 + detailedLogs * 5;
    final badgeXp = achievements
        .where((a) => a.isUnlocked)
        .fold<int>(0, (sum, a) => sum + a.xpReward);
    final totalXp = logXp + badgeXp;

    UserRank currentRank = ranks.first;
    UserRank? nextRank;
    for (int i = 0; i < ranks.length; i++) {
      if (totalXp >= ranks[i].minXp) {
        currentRank = ranks[i];
        nextRank = (i + 1 < ranks.length) ? ranks[i + 1] : null;
      }
    }

    final double rankProgress;
    if (nextRank == null) {
      rankProgress = 1.0;
    } else {
      final span = nextRank.minXp - currentRank.minXp;
      rankProgress = span <= 0
          ? 1.0
          : ((totalXp - currentRank.minXp) / span).clamp(0.0, 1.0);
    }

    return GamificationSnapshot(
      totalXp: totalXp,
      currentRank: currentRank,
      nextRank: nextRank,
      rankProgress: rankProgress,
      achievements: achievements,
    );
  }

  static int _computeLongestStreak(Iterable<DateTime> activeDays) {
    final sorted = activeDays.toList()..sort();
    if (sorted.isEmpty) return 0;
    int longest = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (diff > 1) {
        current = 1;
      }
    }
    return longest;
  }
}
