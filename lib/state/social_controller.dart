import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database_helper.dart';
import '../models/group_challenges.dart';
import '../models/social_models.dart';
import '../models/social_plus.dart';
import '../services/settings_service.dart';
import '../services/supabase_sync_service.dart';
import 'trono_controller.dart';

class SocialController extends ChangeNotifier {
  SocialController({
    required TronoController tronoController,
    required BathroomRepository repository,
    required this._settings,
    SupabaseSyncService? service,
  }) : _trono = tronoController,
       _repo = repository,
       _service = service ?? SupabaseSyncService.instance;

  final TronoController _trono;
  final BathroomRepository _repo;
  final SettingsService _settings;
  final SupabaseSyncService _service;

  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _realtimeChannel;
  Timer? _syncDebounce;
  Timer? _realtimeDebounce;

  UserProfile? _myProfile;
  List<SocialGroup> _groups = const [];
  String? _selectedGroupId;
  List<SharedFeedItem> _feed = const [];
  List<LeaderboardEntry> _leaderboard = const [];
  List<LeaderboardEntry> _weeklyLeaderboard = const [];
  SocialPlusSnapshot _socialPlus = const SocialPlusSnapshot();
  GroupChallengesSnapshot _challenges = const GroupChallengesSnapshot();
  int _leaderboardDays = 7;

  bool _isSyncing = false;
  bool _isLoadingSocial = false;
  DateTime? _lastSyncedAt;
  String? _lastError;
  int _pendingSyncCount = 0;

  bool get isCloudReady => _service.isInitialized;
  bool get isSignedIn => _service.isSignedIn;
  String? get currentUserId => _service.currentUser?.id;
  String? get currentEmail => _service.currentUser?.email;

  UserProfile? get myProfile => _myProfile;
  List<SocialGroup> get groups => _groups;
  String? get selectedGroupId => _selectedGroupId;
  SocialGroup? get selectedGroup {
    if (_groups.isEmpty) return null;
    for (final g in _groups) {
      if (g.id == _selectedGroupId) return g;
    }
    return _groups.first;
  }

  List<SharedFeedItem> get feed => _feed;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<LeaderboardEntry> get weeklyLeaderboard => _weeklyLeaderboard;
  SocialPlusSnapshot get socialPlus => _socialPlus;
  GroupChallengesSnapshot get challenges => _challenges;
  int get leaderboardDays => _leaderboardDays;

  GroupWrappedSnapshot? buildGroupWeeklyWrapped() {
    final active = selectedGroup;
    if (active == null) return null;
    return SocialPlusEngine.buildGroupWeeklyWrapped(
      group: active,
      weeklyLeaderboard: _weeklyLeaderboard,
      feed: _feed,
    );
  }

  void _recomputeSocialPlus() {
    _socialPlus = SocialPlusEngine.evaluate(
      currentUserId: currentUserId,
      groups: _groups,
      feed: _feed,
      weeklyLeaderboard: _weeklyLeaderboard,
    );
    final active = selectedGroup;
    _challenges = active == null
        ? const GroupChallengesSnapshot()
        : GroupChallengesEngine.compute(
            feed: _feed,
            weeklyLeaderboard: _weeklyLeaderboard,
            memberCount: active.memberCount,
          );
  }

  bool get isSyncing => _isSyncing;
  bool get isLoadingSocial => _isLoadingSocial;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  int get pendingSyncCount => _pendingSyncCount;

  Future<void> init() async {
    _selectedGroupId = _settings.selectedGroupId;
    await _refreshPendingCount();

    _trono.setOnLogsMutated(() {
      unawaited(_refreshPendingCount());
      scheduleBackgroundSync();
    });

    if (!_service.isInitialized) return;

    _authSub = _service.onAuthStateChange.listen((authState) {
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        if (_service.isSignedIn) {
          _attachRealtime();
          unawaited(syncAndRefreshSocial());
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _handleSignedOutLocally();
      }
      notifyListeners();
    });

    if (_service.isSignedIn) {
      _attachRealtime();
      unawaited(syncAndRefreshSocial());
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      final pending = await _repo.getPendingSyncLogs();
      _pendingSyncCount = pending.length;
      notifyListeners();
    } catch (_) {}
  }

