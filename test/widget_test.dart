import 'package:trono/models/achievement.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/stats_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatsCalculator', () {
    test('computes daily averages, streaks, peak hour, and records', () {
      final now = DateTime(2026, 11, 26, 15, 0);
      final logs = [
        BathroomLog(
          id: '1',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 26, 9, 15),
          bristolType: 4,
          durationSeconds: 420,
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: '2',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 26, 9, 50),
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: '3',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 25, 21, 0),
          durationSeconds: 960,
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: '4',
          type: BathroomType.falseAlarm,
          timestamp: DateTime(2026, 11, 24, 9, 5),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final stats = StatsCalculator.calculate(logs, now: now);

      expect(stats.todayTotal, 2);
      expect(stats.todayPoop, 2);
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
      expect(stats.peakHour, 9);
      expect(stats.recordDayCount, 2);
      expect(stats.longestSessionSeconds, 960);
      expect(stats.weeklyAvg.daysSpan, 3);
      expect(stats.weeklyAvg.avgTotalPerDay, closeTo(4 / 3, 0.01));
      expect(stats.weeklyAvg.avgPoopPerDay, closeTo(3 / 3, 0.01));
    });
  });

  group('GamificationEngine', () {
    test('unlocks achievements and computes XP & rank', () {
      final now = DateTime(2026, 11, 26, 2, 30);
      final logs = List.generate(
        3,
        (i) => BathroomLog(
          id: 'id-$i',
          type: BathroomType.poop,
          timestamp: now.add(Duration(minutes: i * 10)),
          bristolType: 4,
          durationSeconds: 1000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final snap = GamificationEngine.evaluate(logs);
      final unlockedIds = snap.achievements
          .where((a) => a.isUnlocked)
          .map((a) => a.id)
          .toSet();

      expect(
        unlockedIds,
        containsAll(['first_visit', 'hat_trick', 'night_owl', 'marathoner']),
      );
      expect(snap.totalXp, greaterThanOrEqualTo(100));
      expect(snap.currentRank.level, greaterThanOrEqualTo(2));
    });
  });

  group('BathroomLog serialization', () {
    test('round-trips JSON and SQLite maps cleanly', () {
      final ts = DateTime(2026, 11, 26, 14, 20);
      final original = BathroomLog(
        id: 'uuid-123',
        type: BathroomType.poop,
        timestamp: ts,
        bristolType: 4,
        size: PoopSize.epic,
        effort: EffortLevel.effortless,
        durationSeconds: 300,
        color: StoolColor.brown,
        tags: const ['coffee', 'work'],
        note: 'Post espresso',
        shareLevel: ShareLevel.private,
        createdAt: ts,
        updatedAt: ts,
      );

      final fromDb = BathroomLog.fromDbMap(original.toDbMap());
      expect(fromDb.id, original.id);
      expect(fromDb.type, original.type);
      expect(fromDb.bristolType, 4);
      expect(fromDb.size, PoopSize.epic);
      expect(fromDb.tags, ['coffee', 'work']);
      expect(fromDb.shareLevel, ShareLevel.private);

      final fromJson = BathroomLog.fromJson(original.toJson());
      expect(fromJson.id, original.id);
      expect(fromJson.note, 'Post espresso');
      expect(fromJson.color, StoolColor.brown);
    });
  });
}
