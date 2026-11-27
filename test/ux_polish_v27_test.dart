import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/group_challenges.dart';
import 'package:trono/models/social_models.dart';
import 'package:trono/models/social_plus.dart';
import 'package:trono/screens/home_screen.dart';
import 'package:trono/screens/settings_screen.dart';
import 'package:trono/screens/social_screen.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/log_detail_sheet.dart';

class _MemoryRepo implements BathroomRepository {
  final List<BathroomLog> _items = [];

  @override
  Future<void> clearAll() async => _items.clear();

  @override
  Future<List<BathroomLog>> getAllLogs() async => List.of(_items);

  @override
  Future<List<BathroomLog>> getAllLogsIncludingDeleted() async =>
      List.of(_items);

  @override
  Future<List<BathroomLog>> getPendingSyncLogs() async => const [];

  @override
  Future<void> markLogsSynced(List<String> ids) async {}

  @override
  Future<void> softDeleteLog(String id) async =>
      _items.removeWhere((e) => e.id == id);

  @override
  Future<void> upsertLog(BathroomLog log) async {
    _items.removeWhere((e) => e.id == log.id);
    _items.add(log);
  }

  @override
  Future<void> upsertLogsBatch(List<BathroomLog> logs) async {
    for (final l in logs) {
      await upsertLog(l);
    }
  }
}

class _FakeSocialController extends SocialController {
  _FakeSocialController({
    required super.tronoController,
    required super.repository,
    required super.settings,
    required this.fakeGroups,
    required this.fakeFeed,
    required this.fakeLeaderboard,
  });

  final List<SocialGroup> fakeGroups;
  final List<SharedFeedItem> fakeFeed;
  final List<LeaderboardEntry> fakeLeaderboard;

  @override
  bool get isSignedIn => true;

  @override
  String? get currentUserId => 'u1';

  @override
  UserProfile? get myProfile => const UserProfile(
    id: 'u1',
    displayName: 'Alex',
    avatarEmoji: '👑',
    totalXp: 120,
    rankLevel: 2,
    currentStreak: 3,
  );

  @override
  List<SocialGroup> get groups => fakeGroups;

  @override
  SocialGroup? get selectedGroup => fakeGroups.isEmpty ? null : fakeGroups.first;

  @override
  List<SharedFeedItem> get feed => fakeFeed;

  @override
  List<LeaderboardEntry> get leaderboard => fakeLeaderboard;

  @override
  SocialPlusSnapshot get socialPlus => SocialPlusEngine.evaluate(
    currentUserId: 'u1',
    groups: fakeGroups,
    feed: fakeFeed,
    weeklyLeaderboard: fakeLeaderboard,
  );

  @override
  GroupChallengesSnapshot get challenges => selectedGroup == null
      ? const GroupChallengesSnapshot()
      : GroupChallengesEngine.compute(
          feed: fakeFeed,
          weeklyLeaderboard: fakeLeaderboard,
          memberCount: selectedGroup!.memberCount,
        );
}

Future<TronoController> _createController(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = SettingsService();
  await settings.init();
  final ctrl = TronoController(
    repository: _MemoryRepo(),
    settings: settings,
    updateChecker: UpdateCheckerService(
      settings: settings,
      currentVersionProvider: () async => '2.6.0',
      httpGet: (_) async => null,
    ),
  );
  await tester.runAsync(() => ctrl.init());
  return ctrl;
}