  void scheduleBackgroundSync() {
    if (!_service.isSignedIn) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(syncNow(refreshFeedAfter: true));
    });
  }

  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String avatarEmoji,
  }) async {
    _lastError = null;
    notifyListeners();
    final outcome = await _service.signUp(
      email: email,
      password: password,
      displayName: displayName,
      avatarEmoji: avatarEmoji,
    );
    if (outcome.status == AuthOutcomeStatus.signedIn) {
      _attachRealtime();
      await syncAndRefreshSocial();
    }
    notifyListeners();
    return outcome;
  }

  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    _lastError = null;
    notifyListeners();
    final outcome = await _service.signIn(email: email, password: password);
    _attachRealtime();
    await syncAndRefreshSocial();
    notifyListeners();
    return outcome;
  }

  Future<void> signOut() async {
    await _service.unsubscribeChannel(_realtimeChannel);
    _realtimeChannel = null;
    await _service.signOut();
    _handleSignedOutLocally();
    notifyListeners();
  }

  void _handleSignedOutLocally() {
    _myProfile = null;
    _groups = const [];
    _feed = const [];
    _leaderboard = const [];
    _weeklyLeaderboard = const [];
    _socialPlus = const SocialPlusSnapshot();
    _challenges = const GroupChallengesSnapshot();
    _lastError = null;
    unawaited(_service.unsubscribeChannel(_realtimeChannel));
    _realtimeChannel = null;
  }

  Future<void> updateProfile({
    required String displayName,
    required String avatarEmoji,
  }) async {
    final updated = await _service.upsertMyProfile(
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      totalXp: _trono.gamification.totalXp,
      rankLevel: _trono.gamification.currentRank.level,
      currentStreak: _trono.stats.currentStreak,
    );
    _myProfile = updated;
    notifyListeners();
    await refreshSocial();
  }

  Future<SyncReport> syncNow({bool refreshFeedAfter = false}) async {
    if (!_service.isSignedIn || _isSyncing) return const SyncReport();

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final report = await _service.syncLogs(
        repository: _repo,
        totalXp: _trono.gamification.totalXp,
        rankLevel: _trono.gamification.currentRank.level,
        currentStreak: _trono.stats.currentStreak,
      );
      _lastSyncedAt = DateTime.now();
      await _refreshPendingCount();

      if (report.pulledCount > 0) {
        await _trono.reloadLogs(suppressNotifications: true);
      }

      _myProfile = await _service.fetchMyProfile();
      if (refreshFeedAfter) {
        await refreshSocial();
      }
      return report;
    } catch (e) {
      _lastError = e.toString();
      return const SyncReport();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncAndRefreshSocial() async {
    await syncNow(refreshFeedAfter: true);
  }

  Future<void> refreshSocial() async {
    if (!_service.isSignedIn) return;
    _isLoadingSocial = true;
    _lastError = null;
    notifyListeners();

    try {
      _myProfile ??= await _service.fetchMyProfile();
      _groups = await _service.fetchMyGroups();

      if (_groups.isEmpty) {
        _selectedGroupId = null;
        _feed = const [];
        _leaderboard = const [];
        _weeklyLeaderboard = const [];
        _recomputeSocialPlus();
      } else {
        final active = selectedGroup!;
        if (_selectedGroupId != active.id) {
          _selectedGroupId = active.id;
          await _settings.setSelectedGroupId(active.id);
        }

        final futures = <Future<dynamic>>[
          _service.fetchGroupFeed(active),
          _service.fetchGroupLeaderboard(
            groupId: active.id,
            days: _leaderboardDays,
          ),
          if (_leaderboardDays != 7)
            _service.fetchGroupLeaderboard(
              groupId: active.id,
              days: 7,
            ),
        ];
        final results = await Future.wait(futures);
        _feed = results[0] as List<SharedFeedItem>;
        _leaderboard = results[1] as List<LeaderboardEntry>;
        _weeklyLeaderboard = _leaderboardDays == 7
            ? _leaderboard
            : (results[2] as List<LeaderboardEntry>);
        _recomputeSocialPlus();
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoadingSocial = false;
      notifyListeners();
    }
  }

  Future<void> selectGroup(String groupId) async {
    if (_selectedGroupId == groupId) return;
    _selectedGroupId = groupId;
    await _settings.setSelectedGroupId(groupId);
    notifyListeners();
    await refreshSocial();
  }

  Future<void> setLeaderboardDays(int days) async {
    if (_leaderboardDays == days) return;
    _leaderboardDays = days;
    notifyListeners();
    final active = selectedGroup;
    if (active == null || !_service.isSignedIn) return;
    try {
      _leaderboard = await _service.fetchGroupLeaderboard(
        groupId: active.id,
        days: _leaderboardDays,
      );
      if (_leaderboardDays == 7) {
        _weeklyLeaderboard = _leaderboard;
        _recomputeSocialPlus();
      }
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<SocialGroup> createGroup({
    required String name,
    required String emoji,
  }) async {
    final created = await _service.createGroup(name: name, emoji: emoji);
    _selectedGroupId = created.id;
    await _settings.setSelectedGroupId(created.id);
    await refreshSocial();
    return created;
  }

  Future<SocialGroup> joinGroupByCode(String code) async {
    final joined = await _service.joinGroupByCode(code);
    _selectedGroupId = joined.id;
    await _settings.setSelectedGroupId(joined.id);
    await refreshSocial();
    return joined;
  }

  Future<void> leaveGroup(String groupId) async {
    await _service.leaveGroup(groupId);
    if (_selectedGroupId == groupId) {
      _selectedGroupId = null;
      await _settings.setSelectedGroupId(null);
    }
    await refreshSocial();
  }

  Future<void> toggleReaction(String logId, String emoji) async {
    final uid = currentUserId;
    if (uid == null) return;

    final idx = _feed.indexWhere((item) => item.logId == logId);
    if (idx < 0) return;

    final item = _feed[idx];
    final alreadyReacted = item.hasReacted(emoji, uid);

    // Optimistic update for snappy tactile UX
    final updatedReactions = List<LogReaction>.from(item.reactions);
    if (alreadyReacted) {
      updatedReactions.removeWhere((r) => r.userId == uid && r.emoji == emoji);
    } else {
      updatedReactions.add(
        LogReaction(
          id: 'optimistic-$logId-$uid-$emoji',
          logId: logId,
          userId: uid,
          emoji: emoji,
        ),
      );
    }
    final nextFeed = List<SharedFeedItem>.from(_feed);
    nextFeed[idx] = item.copyWith(reactions: updatedReactions);
    _feed = nextFeed;
    _recomputeSocialPlus();
    notifyListeners();

    try {
      if (alreadyReacted) {
        await _service.removeReaction(logId: logId, emoji: emoji);
      } else {
        await _service.addReaction(logId: logId, emoji: emoji);
      }
    } catch (_) {
      // Revert on failure
      await refreshSocial();
    }
  }

  Future<bool> addComment(String logId, String body) async {
    final cleanBody = LogComment.validateBody(body);
    if (cleanBody == null) return false;

    final uid = currentUserId;
    if (uid == null) return false;

    final idx = _feed.indexWhere((item) => item.logId == logId);
    if (idx < 0) return false;

    final optimisticId =
        'optimistic-comment-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = LogComment(
      id: optimisticId,
      logId: logId,
      userId: uid,
      displayName: _myProfile?.displayName ?? 'Trono',
      avatarEmoji: _myProfile?.avatarEmoji ?? '👑',
      body: cleanBody,
      createdAt: DateTime.now(),
    );

    final item = _feed[idx];
    final nextFeed = List<SharedFeedItem>.from(_feed);
    nextFeed[idx] = item.copyWith(comments: [...item.comments, optimistic]);
    _feed = nextFeed;
    _lastError = null;
    notifyListeners();

    try {
      final saved = await _service.addComment(logId: logId, body: cleanBody);
      final currentIdx = _feed.indexWhere((i) => i.logId == logId);
      if (currentIdx >= 0) {
        final currentItem = _feed[currentIdx];
        final replaced = currentItem.comments
            .map((c) => c.id == optimisticId ? saved : c)
            .toList();
        if (!replaced.any((c) => c.id == saved.id)) {
          replaced.add(saved);
        }
        final reconciledFeed = List<SharedFeedItem>.from(_feed);
        reconciledFeed[currentIdx] = currentItem.copyWith(comments: replaced);
        _feed = reconciledFeed;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      final currentIdx = _feed.indexWhere((i) => i.logId == logId);
      if (currentIdx >= 0) {
        final currentItem = _feed[currentIdx];
        final rolledBack = currentItem.comments
            .where((c) => c.id != optimisticId)
            .toList();
        final revertedFeed = List<SharedFeedItem>.from(_feed);
        revertedFeed[currentIdx] = currentItem.copyWith(comments: rolledBack);
        _feed = revertedFeed;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(String logId, String commentId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final idx = _feed.indexWhere((item) => item.logId == logId);
    if (idx < 0) return false;

    final item = _feed[idx];
    final commentIdx = item.comments.indexWhere((c) => c.id == commentId);
    if (commentIdx < 0) return false;

    final target = item.comments[commentIdx];
    if (target.userId != uid) return false;

    final updatedComments = List<LogComment>.from(item.comments)
      ..removeAt(commentIdx);
    final nextFeed = List<SharedFeedItem>.from(_feed);
    nextFeed[idx] = item.copyWith(comments: updatedComments);
    _feed = nextFeed;
    _lastError = null;
    notifyListeners();

    try {
      await _service.deleteComment(commentId);
      return true;
    } catch (e) {
      _lastError = e.toString();
      final currentIdx = _feed.indexWhere((i) => i.logId == logId);
      if (currentIdx >= 0) {
        final currentItem = _feed[currentIdx];
        if (!currentItem.comments.any((c) => c.id == target.id)) {
          final restored = List<LogComment>.from(currentItem.comments);
          final insertAt = commentIdx.clamp(0, restored.length);
          restored.insert(insertAt, target);
          final revertedFeed = List<SharedFeedItem>.from(_feed);
          revertedFeed[currentIdx] = currentItem.copyWith(comments: restored);
          _feed = revertedFeed;
        }
      }
      notifyListeners();
      return false;
    }
  }

  void _attachRealtime() {
    if (_realtimeChannel != null || !_service.isSignedIn) return;
    _realtimeChannel = _service.subscribeToSocialUpdates(
      onUpdate: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 500), () {
          unawaited(refreshSocial());
        });
      },
    );
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _realtimeDebounce?.cancel();
    _authSub?.cancel();
    unawaited(_service.unsubscribeChannel(_realtimeChannel));
    super.dispose();
  }
}
