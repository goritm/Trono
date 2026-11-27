class ReminderConfig {
  const ReminderConfig({
    this.streakEnabled = false,
    this.streakHour = defaultStreakHour,
    this.weeklyEnabled = false,
  });

  static const int defaultStreakHour = 20;
  static const List<int> selectableStreakHours = [19, 20, 21, 22];
  static const int defaultWeeklyWeekday = DateTime.sunday;
  static const int defaultWeeklyHour = 19;

  final bool streakEnabled;
  final int streakHour;
  final bool weeklyEnabled;

  ReminderConfig copyWith({
    bool? streakEnabled,
    int? streakHour,
    bool? weeklyEnabled,
  }) {
    return ReminderConfig(
      streakEnabled: streakEnabled ?? this.streakEnabled,
      streakHour: streakHour ?? this.streakHour,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderConfig &&
        other.streakEnabled == streakEnabled &&
        other.streakHour == streakHour &&
        other.weeklyEnabled == weeklyEnabled;
  }

  @override
  int get hashCode => Object.hash(streakEnabled, streakHour, weeklyEnabled);
}

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.triggerAt,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime triggerAt;
  final String title;
  final String body;

  Map<String, Object> toPlatformMap() => {
    'id': id,
    'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
    'title': title,
    'body': body,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledReminder &&
        other.id == id &&
        other.triggerAt == triggerAt &&
        other.title == title &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(id, triggerAt, title, body);
}

class ReminderScheduleCalculator {
  /// Returns the next Streak Guard fire time:
  /// - Today at [hour]:00 if the user has NOT logged today and [now] is before
  ///   today at [hour]:00.
  /// - Tomorrow at [hour]:00 if the user already logged today (smart
  ///   suppression) OR today's reminder hour has already passed.
  static DateTime nextStreakReminder({
    required DateTime now,
    required int hour,
    required bool loggedToday,
    required int currentStreak,
  }) {
    final safeHour = hour.clamp(0, 23);
    final todayTarget = DateTime(now.year, now.month, now.day, safeHour);
    if (!loggedToday && now.isBefore(todayTarget)) {
      return todayTarget;
    }
    return DateTime(now.year, now.month, now.day + 1, safeHour);
  }

  /// Returns the next occurrence of [weekday] (default Sunday) at [hour]:00
  /// strictly after [now].
  static DateTime nextWeeklyRecap({
    required DateTime now,
    int weekday = ReminderConfig.defaultWeeklyWeekday,
    int hour = ReminderConfig.defaultWeeklyHour,
  }) {
    final safeHour = hour.clamp(0, 23);
    final normalizedWeekday = weekday.clamp(DateTime.monday, DateTime.sunday);
    final daysUntil = (normalizedWeekday - now.weekday + 7) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysUntil,
      safeHour,
    );
    if (!candidate.isAfter(now)) {
      candidate = DateTime(
        now.year,
        now.month,
        now.day + daysUntil + 7,
        safeHour,
      );
    }
    return candidate;
  }
}
