/// Independent Android NotificationChannel identifiers for social push alerts.
/// Each channel appears individually in Android system notification settings
/// so users can mute, silence, or customize sound/vibration per category.
enum SocialNotificationChannel {
  friendThrones('trono_friend_thrones'),
  friendComments('trono_friend_comments'),
  friendReactions('trono_friend_reactions');

  const SocialNotificationChannel(this.channelId);
  final String channelId;
}

/// Per-category toggles for friend push notifications (synced both locally on
/// Android and to `public.push_tokens` in Supabase).
class SocialNotificationPrefs {
  const SocialNotificationPrefs({
    this.friendThrones = true,
    this.friendComments = true,
    this.friendReactions = true,
  });

  final bool friendThrones;
  final bool friendComments;
  final bool friendReactions;

  SocialNotificationPrefs copyWith({
    bool? friendThrones,
    bool? friendComments,
    bool? friendReactions,
  }) {
    return SocialNotificationPrefs(
      friendThrones: friendThrones ?? this.friendThrones,
      friendComments: friendComments ?? this.friendComments,
      friendReactions: friendReactions ?? this.friendReactions,
    );
  }

  Map<String, Object> toPlatformMap() => {
    'notifyFriendThrones': friendThrones,
    'notifyFriendComments': friendComments,
    'notifyFriendReactions': friendReactions,
  };

  @override
  bool operator ==(Object other) =>
      other is SocialNotificationPrefs &&
      other.friendThrones == friendThrones &&
      other.friendComments == friendComments &&
      other.friendReactions == friendReactions;

  @override
  int get hashCode =>
      Object.hash(friendThrones, friendComments, friendReactions);
}
