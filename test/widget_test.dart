import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/achievement.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/insights.dart';
import 'package:trono/models/monthly_comparison.dart';
import 'package:trono/models/social_models.dart';
import 'package:trono/models/social_plus.dart';
import 'package:trono/models/stats_summary.dart';
import 'package:trono/services/location_service.dart';
import 'package:trono/widgets/monthly_comparison_card.dart';
import 'package:trono/widgets/trono_toast.dart';

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
          tags: const ['coffee'],
          locationKind: LocationKind.work,
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

  group('Animation curves safety', () {
    test('TweenSequence bounce curve stays safely within [0, 1]', () {
      final seq = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 55),
        TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 45),
      ]);
      for (int i = 0; i <= 100; i++) {
        final t = Curves.easeOutCubic.transform(i / 100.0);
        expect(t, inInclusiveRange(0.0, 1.0));
        expect(seq.transform(t), inInclusiveRange(0.95, 1.05));
      }
    });
  });

  group('V2 Multiplayer & Cloud Sync Privacy', () {
    test('CloudLogMapper strips exact GPS coordinates and preserves them on pull', () {
      final t1 = DateTime.utc(2026, 11, 26, 12, 0);
      final t2 = DateTime.utc(2026, 11, 26, 12, 5);
      final local = BathroomLog(
        id: 'log-uuid-1',
        type: BathroomType.poop,
        timestamp: t1,
        bristolType: 4,
        tags: const ['coffee'],
        note: 'Morning brew',
        locationKind: LocationKind.work,
        latitude: 40.4168,
        longitude: -3.7038,
        placeLabel: 'Oficina',
        shareLevel: ShareLevel.summaryOnly,
        createdAt: t1,
        updatedAt: t1,
      );

      final cloudPayload = CloudLogMapper.toSupabaseRow(
        local,
        userId: 'user-1',
      );
      expect(cloudPayload.containsKey('latitude'), isFalse);
      expect(cloudPayload.containsKey('longitude'), isFalse);
      expect(cloudPayload['location_kind'], 'work');
      expect(cloudPayload['share_level'], 'summary_only');

      // Remote has a newer update (t2); merging must keep local lat/lng intact!
      final remoteUpdated = Map<String, dynamic>.from(cloudPayload)
        ..['note'] = 'Edited from another phone'
        ..['updated_at'] = t2.toIso8601String();

      final merges = CloudLogMapper.computeRemoteMerges(
        remoteRows: [remoteUpdated],
        localById: {local.id: local},
      );
      expect(merges, hasLength(1));
      expect(merges.first.note, 'Edited from another phone');
      expect(merges.first.latitude, closeTo(40.4168, 0.0001));
      expect(merges.first.longitude, closeTo(-3.7038, 0.0001));
      expect(merges.first.syncStatus, SyncStatus.synced);
    });

    test('SharedFeedItem enforces summary_only redaction & LeaderboardEntry computes away %', () {
      const author = UserProfile(
        id: 'u1',
        displayName: 'Jose',
        avatarEmoji: '👑',
        totalXp: 350,
        rankLevel: 3,
        currentStreak: 4,
      );

      final summaryItem = SharedFeedItem.fromMap(
        {
          'log_id': 'l1',
          'user_id': 'u1',
          'type': 'poop',
          'timestamp': '2026-11-26T10:00:00Z',
          'location_kind': 'away',
          'share_level': 'summary_only',
          // Even if extra fields existed in a map, summary_only must drop them
          'bristol_type': 4,
          'note': 'Should be hidden',
          'tags': ['coffee'],
        },
        author: author,
      );
      expect(summaryItem.bristolType, isNull);
      expect(summaryItem.note, isNull);
      expect(summaryItem.tags, isEmpty);
      expect(summaryItem.locationKind, LocationKind.away);

      final lb = LeaderboardEntry.fromMap({
        'user_id': 'u1',
        'display_name': 'Jose',
        'avatar_emoji': '👑',
        'total_xp': 350,
        'rank_level': 3,
        'current_streak': 4,
        'poop_count': 8,
        'away_count': 6,
        'work_count': 3,
        'total_duration_seconds': 1800,
      });
      expect(lb.awayPercent, 75);
    });
  });

  group('TronoToast auto-dismiss', () {
    testWidgets('toast with Undo action auto-dismisses after duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showTronoToast(
                  context,
                  'Registro eliminado',
                  actionLabel: 'Deshacer',
                  onAction: () {},
                  duration: const Duration(seconds: 3),
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Registro eliminado'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);

      // Advance past the 3s display duration + exit animation
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Registro eliminado'), findsNothing);
    });
  });

  group('Trono Social+ Engine (V2.1)', () {
    test('detects Synced Duos, unlocks social badges, and builds Group Weekly Wrapped', () {
      final now = DateTime(2026, 11, 26, 18, 0);
      final group = SocialGroup(
        id: 'g1',
        name: 'Los cagones',
        emoji: '🍻',
        inviteCode: 'TRN8K2',
        createdBy: 'u1',
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final feed = [
        SharedFeedItem(
          logId: 'l1',
          userId: 'u1',
          displayName: 'Jose',
          avatarEmoji: '🦍',
          rankLevel: 3,
          type: BathroomType.poop,
          timestamp: now.subtract(const Duration(minutes: 10)),
          shareLevel: ShareLevel.summaryOnly,
          locationKind: LocationKind.away,
          reactions: const [
            LogReaction(id: 'r1', logId: 'l1', userId: 'u2', emoji: '👑'),
            LogReaction(id: 'r2', logId: 'l1', userId: 'u2', emoji: '🔥'),
            LogReaction(id: 'r3', logId: 'l1', userId: 'u3', emoji: '👑'),
            LogReaction(id: 'r4', logId: 'l1', userId: 'u4', emoji: '👑'),
            LogReaction(id: 'r5', logId: 'l1', userId: 'u5', emoji: '👏'),
          ],
        ),
        SharedFeedItem(
          logId: 'l2',
          userId: 'u2',
          displayName: 'Ana',
          avatarEmoji: '🦄',
          rankLevel: 2,
          type: BathroomType.poop,
          // 6 minutes apart from Jose -> Synced Duo!
          timestamp: now.subtract(const Duration(minutes: 16)),
          shareLevel: ShareLevel.summaryOnly,
          locationKind: LocationKind.home,
          reactions: const [
            LogReaction(id: 'r6', logId: 'l2', userId: 'u1', emoji: '👑'),
            LogReaction(id: 'r7', logId: 'l2', userId: 'u1', emoji: '🔥'),
            LogReaction(id: 'r8', logId: 'l2', userId: 'u1', emoji: '💀'),
            LogReaction(id: 'r9', logId: 'l2', userId: 'u1', emoji: '👏'),
            LogReaction(id: 'r10', logId: 'l2', userId: 'u1', emoji: '👑'),
          ],
        ),
        SharedFeedItem(
          logId: 'l3',
          userId: 'u1',
          displayName: 'Jose',
          avatarEmoji: '🦍',
          rankLevel: 3,
          type: BathroomType.poop,
          // 2 hours earlier -> not a duo
          timestamp: now.subtract(const Duration(hours: 2)),
          shareLevel: ShareLevel.summaryOnly,
          locationKind: LocationKind.work,
        ),
      ];

      final leaderboard = const [
        LeaderboardEntry(
          userId: 'u1',
          displayName: 'Jose',
          avatarEmoji: '🦍',
          totalXp: 400,
          rankLevel: 3,
          currentStreak: 5,
          poopCount: 6,
          awayCount: 4,
          workCount: 2,
          totalDurationSeconds: 1200,
        ),
        LeaderboardEntry(
          userId: 'u2',
          displayName: 'Ana',
          avatarEmoji: '🦄',
          totalXp: 250,
          rankLevel: 2,
          currentStreak: 3,
          poopCount: 4,
          awayCount: 1,
          workCount: 0,
          totalDurationSeconds: 900,
        ),
      ];

      final plus = SocialPlusEngine.evaluate(
        currentUserId: 'u1',
        groups: [group],
        feed: feed,
        weeklyLeaderboard: leaderboard,
      );

      expect(plus.duos, hasLength(1));
      expect(plus.duos.first.gapMinutes, 6);
      expect(plus.duoByLogId['l1']?.partnerNameFor('l1'), 'Ana');
      expect(plus.duoByLogId['l2']?.partnerNameFor('l2'), 'Jose');
      expect(plus.unlockedCount, 6);

      final wrapped = SocialPlusEngine.buildGroupWeeklyWrapped(
        group: group,
        weeklyLeaderboard: leaderboard,
        feed: feed,
        now: now,
      );
      expect(wrapped.totalPoops, 10);
      expect(wrapped.awayPercent, 50);
      expect(wrapped.syncedDuosCount, 1);
      expect(wrapped.weeklyKing?.displayName, 'Jose');
      expect(wrapped.awayMvp?.displayName, 'Jose');
      expect(wrapped.totalReactions, 10);
      expect(wrapped.topReactionEmoji, '👑');
    });
  });

  group('MonthlyComparisonEngine & Charts (V2.2)', () {
    BathroomLog makeLog({
      required String id,
      required DateTime ts,
      BathroomType type = BathroomType.poop,
      int? bristol,
      LocationKind? loc,
      double? lat,
      double? lng,
    }) {
      return BathroomLog(
        id: id,
        type: type,
        timestamp: ts,
        bristolType: bristol,
        locationKind: loc,
        latitude: lat,
        longitude: lng,
        createdAt: ts,
        updatedAt: ts,
      );
    }

    test('computes delta %, daily averages, Bristol avg & ideal %, away %, and 8-week buckets', () {
      // Thursday, Nov 26, 2026 (days elapsed in Nov = 26, Oct has 31 days)
      // Current week Monday = Nov 23, 2026 (4 days elapsed in current week: Mon..Thu)
      final now = DateTime(2026, 11, 26, 14, 0);
      const homeLat = 40.4168;
      const homeLng = -3.7038;

      final logs = [
        // Current month (Nov 2026): 5 poops + 1 falseAlarm (excluded)
        makeLog(
          id: 'c1',
          ts: DateTime(2026, 11, 26, 9, 0), // Current week (idx 7)
          bristol: 4,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'c2',
          ts: DateTime(2026, 11, 24, 11, 0), // Current week (idx 7)
          bristol: 3,
          loc: LocationKind.work, // away
        ),
        makeLog(
          id: 'c3',
          ts: DateTime(2026, 11, 18, 10, 0), // Previous week (idx 6, Mon Nov 16)
          bristol: 4,
          // No explicit loc -> far from home coords -> auto-classified away
          lat: 41.3874,
          lng: 2.1686,
        ),
        makeLog(
          id: 'c4',
          ts: DateTime(2026, 11, 10, 8, 0), // 2 weeks ago (idx 5, Mon Nov 9)
          bristol: 6,
          // No explicit loc -> at home coords -> auto-classified home
          lat: 40.4168,
          lng: -3.7038,
        ),
        makeLog(
          id: 'c5',
          ts: DateTime(2026, 11, 3, 19, 0), // 3 weeks ago (idx 4, Mon Nov 2)
          loc: LocationKind.away,
        ),
        makeLog(
          id: 'c-false',
          ts: DateTime(2026, 11, 25, 16, 0),
          type: BathroomType.falseAlarm,
          bristol: 1,
          loc: LocationKind.away,
        ),

        // Previous month (Oct 2026): 4 poops
        makeLog(
          id: 'p1',
          ts: DateTime(2026, 10, 28, 9, 0), // idx 3 (Mon Oct 26)
          bristol: 2,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'p2',
          ts: DateTime(2026, 10, 20, 9, 0), // idx 2 (Mon Oct 19)
          bristol: 4,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'p3',
          ts: DateTime(2026, 10, 12, 9, 0), // idx 1 (Mon Oct 12)
          bristol: 4,
          loc: LocationKind.away,
        ),
        makeLog(
          id: 'p4',
          ts: DateTime(2026, 10, 5, 9, 0), // idx 0 (Mon Oct 5 — oldest of 8 weeks)
          loc: LocationKind.home,
        ),
        // Too old (before Oct 5): outside 8-week window & outside prev month
        makeLog(
          id: 'old1',
          ts: DateTime(2026, 9, 20, 9, 0),
          bristol: 7,
          loc: LocationKind.away,
        ),
      ];

      final snap = MonthlyComparisonEngine.compute(
        logs,
        now: now,
        homeLat: homeLat,
        homeLng: homeLng,
      );

      expect(snap.currentMonthPoops, 5);
      expect(snap.previousMonthPoops, 4);
      // ((5 - 4) * 100 / 4).round() == 25
      expect(snap.poopsDeltaPercent, 25);
      expect(snap.currentMonthAvgPerDay, closeTo(5 / 26, 0.001));
      expect(snap.previousMonthAvgPerDay, closeTo(4 / 31, 0.001));

      // Current month away: 3 away (c2 work, c3 far GPS, c5 away) / 5 classified = 60%
      expect(snap.currentMonthAwayPercent, 60);
      // Previous month away: 1 away / 4 classified = 25%
      expect(snap.previousMonthAwayPercent, 25);

      // Current month Bristol: (4 + 3 + 4 + 6) / 4 = 4.25; 3 of 4 are in {3, 4} = 75%
      expect(snap.currentMonthAvgBristol, closeTo(4.25, 0.001));
      expect(snap.idealBristolPercent, 75);
      // Previous month Bristol: (2 + 4 + 4) / 3 = 3.333
      expect(snap.previousMonthAvgBristol, closeTo(10 / 3, 0.001));

      // 8-week Monday–Sunday buckets ordered oldest to newest
      expect(snap.weeklyTrend, hasLength(8));
      expect(snap.weeklyTrend.first.weekStart, DateTime(2026, 10, 5));
      expect(snap.weeklyTrend.first.weekStart.weekday, DateTime.monday);
      expect(snap.weeklyTrend.last.weekStart, DateTime(2026, 11, 23));
      expect(snap.weeklyTrend.last.isCurrentWeek, isTrue);

      // Verify per-week counts & averages
      expect(snap.weeklyTrend[0].poopCount, 1); // Oct 5
      expect(snap.weeklyTrend[1].poopCount, 1); // Oct 12
      expect(snap.weeklyTrend[2].poopCount, 1); // Oct 19
      expect(snap.weeklyTrend[3].poopCount, 1); // Oct 26
      expect(snap.weeklyTrend[4].poopCount, 1); // Nov 2
      expect(snap.weeklyTrend[5].poopCount, 1); // Nov 9
      expect(snap.weeklyTrend[6].poopCount, 1); // Nov 16
      expect(snap.weeklyTrend[7].poopCount, 2); // Nov 23 (current week)
      expect(snap.weeklyTrend[7].avgPerDay, closeTo(2 / 4, 0.001));
      expect(snap.weeklyTrend[7].avgBristol, closeTo(3.5, 0.001));
      expect(snap.weeklyTrend[6].avgPerDay, closeTo(1 / 7, 0.001));
    });

    test('handles zero previous month and missing Bristol/location safely', () {
      final now = DateTime(2026, 1, 1, 10, 0); // Jan 1 -> prev month is Dec 2025
      final logs = [
        makeLog(id: 'j1', ts: DateTime(2026, 1, 1, 8, 0)),
        makeLog(id: 'j2', ts: DateTime(2026, 1, 1, 9, 30)),
      ];

      final snap = MonthlyComparisonEngine.compute(logs, now: now);

      expect(snap.currentMonth, DateTime(2026, 1, 1));
      expect(snap.previousMonth, DateTime(2025, 12, 1));
      expect(snap.currentMonthPoops, 2);
      expect(snap.previousMonthPoops, 0);
      expect(snap.poopsDeltaPercent, isNull);
      expect(snap.currentMonthAvgPerDay, closeTo(2.0, 0.001));
      expect(snap.previousMonthAvgPerDay, 0.0);
      expect(snap.currentMonthAwayPercent, isNull);
      expect(snap.previousMonthAwayPercent, isNull);
      expect(snap.currentMonthAvgBristol, isNull);
      expect(snap.previousMonthAvgBristol, isNull);
      expect(snap.idealBristolPercent, isNull);
      expect(snap.weeklyTrend, hasLength(8));
      expect(snap.weeklyTrend.last.poopCount, 2);
    });

    testWidgets('MonthlyComparisonCard and WeeklyTrendChartCard render and respond to bar taps', (tester) async {
      final now = DateTime(2026, 11, 26, 15, 0);
      final logs = [
        makeLog(
          id: 'w1',
          ts: DateTime(2026, 11, 25, 10, 0),
          bristol: 4,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'w2',
          ts: DateTime(2026, 11, 24, 10, 0),
          bristol: 3,
          loc: LocationKind.away,
        ),
        makeLog(
          id: 'w3',
          ts: DateTime(2026, 11, 17, 10, 0),
          bristol: 5,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'w4',
          ts: DateTime(2026, 10, 15, 10, 0),
          bristol: 4,
          loc: LocationKind.home,
        ),
        makeLog(
          id: 'w5',
          ts: DateTime(2026, 10, 10, 10, 0),
          bristol: 4,
          loc: LocationKind.away,
        ),
      ];
      final snap = MonthlyComparisonEngine.compute(logs, now: now);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  MonthlyComparisonCard(snapshot: snap),
                  const SizedBox(height: 16),
                  WeeklyTrendChartCard(weeks: snap.weeklyTrend),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monthly comparison renders delta (+50%) and ideal Bristol zone pill
      expect(find.text('ESTE MES VS MES PASADO'), findsOneWidget);
      expect(find.text('+50%'), findsOneWidget);
      expect(find.text('Zona ideal'), findsOneWidget);

      // Weekly trend chart renders 8 bars and defaults selection to current week (idx 7)
      expect(find.text('EVOLUCIÓN SEMANAL · 8 SEMANAS'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('2 pupús'), findsOneWidget);

      // Tap prior week bar (idx 6, week of 16/11 with 1 poop & Bristol 5.0)
      await tester.tap(find.byKey(const ValueKey('weekly_trend_bar_6')));
      await tester.pumpAndSettle();

      expect(find.text('Esta semana'), findsNothing);
      expect(find.text('1 pupú'), findsOneWidget);
      expect(find.text('Bristol 5.0'), findsOneWidget);
    });
  });
}
