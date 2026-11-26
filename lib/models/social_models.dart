import 'bathroom_log.dart';

const List<String> kReactionEmojis = ['👑', '🔥', '💀', '👏'];

const List<String> kAvatarEmojis = [
  '👑',
  '💩',
  '🔥',
  '🦄',
  '🐻',
  '🦊',
  '🐸',
  '⚡',
  '🌶️',
  '🚀',
  '😎',
  '👸',
];

const List<String> kGroupEmojis = [
  '👑',
  '🚽',
  '🔥',
  '🏠',
  '❤️',
  '🍻',
  '💼',
  '🌍',
];

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarEmoji,
    required this.totalXp,
    required this.rankLevel,
    required this.currentStreak,
  });

  final String id;
  final String displayName;
  final String avatarEmoji;
  final int totalXp;
  final int rankLevel;
  final int currentStreak;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      displayName: (map['display_name'] as String?)?.trim().isNotEmpty == true
          ? map['display_name'] as String
          : 'Trono',
      avatarEmoji: (map['avatar_emoji'] as String?)?.trim().isNotEmpty == true
          ? map['avatar_emoji'] as String
          : '👑',
      totalXp: (map['total_xp'] as num?)?.toInt() ?? 0,
      rankLevel: (map['rank_level'] as num?)?.toInt() ?? 1,
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarEmoji,
    int? totalXp,
    int? rankLevel,
    int? currentStreak,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      totalXp: totalXp ?? this.totalXp,
      rankLevel: rankLevel ?? this.rankLevel,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.role,
    required this.totalXp,
    required this.rankLevel,
    required this.currentStreak,
  });

  final String userId;
  final String displayName;
  final String avatarEmoji;
  final String role;
  final int totalXp;
  final int rankLevel;
  final int currentStreak;

  bool get isOwner => role == 'owner';
}

class SocialGroup {
  const SocialGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.members = const [],
  });

  final String id;
  final String name;
  final String emoji;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final List<GroupMember> members;

  int get memberCount => members.length;

  factory SocialGroup.fromMap(
    Map<String, dynamic> map, {
    List<GroupMember> members = const [],
  }) {
    return SocialGroup(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '👑',
      inviteCode: map['invite_code']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      members: members,
    );
  }

  SocialGroup copyWith({List<GroupMember>? members}) {
    return SocialGroup(
      id: id,
      name: name,
      emoji: emoji,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
      members: members ?? this.members,
    );
  }
}

class LogReaction {
  const LogReaction({
    required this.id,
    required this.logId,
    required this.userId,
    required this.emoji,
  });

  final String id;
  final String logId;
  final String userId;
  final String emoji;

  factory LogReaction.fromMap(Map<String, dynamic> map) {
    return LogReaction(
      id: map['id']?.toString() ?? '',
      logId: map['log_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '👑',
    );
  }
}

class SharedFeedItem {
  const SharedFeedItem({
    required this.logId,
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.rankLevel,
    required this.type,
    required this.timestamp,
    required this.shareLevel,
    this.locationKind,
    this.bristolType,
    this.size,
    this.effort,
    this.durationSeconds,
    this.color,
    this.tags = const [],
    this.note,
    this.placeLabel,
    this.reactions = const [],
  });

  final String logId;
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final int rankLevel;
  final BathroomType type;
  final DateTime timestamp;
  final ShareLevel shareLevel;
  final LocationKind? locationKind;
  final int? bristolType;
  final PoopSize? size;
  final EffortLevel? effort;
  final int? durationSeconds;
  final StoolColor? color;
  final List<String> tags;
  final String? note;
  final String? placeLabel;
  final List<LogReaction> reactions;

  int countForEmoji(String emoji) =>
      reactions.where((r) => r.emoji == emoji).length;

  bool hasReacted(String emoji, String? currentUserId) {
    if (currentUserId == null) return false;
    return reactions.any(
      (r) => r.emoji == emoji && r.userId == currentUserId,
    );
  }

  SharedFeedItem copyWith({List<LogReaction>? reactions}) {
    return SharedFeedItem(
      logId: logId,
      userId: userId,
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      rankLevel: rankLevel,
      type: type,
      timestamp: timestamp,
      shareLevel: shareLevel,
      locationKind: locationKind,
      bristolType: bristolType,
      size: size,
      effort: effort,
      durationSeconds: durationSeconds,
      color: color,
      tags: tags,
      note: note,
      placeLabel: placeLabel,
      reactions: reactions ?? this.reactions,
    );
  }

