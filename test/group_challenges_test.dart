import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/group_challenges.dart';
import 'package:trono/models/social_models.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/group_challenges_card.dart';

SharedFeedItem _feedItem(
  String logId, {
  String userId = 'u1',
  String displayName = 'Alex',
  String avatarEmoji = '👑',
  BathroomType type = BathroomType.poop,
  required DateTime timestamp,
  LocationKind? locationKind,
}) {
  return SharedFeedItem(
    logId: logId,
    userId: userId,
    displayName: displayName,
    avatarEmoji: avatarEmoji,
    rankLevel: 2,
    type: type,
    timestamp: timestamp,
    shareLevel: ShareLevel.full,
    locationKind: locationKind,
  );
}

LeaderboardEntry _leader(
  String userId, {
  String displayName = 'Alex',
  int poopCount = 0,
  int awayCount = 0,
  int workCount = 0,
}) {
  return LeaderboardEntry(
    userId: userId,
    displayName: displayName,
    avatarEmoji: '👑',
    totalXp: 100,
    rankLevel: 2,
    currentStreak: 3,
    poopCount: poopCount,
    awayCount: awayCount,
    workCount: workCount,
    totalDurationSeconds: 180,
  );
}

void main() {
  final now = DateTime(2026, 11, 26, 15, 30);

  group('GroupChallengesEngine (V2.5)', () {
    test('returns clean defaults for empty feed and leaderboard', () {
      final snap = GroupChallengesEngine.compute(
        feed: const [],
        weeklyLeaderboard: const [],
        memberCount: 1,
        now: now,
      );

      expect(snap.groupStreakDays, 0);
      expect(snap.activeDaysThisWeek, 0);
      expect(snap.totalCount, 3);
      expect(snap.completedCount, 0);
      expect(snap.allCompleted, isFalse);

      final byType = {for (final c in snap.challenges) c.type: c};
      expect(byType[GroupChallengeType.teamVolume]!.target, 7);
      expect(byType[GroupChallengeType.teamVolume]!.current, 0);
      expect(byType[GroupChallengeType.teamVolume]!.progress, 0.0);

      expect(byType[GroupChallengeType.awaySquad]!.target, 3);
      expect(byType[GroupChallengeType.awaySquad]!.current, 0);

      expect(byType[GroupChallengeType.syncedDuo]!.target, 1);
      expect(byType[GroupChallengeType.syncedDuo]!.current, 0);
    });

    test('computes group streak across consecutive calendar days ending today', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          // Today (2 logs from different users -> counts as 1 day)
          _feedItem('l1', userId: 'u1', timestamp: DateTime(2026, 11, 26, 9, 0)),
          _feedItem('l2', userId: 'u2', timestamp: DateTime(2026, 11, 26, 11, 0)),
          // Yesterday
          _feedItem('l3', userId: 'u2', timestamp: DateTime(2026, 11, 25, 22, 15)),
          // 2 days ago
          _feedItem('l4', userId: 'u1', timestamp: DateTime(2026, 11, 24, 8, 5)),
          // Gap on Nov 23, then older log on Nov 22
          _feedItem('l5', userId: 'u1', timestamp: DateTime(2026, 11, 22, 10, 0)),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: now,
      );

      expect(snap.groupStreakDays, 3);
      expect(snap.activeDaysThisWeek, 4);
    });

    test('preserves active streak if yesterday has a throne but today does not yet', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          _feedItem('l1', timestamp: DateTime(2026, 11, 25, 19, 0)),
          _feedItem('l2', timestamp: DateTime(2026, 11, 24, 14, 0)),
          // False alarm today should not extend or break streak
          _feedItem(
            'fa',
            type: BathroomType.falseAlarm,
            timestamp: DateTime(2026, 11, 26, 8, 0),
          ),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: now,
      );

      expect(snap.groupStreakDays, 2);
      expect(snap.activeDaysThisWeek, 2);
    });

    test('returns 0 group streak when last shared throne was 2+ days ago', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          _feedItem('l1', timestamp: DateTime(2026, 11, 24, 14, 0)),
          _feedItem('l2', timestamp: DateTime(2026, 11, 23, 14, 0)),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: now,
      );

      expect(snap.groupStreakDays, 0);
      expect(snap.activeDaysThisWeek, 2);
    });

    test('streak crosses month boundaries and ignores falseAlarm items', () {
      final nov2 = DateTime(2026, 11, 2, 12, 0);
      final snap = GroupChallengesEngine.compute(
        feed: [
          _feedItem('l1', timestamp: DateTime(2026, 11, 2, 9, 0)),
          _feedItem('l2', timestamp: DateTime(2026, 11, 1, 9, 0)),
          _feedItem('l3', timestamp: DateTime(2026, 10, 31, 21, 0)),
          _feedItem('l4', timestamp: DateTime(2026, 10, 30, 8, 0)),
          _feedItem(
            'fa1',
            type: BathroomType.falseAlarm,
            locationKind: LocationKind.away,
            timestamp: DateTime(2026, 11, 2, 10, 0),
          ),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: nov2,
      );

      expect(snap.groupStreakDays, 4);
      final byType = {for (final c in snap.challenges) c.type: c};
      expect(byType[GroupChallengeType.teamVolume]!.current, 4);
      expect(byType[GroupChallengeType.awaySquad]!.current, 0);
    });

    test('auto-scales targets by memberCount and uses weeklyLeaderboard when present', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          _feedItem('l1', userId: 'u1', timestamp: now.subtract(const Duration(hours: 2))),
          _feedItem('l2', userId: 'u2', timestamp: now.subtract(const Duration(hours: 2, minutes: 5))),
        ],
        weeklyLeaderboard: [
          _leader('u1', poopCount: 12, awayCount: 4, workCount: 2),
          _leader('u2', poopCount: 10, awayCount: 3, workCount: 1),
          _leader('u3', poopCount: 5, awayCount: 1, workCount: 0),
        ],
        memberCount: 3,
        now: now,
      );

      final byType = {for (final c in snap.challenges) c.type: c};
      // teamVolume: 27 / max(7, 3*7=21) -> completed, progress clamped to 1.0
      final volume = byType[GroupChallengeType.teamVolume]!;
      expect(volume.target, 21);
      expect(volume.current, 27);
      expect(volume.isCompleted, isTrue);
      expect(volume.progress, 1.0);

      // awaySquad: 8 / max(3, 3*2=6) -> completed
      final away = byType[GroupChallengeType.awaySquad]!;
      expect(away.target, 6);
      expect(away.current, 8);
      expect(away.isCompleted, isTrue);
      expect(away.progress, 1.0);

      // syncedDuo: 1 / 1 -> completed
      final duo = byType[GroupChallengeType.syncedDuo]!;
      expect(duo.target, 1);
      expect(duo.current, 1);
      expect(duo.isCompleted, isTrue);

      expect(snap.completedCount, 3);
      expect(snap.allCompleted, isTrue);
    });

    test('falls back to 7-day feed counts for teamVolume and awaySquad when leaderboard is empty', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          // Within 7 days: 4 poops (1 home, 1 work, 1 away, 1 null)
          _feedItem('1', userId: 'u1', locationKind: LocationKind.home, timestamp: now.subtract(const Duration(days: 1))),
          _feedItem('2', userId: 'u2', locationKind: LocationKind.work, timestamp: now.subtract(const Duration(days: 2))),
          _feedItem('3', userId: 'u1', locationKind: LocationKind.away, timestamp: now.subtract(const Duration(days: 3))),
          _feedItem('4', userId: 'u2', locationKind: null, timestamp: now.subtract(const Duration(days: 4))),
          // Outside 7 days: should be excluded from weekly missions
          _feedItem('old1', userId: 'u1', locationKind: LocationKind.away, timestamp: now.subtract(const Duration(days: 8))),
          _feedItem('old2', userId: 'u2', locationKind: LocationKind.work, timestamp: now.subtract(const Duration(days: 8, minutes: 5))),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: now,
      );

      final byType = {for (final c in snap.challenges) c.type: c};
      expect(byType[GroupChallengeType.teamVolume]!.current, 4);
      expect(byType[GroupChallengeType.teamVolume]!.target, 14);
      expect(byType[GroupChallengeType.awaySquad]!.current, 2);
      expect(byType[GroupChallengeType.awaySquad]!.target, 4);
      // Old duo (8 days ago) must NOT count for this week's syncedDuo
      expect(byType[GroupChallengeType.syncedDuo]!.current, 0);
      expect(byType[GroupChallengeType.syncedDuo]!.isCompleted, isFalse);
    });

    test('syncedDuo ignores same-user logs and pairs >15 min apart', () {
      final snap = GroupChallengesEngine.compute(
        feed: [
          // Same user 5 min apart -> NOT a duo
          _feedItem('a1', userId: 'u1', timestamp: now.subtract(const Duration(hours: 3))),
          _feedItem('a2', userId: 'u1', timestamp: now.subtract(const Duration(hours: 3, minutes: 5))),
          // Different users 20 min apart -> NOT a duo
          _feedItem('b1', userId: 'u1', timestamp: now.subtract(const Duration(hours: 1))),
          _feedItem('b2', userId: 'u2', timestamp: now.subtract(const Duration(hours: 1, minutes: 20))),
        ],
        weeklyLeaderboard: const [],
        memberCount: 2,
        now: now,
      );

      final duo = snap.challenges.firstWhere(
        (c) => c.type == GroupChallengeType.syncedDuo,
      );
      expect(duo.current, 0);
      expect(duo.isCompleted, isFalse);
    });
  });

  group('GroupChallengesCard widget (V2.5)', () {
    testWidgets('renders in-progress missions & streak in English light mode', (tester) async {
      final snap = GroupChallengesSnapshot(
        groupStreakDays: 3,
        activeDaysThisWeek: 4,
        challenges: const [
          GroupChallenge(
            type: GroupChallengeType.teamVolume,
            current: 9,
            target: 14,
          ),
          GroupChallenge(
            type: GroupChallengeType.awaySquad,
            current: 4,
            target: 4,
          ),
          GroupChallenge(
            type: GroupChallengeType.syncedDuo,
            current: 0,
            target: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(
            body: SingleChildScrollView(
              child: GroupChallengesCard(snapshot: snap),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY CHALLENGES'), findsOneWidget);
      expect(find.textContaining('3d streak'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('9/14'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.byKey(const ValueKey('challenge_row_teamVolume')), findsOneWidget);
      expect(find.byKey(const ValueKey('challenge_row_awaySquad')), findsOneWidget);
      expect(find.byKey(const ValueKey('challenge_row_syncedDuo')), findsOneWidget);
      expect(find.byKey(const ValueKey('challenges_all_done_banner')), findsNothing);
    });

    testWidgets('renders Spanish dark mode & celebratory gold banner when allCompleted', (tester) async {
      final snap = GroupChallengesSnapshot(
        groupStreakDays: 5,
        activeDaysThisWeek: 5,
        challenges: const [
          GroupChallenge(
            type: GroupChallengeType.teamVolume,
            current: 16,
            target: 14,
          ),
          GroupChallenge(
            type: GroupChallengeType.awaySquad,
            current: 5,
            target: 4,
          ),
          GroupChallenge(
            type: GroupChallengeType.syncedDuo,
            current: 2,
            target: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(
            body: SingleChildScrollView(
              child: GroupChallengesCard(snapshot: snap),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RETOS SEMANALES'), findsOneWidget);
      expect(find.textContaining('Racha 5d'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byKey(const ValueKey('challenges_all_done_banner')), findsOneWidget);
    });
  });
}
