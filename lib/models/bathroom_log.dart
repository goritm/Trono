import 'package:material_ui/material_ui.dart';

enum BathroomType {
  poop,
  falseAlarm;

  String get dbValue => switch (this) {
    BathroomType.poop => 'poop',
    BathroomType.falseAlarm => 'false_alarm',
  };

  bool get includesPoop => this == BathroomType.poop;

  String get emoji => switch (this) {
    BathroomType.poop => '💩',
    BathroomType.falseAlarm => '💨',
  };

  Color accentColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (this) {
      BathroomType.poop => isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
      BathroomType.falseAlarm => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    };
  }

  static BathroomType fromDb(String? value) {
    return switch (value) {
      'false_alarm' => BathroomType.falseAlarm,
      _ => BathroomType.poop,
    };
  }
}

enum PoopSize {
  small,
  normal,
  epic;

  String get dbValue => name;

  String get emoji => switch (this) {
    PoopSize.small => '🔹',
    PoopSize.normal => '⚖️',
    PoopSize.epic => '🌋',
  };

  static PoopSize? fromDb(String? value) {
    if (value == null) return null;
    for (final item in PoopSize.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

enum EffortLevel {
  effortless,
  normal,
  struggled,
  urgent;

  String get dbValue => name;

  String get emoji => switch (this) {
    EffortLevel.effortless => '😌',
    EffortLevel.normal => '🙂',
    EffortLevel.struggled => '😤',
    EffortLevel.urgent => '🚨',
  };

  static EffortLevel? fromDb(String? value) {
    if (value == null) return null;
    for (final item in EffortLevel.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

enum StoolColor {
  brown,
  lightBrown,
  darkBrown,
  green,
  yellow,
  reddish;

  String get dbValue => name;

  Color get swatch => switch (this) {
    StoolColor.brown => const Color(0xFF7C4D2B),
    StoolColor.lightBrown => const Color(0xFFC28E5C),
    StoolColor.darkBrown => const Color(0xFF3E2723),
    StoolColor.green => const Color(0xFF4D7C0F),
    StoolColor.yellow => const Color(0xFFCA8A04),
    StoolColor.reddish => const Color(0xFFB91C1C),
  };

  static StoolColor? fromDb(String? value) {
    if (value == null) return null;
    for (final item in StoolColor.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

/// V2 Multiplayer readiness: privacy level per log entry.
enum ShareLevel {
  private,
  summaryOnly,
  full;

  String get dbValue => switch (this) {
    ShareLevel.private => 'private',
    ShareLevel.summaryOnly => 'summary_only',
    ShareLevel.full => 'full',
  };

  static ShareLevel fromDb(String? value) {
    return switch (value) {
      'private' => ShareLevel.private,
      'summary_only' => ShareLevel.summaryOnly,
      'full' => ShareLevel.full,
      _ => ShareLevel.summaryOnly,
    };
  }
}

enum SyncStatus {
  localOnly,
  pendingSync,
  synced;

  String get dbValue => switch (this) {
    SyncStatus.localOnly => 'local_only',
    SyncStatus.pendingSync => 'pending_sync',
    SyncStatus.synced => 'synced',
  };

  static SyncStatus fromDb(String? value) {
    return switch (value) {
      'pending_sync' => SyncStatus.pendingSync,
      'synced' => SyncStatus.synced,
      _ => SyncStatus.localOnly,
    };
  }
}

const List<String> kDefaultQuickTags = [
  'coffee',
  'spicy',
  'home',
  'work',
  'travel',
  'dairy',
  'morning',
  'late_night',
];

class BathroomLog {
  const BathroomLog({
    required this.id,
    required this.type,
    required this.timestamp,
    this.bristolType,
    this.size,
    this.effort,
    this.durationSeconds,
    this.color,
    this.tags = const [],
    this.note,
    this.shareLevel = ShareLevel.summaryOnly,
    this.syncStatus = SyncStatus.localOnly,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final BathroomType type;
  final DateTime timestamp;
  final int? bristolType; // 1..7
  final PoopSize? size;
  final EffortLevel? effort;
  final int? durationSeconds;
  final StoolColor? color;
  final List<String> tags;
  final String? note;

  // V2 sync & multiplayer metadata
  final ShareLevel shareLevel;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get hasDetails =>
      bristolType != null ||
      size != null ||
      effort != null ||
      durationSeconds != null ||
      color != null ||
      tags.isNotEmpty ||
      (note != null && note!.trim().isNotEmpty);

  BathroomLog copyWith({
    String? id,
    BathroomType? type,
    DateTime? timestamp,
    int? bristolType,
    bool clearBristol = false,
    PoopSize? size,
    bool clearSize = false,
    EffortLevel? effort,
    bool clearEffort = false,
    int? durationSeconds,
    bool clearDuration = false,
    StoolColor? color,
    bool clearColor = false,
    List<String>? tags,
    String? note,
    bool clearNote = false,
    ShareLevel? shareLevel,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return BathroomLog(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      bristolType: clearBristol ? null : (bristolType ?? this.bristolType),
      size: clearSize ? null : (size ?? this.size),
      effort: clearEffort ? null : (effort ?? this.effort),
      durationSeconds:
          clearDuration ? null : (durationSeconds ?? this.durationSeconds),
      color: clearColor ? null : (color ?? this.color),
      tags: tags ?? this.tags,
      note: clearNote ? null : (note ?? this.note),
      shareLevel: shareLevel ?? this.shareLevel,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'type': type.dbValue,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'bristol_type': bristolType,
      'size': size?.dbValue,
      'effort': effort?.dbValue,
      'duration_seconds': durationSeconds,
      'color': color?.dbValue,
      'tags': tags.join(','),
      'note': note,
      'share_level': shareLevel.dbValue,
      'sync_status': syncStatus.dbValue,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory BathroomLog.fromDbMap(Map<String, Object?> map) {
    final rawTags = (map['tags'] as String?) ?? '';
    final parsedTags = rawTags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return BathroomLog(
      id: map['id'] as String,
      type: BathroomType.fromDb(map['type'] as String?),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      bristolType: map['bristol_type'] as int?,
      size: PoopSize.fromDb(map['size'] as String?),
      effort: EffortLevel.fromDb(map['effort'] as String?),
      durationSeconds: map['duration_seconds'] as int?,
      color: StoolColor.fromDb(map['color'] as String?),
      tags: parsedTags,
      note: map['note'] as String?,
      shareLevel: ShareLevel.fromDb(map['share_level'] as String?),
      syncStatus: SyncStatus.fromDb(map['sync_status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.dbValue,
      'timestamp': timestamp.toIso8601String(),
      'bristolType': bristolType,
      'size': size?.dbValue,
      'effort': effort?.dbValue,
      'durationSeconds': durationSeconds,
      'color': color?.dbValue,
      'tags': tags,
      'note': note,
      'shareLevel': shareLevel.dbValue,
      'syncStatus': syncStatus.dbValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory BathroomLog.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final ts = DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? now;
    return BathroomLog(
      id: json['id']?.toString() ?? '',
      type: BathroomType.fromDb(json['type']?.toString()),
      timestamp: ts,
      bristolType: json['bristolType'] is int
          ? json['bristolType'] as int
          : int.tryParse(json['bristolType']?.toString() ?? ''),
      size: PoopSize.fromDb(json['size']?.toString()),
      effort: EffortLevel.fromDb(json['effort']?.toString()),
      durationSeconds: json['durationSeconds'] is int
          ? json['durationSeconds'] as int
          : int.tryParse(json['durationSeconds']?.toString() ?? ''),
      color: StoolColor.fromDb(json['color']?.toString()),
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      note: json['note']?.toString(),
      shareLevel: ShareLevel.fromDb(json['shareLevel']?.toString()),
      syncStatus: SyncStatus.fromDb(json['syncStatus']?.toString()),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? ts,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? ts,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'].toString())
          : null,
    );
  }
}
