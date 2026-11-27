import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/config/feature_flags.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/app_update.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/group_challenges.dart';
import 'package:trono/models/social_models.dart';
import 'package:trono/models/social_plus.dart';
import 'package:trono/screens/calendar_stats_screen.dart';
import 'package:trono/screens/home_screen.dart';
import 'package:trono/screens/map_screen.dart';
import 'package:trono/screens/social_screen.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/update_banner_card.dart';

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
  }) : _selectedId = fakeGroups.isNotEmpty ? fakeGroups.first.id : null;

  final List<SocialGroup> fakeGroups;
  final List<SharedFeedItem> fakeFeed;
  final List<LeaderboardEntry> fakeLeaderboard;
  String? _selectedId;

  @override
  bool get isSignedIn => true;

  @override
  String? get currentUserId => 'u1';

  @override
  UserProfile? get myProfile => const UserProfile(
    id: 'u1',
    displayName: 'Alex',
    avatarEmoji: '👑',
    totalXp: 150,
    rankLevel: 2,
    currentStreak: 4,
  );

  @override
  List<SocialGroup> get groups => fakeGroups;

  @override
  SocialGroup? get selectedGroup {
    if (fakeGroups.isEmpty) return null;
    return fakeGroups.firstWhere(
      (g) => g.id == _selectedId,
      orElse: () => fakeGroups.first,
    );
  }

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

  @override
  Future<void> selectGroup(String groupId) async {
    _selectedId = groupId;
    notifyListeners();
  }
}

