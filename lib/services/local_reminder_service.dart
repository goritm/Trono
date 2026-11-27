import 'package:flutter/services.dart';

import '../models/reminder_schedule.dart';

/// 100% local Android AlarmManager + NotificationManager bridge.
/// Uses zero third-party notification plugins and safely no-ops on platforms
/// without the native channel.
class LocalReminderService {
  LocalReminderService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.trono.trono/reminders',
  );

  static const int streakReminderId = 1001;
  static const int weeklyRecapReminderId = 1002;

  final MethodChannel _channel;

  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> scheduleReminder(ScheduledReminder reminder) async {
    try {
      final scheduled = await _channel.invokeMethod<bool>(
        'scheduleReminder',
        reminder.toPlatformMap(),
      );
      return scheduled ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _channel.invokeMethod<void>('cancelReminder', {'id': id});
    } on MissingPluginException {
      // Safe no-op on non-Android platforms or widget tests without mock channel.
    } on PlatformException {
      // Safe no-op if platform cannot cancel.
    }
  }

  Future<void> syncReminders({
    required ReminderConfig config,
    required bool loggedToday,
    required int currentStreak,
    required String streakTitle,
    required String streakBody,
    required String weeklyTitle,
    required String weeklyBody,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();

    if (config.streakEnabled) {
      final triggerAt = ReminderScheduleCalculator.nextStreakReminder(
        now: current,
        hour: config.streakHour,
        loggedToday: loggedToday,
        currentStreak: currentStreak,
      );
      await scheduleReminder(
        ScheduledReminder(
          id: streakReminderId,
          triggerAt: triggerAt,
          title: streakTitle,
          body: streakBody,
        ),
      );
    } else {
      await cancelReminder(streakReminderId);
    }

    if (config.weeklyEnabled) {
      final triggerAt = ReminderScheduleCalculator.nextWeeklyRecap(
        now: current,
      );
      await scheduleReminder(
        ScheduledReminder(
          id: weeklyRecapReminderId,
          triggerAt: triggerAt,
          title: weeklyTitle,
          body: weeklyBody,
        ),
      );
    } else {
      await cancelReminder(weeklyRecapReminderId);
    }
  }
}
