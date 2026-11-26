import 'package:flutter_test/flutter_test.dart';
import 'package:trono/models/achievement.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/insights.dart';
import 'package:trono/models/stats_summary.dart';
import 'package:trono/services/location_service.dart';

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
          locationKind: LocationKind.home,
          latitude: 40.4168,
          longitude: -3.7038,
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: '2',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 26, 9, 50),
          locationKind: LocationKind.away,
          latitude: 40.4530,
          longitude: -3.6883,
          createdAt: now,
          updatedAt: now,
        ),
        BathroomLog(
          id: '3',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 25, 21, 0),
          durationSeconds: 960,
          // No explicit locationKind, but >50 km away from Home -> auto-classified away!
          latitude: 41.3874,
          longitude: 2.1686,
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

      final stats = StatsCalculator.calculate(
        logs,
        now: now,
        homeLat: 40.4168,
        homeLng: -3.7038,
      );

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

      // V1.5 Territory stats
      expect(stats.homePoopCount, 1);
      expect(stats.awayPoopCount, 2);
      expect(stats.homePercent, closeTo(33.33, 0.1));
      expect(stats.awayPercent, closeTo(66.67, 0.1));
      expect(stats.distinctSpotsCount, 3);
      expect(stats.maxDistanceFromHomeKm, greaterThan(500));
    });
  });

  group('GamificationEngine', () {
    test('unlocks achievements including V1.5 territory badges', () {
      final now = DateTime(2026, 11, 26, 2, 30);
      final logs = List.generate(
        5,
        (i) => BathroomLog(
          id: 'id-$i',
          type: BathroomType.poop,
          timestamp: now.add(Duration(minutes: i * 10)),
          bristolType: 4,
          durationSeconds: 1000,
          locationKind: LocationKind.away,
          // 5 distinct spots spaced well apart (~11 km each)
          latitude: 40.5 + i * 0.2,
          longitude: -3.7,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final snap = GamificationEngine.evaluate(
        logs,
        homeLat: 40.0,
        homeLng: -3.7,
      );
      final unlockedIds = snap.achievements
          .where((a) => a.isUnlocked)
          .map((a) => a.id)
          .toSet();

      expect(
        unlockedIds,
        containsAll([
          'first_visit',
          'hat_trick',
          'night_owl',
          'marathoner',
          'survival_fittest',
          'territory_conqueror',
          'international_drop',
        ]),
      );
      expect(snap.totalXp, greaterThanOrEqualTo(300));
      expect(snap.currentRank.level, greaterThanOrEqualTo(3));
    });
  });

  group('LocationService & BathroomLog serialization', () {
    test('clusters nearby spots and round-trips location fields', () {
      final ts = DateTime(2026, 11, 26, 14, 20);
      final a = BathroomLog(
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
        locationKind: LocationKind.away,
        latitude: 40.4200,
        longitude: -3.7000,
        placeLabel: 'Oficina',
        shareLevel: ShareLevel.private,
        createdAt: ts,
        updatedAt: ts,
      );
      final nearby = a.copyWith(id: 'uuid-124', latitude: 40.4202);
      final far = a.copyWith(id: 'uuid-125', latitude: 40.4500);

      expect(LocationService.countDistinctSpots([a, nearby, far]), 2);

      final fromDb = BathroomLog.fromDbMap(a.toDbMap());
      expect(fromDb.id, a.id);
      expect(fromDb.locationKind, LocationKind.away);
      expect(fromDb.latitude, closeTo(40.4200, 0.0001));
      expect(fromDb.placeLabel, 'Oficina');

      final fromJson = BathroomLog.fromJson(a.toJson());
      expect(fromJson.locationKind, LocationKind.away);
      expect(fromJson.longitude, closeTo(-3.7000, 0.0001));
      expect(fromJson.placeLabel, 'Oficina');
    });
  });

  group('InsightsEngine (V1.6 Paid on Throne, Insights & Wrapped)', () {
    test('calculates work earnings, generates insights, and builds Wrapped', () {
      final now = DateTime(2026, 11, 26, 14, 0);
      final logs = List.generate(
        4,
        (i) => BathroomLog(
          id: 'w-$i',
          type: BathroomType.poop,
          timestamp: DateTime(2026, 11, 23 + i, 10, 0),
          bristolType: 4,
          durationSeconds: 900, // 15 min each => 60 min total
          tags: const ['work', 'coffee'],
          locationKind: LocationKind.away,
          latitude: 40.5 + i * 0.1,
          longitude: -3.7,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final paid = InsightsEngine.calculatePaidOnThrone(
        logs,
        hourlyRate: 20.0,
        now: now,
      );
      expect(paid.workVisitsTotal, 4);
      expect(paid.workSecondsTotal, 3600);
      expect(paid.earnedThisMonth, closeTo(20.0, 0.01));
      expect(paid.earnedAllTime, closeTo(20.0, 0.01));

      final stats = StatsCalculator.calculate(logs, now: now);
      final insights = InsightsEngine.generateInsights(logs, stats);
      expect(
        insights.map((i) => i.type),
        containsAll([
          InsightType.busiestWeekday,
          InsightType.topBristol,
          InsightType.topTriggerTag,
          InsightType.awaySuperpower,
          InsightType.timeMovies,
        ]),
      );

      final wrapped = InsightsEngine.buildWrapped(
        logs,
        period: WrappedPeriod.thisMonth,
        hourlyRate: 20.0,
        now: now,
      );
      expect(wrapped.totalPoops, 4);
      expect(wrapped.awayPercent, 100);
      expect(wrapped.earnedAtWork, closeTo(20.0, 0.01));
      expect(wrapped.archetype, WrappedArchetype.nomad);

      final gam = GamificationEngine.evaluate(logs);
      expect(
        gam.achievements.firstWhere((a) => a.id == 'paid_throne_pro').isUnlocked,
        isTrue,
      );
    });
  });
}
