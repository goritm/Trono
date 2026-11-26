import 'dart:math' as math;

import 'social_models.dart';
import 'social_plus.dart';

enum GroupChallengeType {
  teamVolume,
  awaySquad,
  syncedDuo,
}

class GroupChallenge {
  const GroupChallenge({
    required this.type,
    required this.current,
    required this.target,
  });

  final GroupChallengeType type;
  final int current;
  final int target;

  bool get isCompleted => current >= target;

  double get progress =>
      target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
}

class GroupChallengesSnapshot {
  const GroupChallengesSnapshot({
    this.groupStreakDays = 0,
    this.challenges = const [],
    this.activeDaysThisWeek = 0,
  });

  final int groupStreakDays;
  final List<GroupChallenge> challenges;
  final int activeDaysThisWeek;

  int get completedCount => challenges.where((c) => c.isCompleted).length;
  int get totalCount => challenges.length;
  bool get allCompleted =>
      challenges.isNotEmpty && completedCount == totalCount;
}

class GroupChallengesEngine {
  static GroupChallengesSnapshot compute({
    required List<SharedFeedItem> feed,
    required List<LeaderboardEntry> weeklyLeaderboard,
    required int memberCount,
    DateTime? now,
  }) {
    final ref = (now ?? DateTime.now()).toLocal();
    final today = DateTime(ref.year, ref.month, ref.day);
    final effectiveMembers =
        memberCount > 0 ? memberCount : weeklyLeaderboard.length;

    final poopFeed = feed.where((item) => item.type.includesPoop).toList();

    // Collect distinct local calendar dates with >= 1 shared throne.
    final activeDayKeys = <DateTime>{};
    for (final item in poopFeed) {
      final local = item.timestamp.toLocal();
      activeDayKeys.add(DateTime(local.year, local.month, local.day));
    }

    // Group Streak: consecutive local calendar days ending at today (or yesterday).
    int groupStreakDays = 0;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    DateTime? cursor;
    if (activeDayKeys.contains(today)) {
      cursor = today;
    } else if (activeDayKeys.contains(yesterday)) {
      cursor = yesterday;
    }
    while (cursor != null && activeDayKeys.contains(cursor)) {
      groupStreakDays++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    // Active days in the rolling 7 calendar-day window [today - 6 .. today].
    int activeDaysThisWeek = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      if (activeDayKeys.contains(day)) {
        activeDaysThisWeek++;
      }
    }

    // Last 7 days window aligned with weeklyLeaderboard (get_group_leaderboard p_days=7).
    final cutoff = ref.subtract(const Duration(days: 7));
    final weekPoopFeed = poopFeed
        .where((item) => !item.timestamp.toLocal().isBefore(cutoff))
        .toList();

    final hasLeaderboard = weeklyLeaderboard.isNotEmpty;

    final int teamVolumeCurrent = hasLeaderboard
        ? weeklyLeaderboard.fold<int>(0, (sum, entry) => sum + entry.poopCount)
        : weekPoopFeed.length;
    final int teamVolumeTarget = math.max(7, effectiveMembers * 7);

    final int awaySquadCurrent = hasLeaderboard
        ? weeklyLeaderboard.fold<int>(0, (sum, entry) => sum + entry.awayCount)
        : weekPoopFeed
            .where((item) => item.locationKind?.isAwayFromHome == true)
            .length;
    final int awaySquadTarget = math.max(3, effectiveMembers * 2);

    final int syncedDuoCurrent =
        SocialPlusEngine.findSyncedDuos(weekPoopFeed).length;

    final challenges = <GroupChallenge>[
      GroupChallenge(
        type: GroupChallengeType.teamVolume,
        current: teamVolumeCurrent,
        target: teamVolumeTarget,
      ),
      GroupChallenge(
        type: GroupChallengeType.awaySquad,
        current: awaySquadCurrent,
        target: awaySquadTarget,
      ),
      GroupChallenge(
        type: GroupChallengeType.syncedDuo,
        current: syncedDuoCurrent,
        target: 1,
      ),
    ];

    return GroupChallengesSnapshot(
      groupStreakDays: groupStreakDays,
      challenges: challenges,
      activeDaysThisWeek: activeDaysThisWeek,
    );
  }
}
