import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/database_helper.dart';
import '../models/bathroom_log.dart';
import '../models/push_notification_config.dart';
import '../models/social_models.dart';
import 'google_native_auth_service.dart';

enum AuthOutcomeStatus {
  signedIn,
  needsEmailConfirmation,
}

class AuthOutcome {
  const AuthOutcome({
    required this.status,
    this.email,
  });

  final AuthOutcomeStatus status;
  final String? email;
}

class SyncReport {
  const SyncReport({
    this.pushedCount = 0,
    this.pulledCount = 0,
  });

  final int pushedCount;
  final int pulledCount;
}

/// Handles all Supabase Auth, offline-first cloud sync, groups, feed,
/// reactions, leaderboards, and Realtime subscriptions for Trono V2.
class SupabaseSyncService {
  SupabaseSyncService._();

  @visibleForTesting
  SupabaseSyncService.forTesting();

  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _initialized = true;
    } catch (_) {
      // Offline or already initialized; keep app working 100% locally.
      _initialized = false;
    }
  }

  SupabaseClient? get client => _initialized ? Supabase.instance.client : null;

  User? get currentUser => client?.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange =>
      client?.auth.onAuthStateChange ?? const Stream.empty();

  // ---------------- Auth ----------------

  Future<AuthOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String avatarEmoji,
  }) async {
    final c = _requireClient();
    final cleanName = displayName.trim();
    final res = await c.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': cleanName.isEmpty ? 'Trono' : cleanName,
        'avatar_emoji': avatarEmoji,
      },
    );

    if (res.session != null && res.user != null) {
      await upsertMyProfile(
        displayName: cleanName.isEmpty ? 'Trono' : cleanName,
        avatarEmoji: avatarEmoji,
      );
      return AuthOutcome(
        status: AuthOutcomeStatus.signedIn,
        email: res.user!.email,
      );
    }

    return AuthOutcome(
      status: AuthOutcomeStatus.needsEmailConfirmation,
      email: res.user?.email ?? email.trim(),
    );
  }

  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final c = _requireClient();
    final res = await c.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return AuthOutcome(
      status: AuthOutcomeStatus.signedIn,
      email: res.user?.email ?? email.trim(),
    );
  }

  /// Signs in with Google using Android's native 1-tap Credential Manager
  /// (`signInWithIdToken`) when available, automatically falling back to the
  /// PKCE browser OAuth flow (`com.trono.trono://login-callback`) otherwise.
  Future<bool> signInWithGoogle() async {
    final c = _requireClient();
    if (!kIsWeb) {
      final nativeResult = await GoogleNativeAuthService()
          .requestIdToken(serverClientId: SupabaseConfig.googleWebClientId);
      if (nativeResult.status == GoogleNativeAuthStatus.ok &&
          nativeResult.idToken != null) {
        await c.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: nativeResult.idToken!,
          nonce: nativeResult.rawNonce,
        );
        return true;
      }
      if (nativeResult.status == GoogleNativeAuthStatus.cancelled) {
        throw const GoogleSignInCancelledException();
      }
    }
    return c.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : SupabaseConfig.oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Resolves a clean display name (1..32 chars) from Supabase user metadata
  /// (covering both custom signUp `display_name` and Google OAuth `full_name` /
  /// `name` fields). Convenience fallback only; never used for authorization.
  static String resolveDisplayNameFromMetadata(
    Map<String, dynamic>? meta, {
    String? email,
  }) {
    final candidates = <String?>[
      meta?['display_name'] as String?,
      meta?['full_name'] as String?,
      meta?['name'] as String?,
      if (email != null && email.contains('@')) email.split('@').first,
    ];
    for (final raw in candidates) {
      final clean = raw?.trim() ?? '';
      if (clean.isNotEmpty) {
        return clean.length > 32 ? clean.substring(0, 32) : clean;
      }
    }
    return 'Trono';
  }

  Future<void> signOut() async {
    final c = client;
    if (c == null) return;
    await c.auth.signOut();
  }

  // ---------------- Push Tokens (FCM) ----------------

  Future<void> upsertMyPushToken({
    required String token,
    required String locale,
    required SocialNotificationPrefs prefs,
    String platform = 'android',
  }) async {
    final c = client;
    if (c == null || !isSignedIn) return;
    final cleanToken = token.trim();
    if (cleanToken.length < 20) return;

    await c.rpc(
      'upsert_my_push_token',
      params: {
        'p_token': cleanToken,
        'p_platform': platform,
        'p_locale': locale.startsWith('es') ? 'es' : 'en',
        'p_notify_friend_thrones': prefs.friendThrones,
        'p_notify_friend_comments': prefs.friendComments,
        'p_notify_friend_reactions': prefs.friendReactions,
      },
    );
  }

  Future<void> deletePushToken(String token) async {
    final c = client;
    if (c == null || !isSignedIn) return;
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;
    await c.from('push_tokens').delete().eq('token', cleanToken);
  }

  // ---------------- Profile ----------------

  Future<UserProfile?> fetchMyProfile() async {
    final c = client;
    final uid = currentUser?.id;
    if (c == null || uid == null) return null;

    final row = await c
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  Future<UserProfile> upsertMyProfile({
    required String displayName,
    required String avatarEmoji,
    int? totalXp,
    int? rankLevel,
    int? currentStreak,
  }) async {
    final c = _requireClient();
    final uid = _requireUserId();
    final payload = <String, dynamic>{
      'id': uid,
      'display_name': displayName.trim().isEmpty ? 'Trono' : displayName.trim(),
      'avatar_emoji': avatarEmoji,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'total_xp': ?totalXp,
      if (rankLevel != null) 'rank_level': rankLevel.clamp(1, 7),
      'current_streak': ?currentStreak,
    };

    final row = await c
        .from('profiles')
        .upsert(payload, onConflict: 'id')
        .select()
        .single();
    return UserProfile.fromMap(row);
  }

  Future<void> syncProfileStats({
    required int totalXp,
    required int rankLevel,
    required int currentStreak,
  }) async {
    final c = client;
    final uid = currentUser?.id;
    if (c == null || uid == null) return;

    await c
        .from('profiles')
        .update({
          'total_xp': totalXp,
          'rank_level': rankLevel.clamp(1, 7),
          'current_streak': currentStreak,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid);
  }

  // ---------------- Offline-First Log Sync ----------------

  Future<SyncReport> syncLogs({
    required BathroomRepository repository,
    required int totalXp,
    required int rankLevel,
    required int currentStreak,
  }) async {
    final c = client;
    final uid = currentUser?.id;
    if (c == null || uid == null) return const SyncReport();

    // Ensure profile exists & stays fresh with latest XP / rank / streak
    final existingProfile = await fetchMyProfile();
    if (existingProfile == null) {
      final meta = currentUser?.userMetadata ?? const {};
      await upsertMyProfile(
        displayName: resolveDisplayNameFromMetadata(
          meta,
          email: currentUser?.email,
        ),
        avatarEmoji: (meta['avatar_emoji'] as String?) ?? '👑',
        totalXp: totalXp,
        rankLevel: rankLevel,
        currentStreak: currentStreak,
      );
    } else {
      await syncProfileStats(
        totalXp: totalXp,
        rankLevel: rankLevel,
        currentStreak: currentStreak,
      );
    }

    // 1. Push pending local logs (excluding exact GPS lat/lng!)
    final pending = await repository.getPendingSyncLogs();
    int pushed = 0;
    if (pending.isNotEmpty) {
      const batchSize = 50;
      for (int i = 0; i < pending.length; i += batchSize) {
        final chunk = pending.sublist(
          i,
          (i + batchSize > pending.length) ? pending.length : i + batchSize,
        );
        final payload = chunk
            .map((log) => CloudLogMapper.toSupabaseRow(log, userId: uid))
            .toList();
        await c.from('bathroom_logs').upsert(payload, onConflict: 'id');
        await repository.markLogsSynced(chunk.map((l) => l.id).toList());
        pushed += chunk.length;
      }
    }

    // 2. Pull remote logs for this user (restores history on new devices)
    final remoteRaw = await c
        .from('bathroom_logs')
        .select()
        .eq('user_id', uid)
        .order('timestamp', ascending: false);
    final remoteRows = List<Map<String, dynamic>>.from(remoteRaw as List);

    final allLocal = await repository.getAllLogsIncludingDeleted();
    final localById = <String, BathroomLog>{
      for (final log in allLocal) log.id: log,
    };

    final merges = CloudLogMapper.computeRemoteMerges(
      remoteRows: remoteRows,
      localById: localById,
    );
    if (merges.isNotEmpty) {
      await repository.upsertLogsBatch(merges);
    }

    return SyncReport(pushedCount: pushed, pulledCount: merges.length);
  }

  // ---------------- Groups ----------------

  Future<List<SocialGroup>> fetchMyGroups() async {
    final c = client;
    if (c == null || currentUser == null) return const [];

    final groupsRaw = await c
        .from('groups')
        .select()
        .order('created_at', ascending: true);
    final groupRows = List<Map<String, dynamic>>.from(groupsRaw as List);
    if (groupRows.isEmpty) return const [];

    final groupIds = groupRows.map((g) => g['id'].toString()).toList();
    final membersRaw = await c
        .from('group_members')
        .select(
          'group_id, user_id, role, profiles(id, display_name, avatar_emoji, total_xp, rank_level, current_streak)',
        )
        .inFilter('group_id', groupIds);
    final memberRows = List<Map<String, dynamic>>.from(membersRaw as List);

    final membersByGroup = <String, List<GroupMember>>{};
    for (final row in memberRows) {
      final gid = row['group_id']?.toString() ?? '';
      final profileMap = row['profiles'] as Map<String, dynamic>?;
      final member = GroupMember(
        userId: row['user_id']?.toString() ?? '',
        displayName: (profileMap?['display_name'] as String?) ?? 'Trono',
        avatarEmoji: (profileMap?['avatar_emoji'] as String?) ?? '👑',
        role: row['role']?.toString() ?? 'member',
        totalXp: (profileMap?['total_xp'] as num?)?.toInt() ?? 0,
        rankLevel: (profileMap?['rank_level'] as num?)?.toInt() ?? 1,
        currentStreak: (profileMap?['current_streak'] as num?)?.toInt() ?? 0,
      );
      membersByGroup.putIfAbsent(gid, () => []).add(member);
    }

    return groupRows.map((g) {
      final gid = g['id'].toString();
      return SocialGroup.fromMap(
        g,
        members: membersByGroup[gid] ?? const [],
      );
    }).toList();
  }

  Future<SocialGroup> createGroup({
    required String name,
    required String emoji,
  }) async {
    final c = _requireClient();
    final res = await c.rpc(
      'create_group',
      params: {'p_name': name.trim(), 'p_emoji': emoji},
    );
    return SocialGroup.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<SocialGroup> joinGroupByCode(String code) async {
    final c = _requireClient();
    final res = await c.rpc(
      'join_group_by_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return SocialGroup.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<void> leaveGroup(String groupId) async {
    final c = _requireClient();
    final uid = _requireUserId();
    await c
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', uid);
  }

  // ---------------- Group Feed & Reactions ----------------

  Future<List<SharedFeedItem>> fetchGroupFeed(
    SocialGroup group, {
    int limit = 50,
  }) async {
    final c = client;
    if (c == null || currentUser == null) return const [];
    if (group.members.isEmpty) return const [];

    final memberIds = group.members.map((m) => m.userId).toList();
    final profileById = <String, UserProfile>{
      for (final m in group.members)
        m.userId: UserProfile(
          id: m.userId,
          displayName: m.displayName,
          avatarEmoji: m.avatarEmoji,
          totalXp: m.totalXp,
          rankLevel: m.rankLevel,
          currentStreak: m.currentStreak,
        ),
    };

    final logsRaw = await c
        .from('shared_logs')
        .select()
        .inFilter('user_id', memberIds)
        .order('timestamp', ascending: false)
        .limit(limit);
    final logRows = List<Map<String, dynamic>>.from(logsRaw as List);
    if (logRows.isEmpty) return const [];

    final logIds = logRows.map((r) => r['log_id'].toString()).toList();
    final extras = await Future.wait<dynamic>([
      c.from('log_reactions').select().inFilter('log_id', logIds),
      c
          .from('log_comments')
          .select(
            'id, log_id, user_id, body, created_at, profiles(display_name, avatar_emoji)',
          )
          .inFilter('log_id', logIds)
          .order('created_at', ascending: true),
    ]);
    final reactionRows = List<Map<String, dynamic>>.from(extras[0] as List);
    final commentRows = List<Map<String, dynamic>>.from(extras[1] as List);

    final reactionsByLog = <String, List<LogReaction>>{};
    for (final row in reactionRows) {
      final reaction = LogReaction.fromMap(row);
      reactionsByLog.putIfAbsent(reaction.logId, () => []).add(reaction);
    }

    final commentsByLog = <String, List<LogComment>>{};
    for (final row in commentRows) {
      final comment = LogComment.fromMap(row);
      commentsByLog.putIfAbsent(comment.logId, () => []).add(comment);
    }

    return logRows.map((row) {
      final uid = row['user_id'].toString();
      final author =
          profileById[uid] ??
          UserProfile(
            id: uid,
            displayName: 'Trono',
            avatarEmoji: '👑',
            totalXp: 0,
            rankLevel: 1,
            currentStreak: 0,
          );
      final logId = row['log_id'].toString();
      return SharedFeedItem.fromMap(
        row,
        author: author,
        reactions: reactionsByLog[logId] ?? const [],
        comments: commentsByLog[logId] ?? const [],
      );
    }).toList();
  }

  Future<void> addReaction({
    required String logId,
    required String emoji,
  }) async {
    final c = _requireClient();
    final uid = _requireUserId();
    await c.from('log_reactions').upsert(
      {
        'log_id': logId,
        'user_id': uid,
        'emoji': emoji,
      },
      onConflict: 'log_id,user_id,emoji',
    );
  }

  Future<void> removeReaction({
    required String logId,
    required String emoji,
  }) async {
    final c = _requireClient();
    final uid = _requireUserId();
    await c
        .from('log_reactions')
        .delete()
        .eq('log_id', logId)
        .eq('user_id', uid)
        .eq('emoji', emoji);
  }

  Future<LogComment> addComment({
    required String logId,
    required String body,
  }) async {
    final cleanBody = LogComment.validateBody(body);
    if (cleanBody == null) {
      throw ArgumentError('INVALID_COMMENT_BODY');
    }
    final c = _requireClient();
    final uid = _requireUserId();
    final row = await c
        .from('log_comments')
        .insert({
          'log_id': logId,
          'user_id': uid,
          'body': cleanBody,
        })
        .select(
          'id, log_id, user_id, body, created_at, profiles(display_name, avatar_emoji)',
        )
        .single();
    return LogComment.fromMap(row);
  }

  Future<void> deleteComment(String commentId) async {
    final c = _requireClient();
    final uid = _requireUserId();
    await c
        .from('log_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', uid);
  }

  // ---------------- Leaderboard ----------------

  Future<List<LeaderboardEntry>> fetchGroupLeaderboard({
    required String groupId,
    required int days,
  }) async {
    final c = client;
    if (c == null || currentUser == null) return const [];

    final res = await c.rpc(
      'get_group_leaderboard',
      params: {'p_group_id': groupId, 'p_days': days},
    );
    final rows = List<Map<String, dynamic>>.from(res as List);
    return rows.map(LeaderboardEntry.fromMap).toList();
  }

  // ---------------- Realtime ----------------

  RealtimeChannel? subscribeToSocialUpdates({
    required void Function() onUpdate,
  }) {
    final c = client;
    if (c == null || currentUser == null) return null;

    final channel = c
        .channel('trono-social-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shared_logs',
          callback: (_) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'log_reactions',
          callback: (_) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'log_comments',
          callback: (_) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (_) => onUpdate(),
        )
        .subscribe();

    return channel;
  }

  Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    final c = client;
    if (c == null || channel == null) return;
    try {
      await c.removeChannel(channel);
    } catch (_) {}
  }

  SupabaseClient _requireClient() {
    final c = client;
    if (c == null) {
      throw StateError('SUPABASE_NOT_INITIALIZED');
    }
    return c;
  }

  String _requireUserId() {
    final uid = currentUser?.id;
    if (uid == null) {
      throw StateError('NOT_AUTHENTICATED');
    }
    return uid;
  }
}
