import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/social_models.dart';
import 'package:trono/screens/social_screen.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/supabase_sync_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/social_controller.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';

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

class _FakeSyncService extends SupabaseSyncService {
  _FakeSyncService({
    required this.profile,
    required this.groups,
    required this.feedItems,
  }) : super.forTesting();

  final UserProfile profile;
  final List<SocialGroup> groups;
  List<SharedFeedItem> feedItems;

  bool failAddComment = false;
  bool failDeleteComment = false;
  final List<String> addedBodies = [];
  final List<String> deletedIds = [];
  int _nextId = 1;

  @override
  bool get isInitialized => true;

  @override
  bool get isSignedIn => true;

  @override
  User? get currentUser => User(
    id: profile.id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );

  @override
  Future<UserProfile?> fetchMyProfile() async => profile;

  @override
  Future<List<SocialGroup>> fetchMyGroups() async => groups;

  @override
  Future<List<SharedFeedItem>> fetchGroupFeed(
    SocialGroup group, {
    int limit = 50,
  }) async => List.of(feedItems);

  @override
  Future<List<LeaderboardEntry>> fetchGroupLeaderboard({
    required String groupId,
    required int days,
  }) async => const [];

  @override
  Future<LogComment> addComment({
    required String logId,
    required String body,
  }) async {
    if (failAddComment) {
      throw StateError('NETWORK_ERROR');
    }
    addedBodies.add(body);
    return LogComment(
      id: 'srv-c-${_nextId++}',
      logId: logId,
      userId: profile.id,
      displayName: profile.displayName,
      avatarEmoji: profile.avatarEmoji,
      body: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    if (failDeleteComment) {
      throw StateError('NETWORK_ERROR');
    }
    deletedIds.add(commentId);
  }
}

void main() {
  group('LogComment model & validation (V2.6)', () {
    test('validateBody trims valid text and rejects empty or >280 chars', () {
      expect(LogComment.validateBody(''), isNull);
      expect(LogComment.validateBody('   \n\t  '), isNull);
      expect(LogComment.validateBody('  Nice throne!  '), 'Nice throne!');
      expect(LogComment.validateBody('a' * 280), 'a' * 280);
      expect(LogComment.validateBody(' ${'a' * 280} '), 'a' * 280);
      expect(LogComment.validateBody('a' * 281), isNull);
    });

    test('fromMap parses nested profiles and handles missing profile defaults', () {
      final parsed = LogComment.fromMap({
        'id': 'c1',
        'log_id': 'l1',
        'user_id': 'u2',
        'body': 'Legendary!',
        'created_at': '2026-11-27T10:00:00Z',
        'profiles': {
          'display_name': 'Sam',
          'avatar_emoji': '🦊',
        },
      });

      expect(parsed.id, 'c1');
      expect(parsed.logId, 'l1');
      expect(parsed.userId, 'u2');
      expect(parsed.displayName, 'Sam');
      expect(parsed.avatarEmoji, '🦊');
      expect(parsed.body, 'Legendary!');
      expect(parsed.createdAt.isUtc, isFalse);

      final fallback = LogComment.fromMap({
        'id': 'c2',
        'log_id': 'l1',
        'user_id': 'u3',
        'body': 'Fallback author',
        'created_at': '2026-11-27T10:05:00Z',
      });

      expect(fallback.displayName, 'Trono');
      expect(fallback.avatarEmoji, '👑');
    });

    test('SharedFeedItem stores comments and preserves them across copyWith', () {
      final now = DateTime.now();
      final c1 = LogComment(
        id: 'c1',
        logId: 'l1',
        userId: 'u2',
        displayName: 'Sam',
        avatarEmoji: '🦊',
        body: 'First!',
        createdAt: now,
      );
      final item = SharedFeedItem(
        logId: 'l1',
        userId: 'u1',
        displayName: 'Alex',
        avatarEmoji: '👑',
        rankLevel: 2,
        type: BathroomType.poop,
        timestamp: now,
        shareLevel: ShareLevel.full,
        comments: [c1],
      );

      expect(item.comments.length, 1);
      final updatedReactions = item.copyWith(reactions: const []);
      expect(updatedReactions.comments.length, 1);

      final clearedComments = item.copyWith(comments: const []);
      expect(clearedComments.comments, isEmpty);
    });
  });

  group('SocialController optimistic comments & rollback (V2.6)', () {
    Future<(TronoController, SocialController, _FakeSyncService)> buildFixture({
      List<LogComment> initialComments = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      final repo = _MemoryRepo();
      final trono = TronoController(
        repository: repo,
        settings: settings,
        updateChecker: UpdateCheckerService(
          settings: settings,
          currentVersionProvider: () async => '2.6.0',
          httpGet: (_) async => null,
        ),
      );
      await trono.init();

      const me = UserProfile(
        id: 'u1',
        displayName: 'Alex',
        avatarEmoji: '👑',
        totalXp: 150,
        rankLevel: 2,
        currentStreak: 4,
      );
      final now = DateTime.now();
      final group = SocialGroup(
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
      final feed = [
        SharedFeedItem(
          logId: 'l1',
          userId: 'u2',
          displayName: 'Sam',
          avatarEmoji: '🦊',
          rankLevel: 2,
          type: BathroomType.poop,
          timestamp: now.subtract(const Duration(minutes: 5)),
          shareLevel: ShareLevel.full,
          locationKind: LocationKind.home,
          comments: initialComments,
        ),
      ];
      final fakeService = _FakeSyncService(
        profile: me,
        groups: [group],
        feedItems: feed,
      );
      final social = SocialController(
        tronoController: trono,
        repository: repo,
        settings: settings,
        service: fakeService,
      );
      await social.refreshSocial();
      return (trono, social, fakeService);
    }

    test('addComment validates, updates optimistically, and reconciles with server ID', () async {
      final (trono, social, service) = await buildFixture();

      // Rejects blank & >280 chars
      expect(await social.addComment('l1', '   '), isFalse);
      expect(await social.addComment('l1', 'x' * 281), isFalse);
      expect(social.feed.first.comments, isEmpty);

      // Accepts trimmed valid text
      final ok = await social.addComment('l1', '  Way to go!  ');
      expect(ok, isTrue);
      expect(service.addedBodies, ['Way to go!']);
      expect(social.feed.first.comments.length, 1);
      expect(social.feed.first.comments.first.id, 'srv-c-1');
      expect(social.feed.first.comments.first.body, 'Way to go!');

      social.dispose();
      trono.dispose();
    });

    test('addComment rolls back cleanly when server request fails', () async {
      final (trono, social, service) = await buildFixture();
      service.failAddComment = true;

      final ok = await social.addComment('l1', 'Will fail');
      expect(ok, isFalse);
      expect(social.feed.first.comments, isEmpty);

      social.dispose();
      trono.dispose();
    });

    test('deleteComment removes own comment, blocks deleting others, and rolls back on failure', () async {
      final now = DateTime.now();
      final own = LogComment(
        id: 'c-own',
        logId: 'l1',
        userId: 'u1',
        displayName: 'Alex',
        avatarEmoji: '👑',
        body: 'My comment',
        createdAt: now.subtract(const Duration(minutes: 2)),
      );
      final other = LogComment(
        id: 'c-other',
        logId: 'l1',
        userId: 'u2',
        displayName: 'Sam',
        avatarEmoji: '🦊',
        body: 'Friend comment',
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

      final (trono, social, service) = await buildFixture(
        initialComments: [own, other],
      );

      // Cannot delete another user's comment
      expect(await social.deleteComment('l1', 'c-other'), isFalse);
      expect(social.feed.first.comments.length, 2);

      // Rollback on failure
      service.failDeleteComment = true;
      expect(await social.deleteComment('l1', 'c-own'), isFalse);
      expect(social.feed.first.comments.length, 2);
      expect(social.feed.first.comments.first.id, 'c-own');

      // Success deletes own comment
      service.failDeleteComment = false;
      expect(await social.deleteComment('l1', 'c-own'), isTrue);
      expect(service.deletedIds, ['c-own']);
      expect(social.feed.first.comments.length, 1);
      expect(social.feed.first.comments.first.id, 'c-other');

      social.dispose();
      trono.dispose();
    });
  });

  group('SocialScreen Comments UI (V2.6)', () {
    testWidgets(
      'shows compact comment pill, opens Comments Bottom Sheet, adds & deletes own comment, hides delete on friend comment',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsService();
        await settings.init();
        final repo = _MemoryRepo();
        final trono = TronoController(
          repository: repo,
          settings: settings,
          updateChecker: UpdateCheckerService(
            settings: settings,
            currentVersionProvider: () async => '2.6.0',
            httpGet: (_) async => null,
          ),
        );
        await tester.runAsync(() => trono.init());

        final now = DateTime.now();
        const me = UserProfile(
          id: 'u1',
          displayName: 'Alex',
          avatarEmoji: '👑',
          totalXp: 150,
          rankLevel: 2,
          currentStreak: 4,
        );
        final group = SocialGroup(
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
        final friendComment = LogComment(
          id: 'c-friend',
          logId: 'l1',
          userId: 'u2',
          displayName: 'Sam',
          avatarEmoji: '🦊',
          body: 'Speedrun record!',
          createdAt: now.subtract(const Duration(minutes: 3)),
        );
        final fakeService = _FakeSyncService(
          profile: me,
          groups: [group],
          feedItems: [
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
              comments: [friendComment],
            ),
            SharedFeedItem(
              logId: 'l2',
              userId: 'u1',
              displayName: 'Alex',
              avatarEmoji: '👑',
              rankLevel: 2,
              type: BathroomType.poop,
              timestamp: now.subtract(const Duration(minutes: 20)),
              shareLevel: ShareLevel.summaryOnly,
              comments: const [],
            ),
          ],
        );
        final social = SocialController(
          tronoController: trono,
          repository: repo,
          settings: settings,
          service: fakeService,
        );
        await tester.runAsync(() => social.refreshSocial());

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

        // Feed card 1 shows clear comments footer with preview + "View 1 comment"
        final pill1 = find.byKey(const ValueKey('feed_comment_btn_l1'));
        expect(pill1, findsOneWidget);
        expect(
          find.descendant(
            of: pill1,
            matching: find.text('View 1 comment'),
          ),
          findsOneWidget,
        );

        // Feed card 2 shows "Add a comment..." CTA when there are 0 comments
        final pill2 = find.byKey(const ValueKey('feed_comment_btn_l2'));
        expect(pill2, findsOneWidget);
        expect(
          find.descendant(
            of: pill2,
            matching: find.text('Add a comment...'),
          ),
          findsOneWidget,
        );

        // Tap pill2 -> empty state
        await tester.tap(pill2);
        await tester.pumpAndSettle();
        expect(find.text('No comments yet — be the first!'), findsOneWidget);

        // Close sheet
        Navigator.of(tester.element(find.text('No comments yet — be the first!'))).pop();
        await tester.pumpAndSettle();

        // Tap pill1 -> shows friend's comment with NO delete icon
        await tester.tap(pill1);
        await tester.pumpAndSettle();
        expect(find.text('Speedrun record!'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('comment_delete_btn_c-friend')),
          findsNothing,
        );

        // Type & send own comment
        await tester.enterText(
          find.byKey(const ValueKey('comment_input_field')),
          'Absolute royalty!',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('comment_send_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Absolute royalty!'), findsOneWidget);
        final ownDeleteBtn = find.byKey(
          const ValueKey('comment_delete_btn_srv-c-1'),
        );
        expect(ownDeleteBtn, findsOneWidget);

        // Delete own comment
        await tester.tap(ownDeleteBtn);
        await tester.pumpAndSettle();
        expect(find.text('Absolute royalty!'), findsNothing);
        expect(find.text('Speedrun record!'), findsOneWidget);

        social.dispose();
        trono.dispose();
      },
    );

    testWidgets('renders Spanish copy parity in Comments Bottom Sheet', (
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
          currentVersionProvider: () async => '2.6.0',
          httpGet: (_) async => null,
        ),
      );
      await tester.runAsync(() => trono.init());

      final now = DateTime.now();
      const me = UserProfile(
        id: 'u1',
        displayName: 'Alex',
        avatarEmoji: '👑',
        totalXp: 150,
        rankLevel: 2,
        currentStreak: 4,
      );
      final group = SocialGroup(
        id: 'g1',
        name: 'Los del Trono',
        emoji: '👑',
        inviteCode: 'TRN123',
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
      final fakeService = _FakeSyncService(
        profile: me,
        groups: [group],
        feedItems: [
          SharedFeedItem(
            logId: 'l-es',
            userId: 'u1',
            displayName: 'Alex',
            avatarEmoji: '👑',
            rankLevel: 2,
            type: BathroomType.poop,
            timestamp: now,
            shareLevel: ShareLevel.summaryOnly,
          ),
        ],
      );
      final social = SocialController(
        tronoController: trono,
        repository: repo,
        settings: settings,
        service: fakeService,
      );
      await tester.runAsync(() => social.refreshSocial());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: SocialScreen(social: social),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('feed_comment_btn_l-es')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sin comentarios aún — ¡sé el primero!'),
        findsOneWidget,
      );
      expect(find.text('Añade un comentario...'), findsOneWidget);

      social.dispose();
      trono.dispose();
    });
  });
}