void main() {
  group('FeatureFlags & Seasonal Wrapped (V2.6)', () {
    test('showWrapped defaults to false (Spotify-style seasonal mode)', () {
      expect(FeatureFlags.showWrapped, isFalse);
    });

    testWidgets('hides Personal Wrapped entry points in CalendarStatsScreen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final ctrl = TronoController(
        repository: _MemoryRepo(),
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.5.0',
          httpGet: (_) async => null,
        ),
      );
      await tester.runAsync(() => ctrl.init());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: CalendarStatsScreen(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar sparkle Wrapped icon hidden
      expect(find.byTooltip('Trono Wrapped'), findsNothing);

      // Insights sub-tab Wrapped banner hidden
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('View Trono Wrapped'), findsNothing);

      ctrl.dispose();
    });
  });

  group('UpdateCheckerService.fetchReleaseByTag & Read-Only Changelog (V2.6)', () {
    test('builds tag URI, parses release notes, caches result, and handles offline', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();

      expect(
        UpdateCheckerService.releaseByTagUri('2.5.0').toString(),
        'https://api.github.com/repos/goritm/Trono/releases/tags/v2.5.0',
      );
      expect(
        UpdateCheckerService.releaseByTagUri('v2.5.0+5').toString(),
        'https://api.github.com/repos/goritm/Trono/releases/tags/v2.5.0',
      );

      int calls = 0;
      final svc = UpdateCheckerService(
        settings: settings,
        httpGet: (uri) async {
          calls++;
          if (uri.path.endsWith('/tags/v2.5.0')) {
            return '''
            {
              "tag_name": "v2.5.0",
              "html_url": "https://github.com/goritm/Trono/releases/tag/v2.5.0",
              "body": "- **Trigger Lab**\\n- Group Challenges",
              "assets": []
            }
            ''';
          }
          return null;
        },
      );

      final first = await svc.fetchReleaseByTag('2.5.0');
      expect(first, isNotNull);
      expect(first!.tagName, 'v2.5.0');
      expect(ReleaseNotesFormatter.extractLines(first.releaseNotes), [
        'Trigger Lab',
        'Group Challenges',
      ]);

      // Second call hits in-memory cache
      final second = await svc.fetchReleaseByTag('v2.5.0');
      expect(second?.tagName, 'v2.5.0');
      expect(calls, 1);

      // Missing / offline tag returns null safely
      expect(await svc.fetchReleaseByTag('9.9.9'), isNull);
    });

    testWidgets('showReleaseNotesSheet hides download button when onDownload is null', (
      tester,
    ) async {
      const release = AppReleaseInfo(
        tagName: 'v2.5.0',
        version: SemVer(2, 5, 0),
        downloadUrl: 'https://github.com/goritm/Trono/releases/tag/v2.5.0',
        isDirectApk: false,
        releaseNotes: '- Trigger Lab\n- Local Smart Reminders',
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
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showReleaseNotesSheet(ctx, release: release),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('What’s new in v2.5.0'), findsOneWidget);
      expect(find.text('Trigger Lab'), findsOneWidget);
      expect(find.byKey(const ValueKey('release_notes_download_btn')), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('SocialScreen 3-Tab Redesign & Header Group Switcher (V2.6)', () {
    testWidgets('renders 3 pinned tabs (Feed · Challenges · Ranking), separates Challenges from Feed, and switches groups via header sheet', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final repo = _MemoryRepo();
      final trono = TronoController(
        repository: repo,
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.5.0',
          httpGet: (_) async => null,
        ),
      );
      await tester.runAsync(() => trono.init());

      final now = DateTime.now();
      final g1 = SocialGroup(
        id: 'g1',
        name: 'Home Squad',
        emoji: '🏠',
        inviteCode: 'HOM123',
        createdBy: 'u1',
        createdAt: now,
        members: const [
          GroupMember(
            userId: 'u1',
            displayName: 'Alex',
            avatarEmoji: '👑',
            role: 'owner',
            totalXp: 150,
            rankLevel: 2,
            currentStreak: 4,
          ),
          GroupMember(
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            role: 'member',
            totalXp: 120,
            rankLevel: 2,
            currentStreak: 3,
          ),
        ],
      );
      final g2 = SocialGroup(
        id: 'g2',
        name: 'Office VIP',
        emoji: '💼',
        inviteCode: 'OFF456',
        createdBy: 'u1',
        createdAt: now,
        members: const [
          GroupMember(
            userId: 'u1',
            displayName: 'Alex',
            avatarEmoji: '👑',
            role: 'owner',
            totalXp: 150,
            rankLevel: 2,
            currentStreak: 4,
          ),
        ],
      );

      final fakeSocial = _FakeSocialController(
        tronoController: trono,
        repository: repo,
        settings: settings,
        fakeGroups: [g1, g2],
        fakeFeed: [
          SharedFeedItem(
            logId: 'l1',
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            rankLevel: 2,
            type: BathroomType.poop,
            timestamp: now.subtract(const Duration(minutes: 10)),
            shareLevel: ShareLevel.full,
            locationKind: LocationKind.home,
          ),
        ],
        fakeLeaderboard: const [
          LeaderboardEntry(
            userId: 'u2',
            displayName: 'Sam',
            avatarEmoji: '🦊',
            poopCount: 5,
            awayCount: 2,
            workCount: 1,
            currentStreak: 3,
            totalXp: 120,
            rankLevel: 2,
            totalDurationSeconds: 900,
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
          home: SocialScreen(social: fakeSocial),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Pinned 3-way sub-tabs visible right at the top
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Ranking'), findsOneWidget);

      // 2. Feed tab shows live feed directly without Weekly Challenges / Awards cluttering above it
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('WEEKLY CHALLENGES'), findsNothing);
      expect(find.text('Weekly Wrapped'), findsNothing);

      // 3. Challenges tab cleanly houses Weekly Challenges & Group Awards
      await tester.tap(find.text('Challenges'));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY CHALLENGES'), findsOneWidget);
      expect(find.text('GROUP AWARDS'), findsOneWidget);

      // 4. Ranking tab shows Leaderboard
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);

      // 5. Header Group Switcher pill opens bottom sheet to switch groups & see invite code
      await tester.tap(find.byKey(const ValueKey('social_group_switcher_btn')));
      await tester.pumpAndSettle();
      expect(find.text('HOM123'), findsOneWidget);
      expect(find.text('Office VIP'), findsOneWidget);

      await tester.tap(find.text('Office VIP'));
      await tester.pumpAndSettle();
      expect(fakeSocial.selectedGroup?.id, 'g2');

      trono.dispose();
    });

    testWidgets('keeps Settings gear icon at the exact same pixel position across all 4 root tabs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final repo = _MemoryRepo();
      final trono = TronoController(
        repository: repo,
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.5.0',
          httpGet: (_) async => null,
        ),
      );
      await tester.runAsync(() => trono.init());
      final social = SocialController(
        tronoController: trono,
        repository: repo,
        settings: settings,
      );

      Future<Rect> measureSettingsRect(Widget screen) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const [Locale('en'), Locale('es')],
            home: Scaffold(body: screen),
          ),
        );
        await tester.pump();
        final gear = find.byIcon(Icons.settings_outlined);
        expect(gear, findsOneWidget);
        return tester.getRect(gear);
      }

      final homeRect = await measureSettingsRect(
        HomeScreen(controller: trono, onOpenSettings: () {}),
      );
      final statsRect = await measureSettingsRect(
        CalendarStatsScreen(controller: trono, onOpenSettings: () {}),
      );
      final mapRect = await measureSettingsRect(
        MapScreen(controller: trono, isRootTab: true, onOpenSettings: () {}),
      );
      final friendsRect = await measureSettingsRect(
        SocialScreen(social: social, onOpenSettings: () {}),
      );

      expect(statsRect, homeRect);
      expect(mapRect, homeRect);
      expect(friendsRect, homeRect);

      social.dispose();
      trono.dispose();
    });
  });
}
