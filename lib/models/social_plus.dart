import 'bathroom_log.dart';
import 'social_models.dart';

/// Represents a "Dúo Sincronizado": two distinct group members who logged
/// a poop within [SocialPlusEngine.kSyncedDuoWindow] of each other.
class SyncedDuoPair {
  const SyncedDuoPair({
    required this.logIdA,
    required this.logIdB,
    required this.userIdA,
    required this.userIdB,
    required this.userAName,
    required this.userAEmoji,
    required this.userBName,
    required this.userBEmoji,
    required this.gapMinutes,
    required this.timestamp,
  });

  final String logIdA;
  final String logIdB;
  final String userIdA;
  final String userIdB;
  final String userAName;
  final String userAEmoji;
  final String userBName;
  final String userBEmoji;
  final int gapMinutes;
  final DateTime timestamp;

  String partnerNameFor(String logId) =>
      logId == logIdA ? userBName : userAName;

  String partnerEmojiFor(String logId) =>
      logId == logIdA ? userBEmoji : userAEmoji;

  bool involvesUser(String userId) => userIdA == userId || userIdB == userId;
}

class SocialBadgeProgress {
  const SocialBadgeProgress({
    required this.id,
    required this.emoji,
    required this.current,
    required this.target,
  });

  final String id;
  final String emoji;
  final int current;
  final int target;

  bool get isUnlocked => current >= target;
  double get progress =>
      target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
}

class SocialPlusSnapshot {
  const SocialPlusSnapshot({
    this.duos = const [],
    this.duoByLogId = const {},
    this.badges = const [],
  });

  final List<SyncedDuoPair> duos;
  final Map<String, SyncedDuoPair> duoByLogId;
  final List<SocialBadgeProgress> badges;

  int get unlockedCount => badges.where((b) => b.isUnlocked).length;
}

class GroupWrappedSnapshot {
  const GroupWrappedSnapshot({
    required this.groupName,
    required this.groupEmoji,
    required this.inviteCode,
    required this.memberCount,
    required this.totalPoops,
    required this.totalAwayPoops,
    required this.awayPercent,
    required this.syncedDuosCount,
    required this.totalReactions,
    this.topReactionEmoji,
    this.weeklyKing,
    this.awayMvp,
    this.top3 = const [],
  });

  final String groupName;
  final String groupEmoji;
  final String inviteCode;
  final int memberCount;
  final int totalPoops;
  final int totalAwayPoops;
  final int awayPercent;
  final int syncedDuosCount;
  final int totalReactions;
  final String? topReactionEmoji;
  final LeaderboardEntry? weeklyKing;
  final LeaderboardEntry? awayMvp;
  final List<LeaderboardEntry> top3;
}

class SocialPlusEngine {
  static const Duration kSyncedDuoWindow = Duration(minutes: 15);

  /// Finds all Synced Duo pairs (different members logging a poop within 15m).
  /// Each log participates in at most one (closest-in-time) pair.
  static List<SyncedDuoPair> findSyncedDuos(
    List<SharedFeedItem> feed, {
    Duration window = kSyncedDuoWindow,
  }) {
    final poops = feed.where((f) => f.type == BathroomType.poop).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final usedLogIds = <String>{};
    final pairs = <SyncedDuoPair>[];

    for (int i = 0; i < poops.length; i++) {
      final a = poops[i];
      if (usedLogIds.contains(a.logId)) continue;

      SharedFeedItem? bestPartner;
      Duration? bestGap;

      for (int j = i + 1; j < poops.length; j++) {
        final b = poops[j];
        if (usedLogIds.contains(b.logId)) continue;
        final gap = a.timestamp.difference(b.timestamp).abs();
        if (gap > window) break; // sorted descending, no closer matches ahead
        if (b.userId == a.userId) continue;

        if (bestGap == null || gap < bestGap) {
          bestGap = gap;
          bestPartner = b;
        }
      }

      if (bestPartner != null && bestGap != null) {
        usedLogIds.add(a.logId);
        usedLogIds.add(bestPartner.logId);
        pairs.add(
          SyncedDuoPair(
            logIdA: a.logId,
            logIdB: bestPartner.logId,
            userIdA: a.userId,
            userIdB: bestPartner.userId,
            userAName: a.displayName,
            userAEmoji: a.avatarEmoji,
            userBName: bestPartner.displayName,
            userBEmoji: bestPartner.avatarEmoji,
            gapMinutes: bestGap.inMinutes,
            timestamp: a.timestamp,
          ),
        );
      }
    }

    return pairs;
  }