  factory SharedFeedItem.fromMap(
    Map<String, dynamic> map, {
    required UserProfile author,
    List<LogReaction> reactions = const [],
  }) {
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final shareLevel = ShareLevel.fromDb(map['share_level']?.toString());
    final isFull = shareLevel == ShareLevel.full;

    return SharedFeedItem(
      logId: map['log_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? author.id,
      displayName: author.displayName,
      avatarEmoji: author.avatarEmoji,
      rankLevel: author.rankLevel,
      type: BathroomType.fromDb(map['type']?.toString()),
      timestamp:
          (DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
                  DateTime.now())
              .toLocal(),
      shareLevel: shareLevel,
      locationKind: LocationKind.fromDb(map['location_kind']?.toString()),
      bristolType: isFull ? (map['bristol_type'] as num?)?.toInt() : null,
      size: isFull ? PoopSize.fromDb(map['size']?.toString()) : null,
      effort: isFull ? EffortLevel.fromDb(map['effort']?.toString()) : null,
      durationSeconds:
          isFull ? (map['duration_seconds'] as num?)?.toInt() : null,
      color: isFull ? StoolColor.fromDb(map['color']?.toString()) : null,
      tags: isFull ? tags : const [],
      note: isFull ? map['note']?.toString() : null,
      placeLabel: isFull ? map['place_label']?.toString() : null,
      reactions: reactions,
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.totalXp,
    required this.rankLevel,
    required this.currentStreak,
    required this.poopCount,
    required this.awayCount,
    required this.workCount,
    required this.totalDurationSeconds,
  });

  final String userId;
  final String displayName;
  final String avatarEmoji;
  final int totalXp;
  final int rankLevel;
  final int currentStreak;
  final int poopCount;
  final int awayCount;
  final int workCount;
  final int totalDurationSeconds;

  int get awayPercent =>
      poopCount == 0 ? 0 : ((awayCount * 100) / poopCount).round();

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['user_id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Trono',
      avatarEmoji: map['avatar_emoji']?.toString() ?? '👑',
      totalXp: (map['total_xp'] as num?)?.toInt() ?? 0,
      rankLevel: (map['rank_level'] as num?)?.toInt() ?? 1,
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      poopCount: (map['poop_count'] as num?)?.toInt() ?? 0,
      awayCount: (map['away_count'] as num?)?.toInt() ?? 0,
      workCount: (map['work_count'] as num?)?.toInt() ?? 0,
      totalDurationSeconds:
          (map['total_duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Pure, testable mapper between local SQLite [BathroomLog] and Supabase
/// `public.bathroom_logs`.
///
/// PRIVACY GUARANTEE: Exact GPS coordinates (`latitude`, `longitude`) are
/// NEVER included in the cloud payload, and are preserved locally when
/// merging remote records back onto the device.
class CloudLogMapper {
  static Map<String, dynamic> toSupabaseRow(
    BathroomLog log, {
    required String userId,
  }) {
    return {
      'id': log.id,
      'user_id': userId,
      'type': log.type.dbValue,
      'timestamp': log.timestamp.toUtc().toIso8601String(),
      'bristol_type': log.bristolType,
      'size': log.size?.dbValue,
      'effort': log.effort?.dbValue,
      'duration_seconds': log.durationSeconds,
      'color': log.color?.dbValue,
      'tags': log.tags,
      'note': log.note,
      'location_kind': log.locationKind?.dbValue,
      'place_label': log.placeLabel,
      'share_level': log.shareLevel.dbValue,
      'created_at': log.createdAt.toUtc().toIso8601String(),
      'updated_at': log.updatedAt.toUtc().toIso8601String(),
      'deleted_at': log.deletedAt?.toUtc().toIso8601String(),
    };
  }

  static BathroomLog fromSupabaseRow(
    Map<String, dynamic> row, {
    BathroomLog? existingLocal,
  }) {
    final rawTags = row['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final now = DateTime.now();
    final ts =
        (DateTime.tryParse(row['timestamp']?.toString() ?? '') ?? now)
            .toLocal();

    return BathroomLog(
      id: row['id'].toString(),
      type: BathroomType.fromDb(row['type']?.toString()),
      timestamp: ts,
      bristolType: (row['bristol_type'] as num?)?.toInt(),
      size: PoopSize.fromDb(row['size']?.toString()),
      effort: EffortLevel.fromDb(row['effort']?.toString()),
      durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
      color: StoolColor.fromDb(row['color']?.toString()),
      tags: tags,
      note: row['note']?.toString(),
      locationKind: LocationKind.fromDb(row['location_kind']?.toString()),
      // Always preserve local-only GPS coordinates if this log exists on device
      latitude: existingLocal?.latitude,
      longitude: existingLocal?.longitude,
      placeLabel: row['place_label']?.toString(),
      shareLevel: ShareLevel.fromDb(row['share_level']?.toString()),
      syncStatus: SyncStatus.synced,
      createdAt:
          (DateTime.tryParse(row['created_at']?.toString() ?? '') ?? ts)
              .toLocal(),
      updatedAt:
          (DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? ts)
              .toLocal(),
      deletedAt: row['deleted_at'] != null
          ? DateTime.tryParse(row['deleted_at'].toString())?.toLocal()
          : null,
    );
  }

  /// Determines which remote logs should overwrite or be inserted locally
  /// (last-write-wins by `updatedAt`), preserving local GPS coordinates.
  static List<BathroomLog> computeRemoteMerges({
    required List<Map<String, dynamic>> remoteRows,
    required Map<String, BathroomLog> localById,
  }) {
    final toUpsert = <BathroomLog>[];
    for (final row in remoteRows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final existing = localById[id];
      final mapped = fromSupabaseRow(row, existingLocal: existing);

      if (existing == null) {
        toUpsert.add(mapped);
      } else if (mapped.updatedAt.isAfter(existing.updatedAt)) {
        toUpsert.add(mapped);
      }
    }
    return toUpsert;
  }
}