void main() {
  group('V2.7 Two-State Sharing Privacy', () {
    test('selectableValues exposes only full & private and SettingsService normalizes legacy summary_only', () async {
      expect(ShareLevel.selectableValues, [ShareLevel.full, ShareLevel.private]);

      // Fresh install defaults to ShareLevel.full
      SharedPreferences.setMockInitialValues({});
      final s1 = SettingsService();
      await s1.init();
      expect(s1.defaultShareLevel, ShareLevel.full);

      // Legacy summary_only preference normalizes to ShareLevel.full
      SharedPreferences.setMockInitialValues({
        'default_share_level': 'summary_only',
      });
      final s2 = SettingsService();
      await s2.init();
      expect(s2.defaultShareLevel, ShareLevel.full);

      // Explicit private preference stays private
      SharedPreferences.setMockInitialValues({
        'default_share_level': 'private',
      });
      final s3 = SettingsService();
      await s3.init();
      expect(s3.defaultShareLevel, ShareLevel.private);
    });

    testWidgets('SettingsScreen & LogDetailSheet show only 2 sharing choices (no Summary only)', (
      tester,
    ) async {
      final ctrl = await _createController(tester);
      final social = SocialController(
        tronoController: ctrl,
        repository: _MemoryRepo(),
        settings: SettingsService()..init(),
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
          home: SettingsScreen(controller: ctrl, social: social),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Security & Privacy section
      await tester.scrollUntilVisible(
        find.text('Default privacy in groups'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('👥 Share with friends'), findsOneWidget);
      expect(find.text('🔒 Private'), findsOneWidget);
      expect(find.textContaining('Summary only'), findsNothing);

      // Verify LogDetailSheet also shows only 2 sharing chips
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLogDetailSheet(
                  ctx,
                  mode: LogSheetMode.createPast,
                  defaultShareLevel: ShareLevel.summaryOnly,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('👥 Share with friends'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('👥 Share with friends'), findsOneWidget);
      expect(find.text('🔒 Private'), findsOneWidget);
      expect(find.textContaining('Summary only'), findsNothing);

      social.dispose();
      ctrl.dispose();
    });
  });

  group('V2.7 Friends Tab Order (Feed | Ranking | Challenges) & Clean Feed Card', () {
    testWidgets('orders tabs as Feed, Ranking, Challenges and hides Summary only badge', (
      tester,
    ) async {
      final ctrl = await _createController(tester);
      final now = DateTime.now();
      final group = SocialGroup(
        id: 'g1',
        name: 'Squad',
        emoji: '👑',
        inviteCode: 'SQD123',
        createdBy: 'u1',
        createdAt: now,
        members: const [
          GroupMember(
            userId: 'u1',
            displayName: 'Alex',
            avatarEmoji: '👑',
            role: 'owner',
            totalXp: 120,
            rankLevel: 2,
            currentStreak: 3,
          ),
          GroupMember(
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            role: 'member',
            totalXp: 90,
            rankLevel: 2,
            currentStreak: 2,
          ),
        ],
      );

      final social = _FakeSocialController(
        tronoController: ctrl,
        repository: _MemoryRepo(),
        settings: SettingsService()..init(),
        fakeGroups: [group],
        fakeFeed: [
          SharedFeedItem(
            logId: 'l1',
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            rankLevel: 2,
            type: BathroomType.poop,
            timestamp: now.subtract(const Duration(minutes: 5)),
            shareLevel: ShareLevel.summaryOnly,
            locationKind: LocationKind.home,
          ),
        ],
        fakeLeaderboard: const [
          LeaderboardEntry(
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            poopCount: 4,
            awayCount: 1,
            workCount: 1,
            currentStreak: 2,
            totalXp: 90,
            rankLevel: 2,
            totalDurationSeconds: 600,
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
          home: SocialScreen(social: social),
        ),
      );
      await tester.pumpAndSettle();

      // Verify exact horizontal order: Feed < Ranking < Challenges
      final feedX = tester.getCenter(find.text('Feed')).dx;
      final rankingX = tester.getCenter(find.text('Ranking')).dx;
      final challengesX = tester.getCenter(find.text('Challenges')).dx;
      expect(feedX, lessThan(rankingX));
      expect(rankingX, lessThan(challengesX));

      // No noisy "Summary only" pill on feed card
      expect(find.textContaining('Summary only'), findsNothing);

      // Tapping middle tab (Ranking) shows leaderboard
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('7 days'), findsOneWidget);

      // Tapping third tab (Challenges) shows Weekly Challenges & Group Awards
      await tester.tap(find.text('Challenges'));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY CHALLENGES'), findsOneWidget);
      expect(find.text('GROUP AWARDS'), findsOneWidget);

      social.dispose();
      ctrl.dispose();
    });
  });

  group('V2.7 Clean Home & Dual-Mode Hero Timer', () {
    testWidgets('hides False Alarm from Home, puts + Past in history header, and transforms Hero button into live session timer', (
      tester,
    ) async {
      final ctrl = await _createController(
        tester,
        prefs: {
          'hourly_rate': 30.0,
          'currency_symbol': '€',
        },
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
            body: ListenableBuilder(
              listenable: ctrl,
              builder: (_, _) => HomeScreen(controller: ctrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Idle state: no False Alarm shortcut; single Start timer button; + Past in history header
      expect(find.text('False alarm'), findsNothing);
      expect(find.byKey(const ValueKey('home_start_timer_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_add_past_btn')), findsOneWidget);
      expect(find.text('CLAIM THRONE'), findsOneWidget);

      // Select WFH via clean single-pill Location picker sheet so live earnings pill appears
      await tester.tap(find.byKey(const ValueKey('home_location_picker_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick_loc_wfh')));
      await tester.pumpAndSettle();

      // 2. Tap Start timer -> Hero button transforms into live session timer + Cancel button
      await tester.tap(find.byKey(const ValueKey('home_start_timer_btn')));
      await tester.pump();
      expect(ctrl.isTimerRunning, isTrue);
      expect(find.byKey(const ValueKey('home_hero_timer_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_cancel_timer_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_start_timer_btn')), findsNothing);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('€0.00'), findsOneWidget);

      // 3. Cancel timer returns cleanly to idle Claim Throne hero
      await tester.tap(find.byKey(const ValueKey('home_cancel_timer_btn')));
      await tester.pumpAndSettle();
      expect(ctrl.isTimerRunning, isFalse);
      expect(ctrl.logs, isEmpty);
      expect(find.text('CLAIM THRONE'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_start_timer_btn')), findsOneWidget);

      ctrl.dispose();
    });
  });
}