  static SocialPlusSnapshot evaluate({
    required String? currentUserId,
    required List<SocialGroup> groups,
    required List<SharedFeedItem> feed,
    required List<LeaderboardEntry> weeklyLeaderboard,
  }) {
    final duos = findSyncedDuos(feed);
    final duoByLogId = <String, SyncedDuoPair>{};
    for (final pair in duos) {
      duoByLogId[pair.logIdA] = pair;
      duoByLogId[pair.logIdB] = pair;
    }

    final uid = currentUserId;
    final myDuoCount =
        uid == null ? 0 : duos.where((d) => d.involvesUser(uid)).length;

    final isWeeklyKing = uid != null &&
        weeklyLeaderboard.isNotEmpty &&
        weeklyLeaderboard.first.userId == uid &&
        weeklyLeaderboard.first.poopCount > 0;

    int reactionsGiven = 0;
    int reactionsReceived = 0;
    if (uid != null) {
      for (final item in feed) {
        for (final r in item.reactions) {
          if (r.userId == uid && item.userId != uid) {
            reactionsGiven++;
          }
          if (item.userId == uid && r.userId != uid) {
            reactionsReceived++;
          }
        }
      }
    }

    final awayLeader = _findAwayMvp(weeklyLeaderboard);
    final isAwayMvp = uid != null && awayLeader?.userId == uid;

    final badges = <SocialBadgeProgress>[
      SocialBadgeProgress(
        id: 'social_founder',
        emoji: '👥',
        current: groups.length,
        target: 1,
      ),
      SocialBadgeProgress(
        id: 'synced_duo',
        emoji: '⚡',
        current: myDuoCount,
        target: 1,
      ),
      SocialBadgeProgress(
        id: 'weekly_king',
        emoji: '👑',
        current: isWeeklyKing ? 1 : 0,
        target: 1,
      ),
      SocialBadgeProgress(
        id: 'hype_squad',
        emoji: '🔥',
        current: reactionsGiven,
        target: 5,
      ),
      SocialBadgeProgress(
        id: 'crowd_favorite',
        emoji: '🌟',
        current: reactionsReceived,
        target: 5,
      ),
      SocialBadgeProgress(
        id: 'away_mvp',
        emoji: '🌍',
        current: isAwayMvp ? 1 : 0,
        target: 1,
      ),
    ];

    return SocialPlusSnapshot(
      duos: duos,
      duoByLogId: duoByLogId,
      badges: badges,
    );
  }

  static GroupWrappedSnapshot buildGroupWeeklyWrapped({
    required SocialGroup group,
    required List<LeaderboardEntry> weeklyLeaderboard,
    required List<SharedFeedItem> feed,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final cutoff = ref.subtract(const Duration(days: 7));
    final weekFeed =
        feed.where((item) => !item.timestamp.isBefore(cutoff)).toList();

    int totalPoops = 0;
    int totalAway = 0;
    for (final row in weeklyLeaderboard) {
      totalPoops += row.poopCount;
      totalAway += row.awayCount;
    }
    final awayPct =
        totalPoops == 0 ? 0 : ((totalAway * 100) / totalPoops).round();

    final weekDuos = findSyncedDuos(weekFeed);

    int totalReactions = 0;
    final emojiCounts = <String, int>{};
    for (final item in weekFeed) {
      totalReactions += item.reactions.length;
      for (final r in item.reactions) {
        emojiCounts[r.emoji] = (emojiCounts[r.emoji] ?? 0) + 1;
      }
    }

    String? topEmoji;
    int topEmojiCount = 0;
    emojiCounts.forEach((emoji, count) {
      if (count > topEmojiCount) {
        topEmoji = emoji;
        topEmojiCount = count;
      }
    });

    final king = weeklyLeaderboard.isNotEmpty &&
            weeklyLeaderboard.first.poopCount > 0
        ? weeklyLeaderboard.first
        : null;
    final awayMvp = _findAwayMvp(weeklyLeaderboard);

    return GroupWrappedSnapshot(
      groupName: group.name,
      groupEmoji: group.emoji,
      inviteCode: group.inviteCode,
      memberCount: group.memberCount > 0
          ? group.memberCount
          : weeklyLeaderboard.length,
      totalPoops: totalPoops,
      totalAwayPoops: totalAway,
      awayPercent: awayPct,
      syncedDuosCount: weekDuos.length,
      totalReactions: totalReactions,
      topReactionEmoji: topEmoji,
      weeklyKing: king,
      awayMvp: awayMvp,
      top3: weeklyLeaderboard.take(3).toList(),
    );
  }

  static LeaderboardEntry? _findAwayMvp(List<LeaderboardEntry> entries) {
    LeaderboardEntry? best;
    for (final e in entries) {
      if (e.awayCount <= 0) continue;
      if (best == null ||
          e.awayCount > best.awayCount ||
          (e.awayCount == best.awayCount && e.awayPercent > best.awayPercent)) {
        best = e;
      }
    }
    return best;
  }
}
