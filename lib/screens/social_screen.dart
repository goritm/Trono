import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/social_models.dart';
import '../models/social_plus.dart';
import '../services/google_native_auth_service.dart';
import '../services/supabase_sync_service.dart';
import '../state/social_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/group_challenges_card.dart';
import '../widgets/trono_toast.dart';
import 'group_wrapped_screen.dart';

/// Opens the tactile Sign Up / Sign In modal sheet.
Future<void> showAuthSheet(
  BuildContext context,
  SocialController social, {
  bool initialSignUp = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AuthSheet(
      social: social,
      initialSignUp: initialSignUp,
    ),
  );
}

/// Opens the Edit Profile (alias + emoji avatar) modal dialog.
Future<void> showEditProfileDialog(
  BuildContext context,
  SocialController social,
) async {
  final s = AppStrings.of(context);
  final profile = social.myProfile;
  final nameCtrl = TextEditingController(text: profile?.displayName ?? '');
  String selectedEmoji = profile?.avatarEmoji ?? '👑';
  bool saving = false;

  final updated = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(s.editProfileTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.chooseAvatarLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: kAvatarEmojis.map((emoji) {
                        final active = emoji == selectedEmoji;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedEmoji = emoji),
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active
                                  ? TronoColors.terracotta.withValues(
                                      alpha: 0.16,
                                    )
                                  : TronoColors.surface(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? TronoColors.terracotta
                                    : TronoColors.border(ctx),
                                width: active ? 2.5 : 1.5,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: s.displayNameLabel,
                      hintText: s.displayNameHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TronoColors.coral,
                        side: BorderSide(
                          color: TronoColors.coral.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: Text(s.signOutBtn),
                                  content: Text(s.signOutConfirmBody),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(false),
                                      child: Text(s.cancelTimer),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: TronoColors.coral,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(true),
                                      child: Text(s.signOutBtn),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await social.signOut();
                                if (ctx.mounted) Navigator.of(ctx).pop(false);
                              }
                            },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        s.signOutBtn,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                child: Text(s.cancelTimer),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setModalState(() => saving = true);
                        try {
                          await social.updateProfile(
                            displayName: nameCtrl.text.trim(),
                            avatarEmoji: selectedEmoji,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (_) {
                          setModalState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.saveButton),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();

  if (updated == true && context.mounted) {
    showTronoToast(context, s.profileSavedToast);
  }
}

class SocialScreen extends StatefulWidget {
  const SocialScreen({
    super.key,
    required this.social,
    this.onOpenSettings,
  });

  final SocialController social;
  final VoidCallback? onOpenSettings;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _subTab = 0; // 0 = Feed, 1 = Ranking, 2 = Challenges

  Future<void> _showCreateGroupDialog() async {
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController();
    String selectedEmoji = kGroupEmojis.first;
    bool submitting = false;
    String? err;

    final created = await showDialog<SocialGroup>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text(s.createGroupBtn),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.groupEmojiLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: kGroupEmojis.map((emoji) {
                          final active = emoji == selectedEmoji;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedEmoji = emoji),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active
                                    ? TronoColors.terracotta.withValues(
                                        alpha: 0.16,
                                      )
                                    : TronoColors.surface(ctx),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? TronoColors.terracotta
                                      : TronoColors.border(ctx),
                                  width: active ? 2.5 : 1.5,
                                ),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: s.groupNameLabel,
                        hintText: s.groupNameHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        err!,
                        style: const TextStyle(
                          color: TronoColors.coral,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: Text(s.cancelTimer),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setModalState(() {
                            submitting = true;
                            err = null;
                          });
                          try {
                            final g = await widget.social.createGroup(
                              name: name,
                              emoji: selectedEmoji,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(g);
                          } catch (e) {
                            setModalState(() {
                              submitting = false;
                              err = s.authGenericError;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.createGroupBtn),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();

    if (created != null && mounted) {
      await Clipboard.setData(ClipboardData(text: created.inviteCode));
      if (!mounted) return;
      showTronoToast(
        context,
        '${created.emoji} ${created.name} · ${created.inviteCode}',
      );
    }
  }

  Future<void> _showJoinGroupDialog() async {
    final s = AppStrings.of(context);
    final codeCtrl = TextEditingController();
    bool submitting = false;
    String? err;

    final joined = await showDialog<SocialGroup>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text(s.joinGroupBtn),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeCtrl,
                    autofocus: true,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: s.inviteCodeLabel,
                      hintText: s.enterInviteCodeHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      err!,
                      style: const TextStyle(
                        color: TronoColors.coral,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: Text(s.cancelTimer),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          if (code.length != 6) {
                            setModalState(() => err = s.groupNotFoundError);
                            return;
                          }
                          setModalState(() {
                            submitting = true;
                            err = null;
                          });
                          try {
                            final g = await widget.social.joinGroupByCode(code);
                            if (ctx.mounted) Navigator.of(ctx).pop(g);
                          } catch (e) {
                            setModalState(() {
                              submitting = false;
                              err = e.toString().contains('GROUP_NOT_FOUND')
                                  ? s.groupNotFoundError
                                  : s.authGenericError;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.joinGroupBtn),
                ),
              ],
            );
          },
        );
      },
    );
    codeCtrl.dispose();

    if (joined != null && mounted) {
      showTronoToast(context, '${joined.emoji} ${joined.name}');
    }
  }

  Future<void> _confirmLeaveGroup(SocialGroup group) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s.leaveGroupBtn} (${group.name})'),
        content: Text(s.leaveGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancelTimer),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TronoColors.coral,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.leaveGroupBtn),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.social.leaveGroup(group.id);
    }
  }

  Future<void> _showGroupSwitcherSheet(
    BuildContext context,
    SocialController social,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: TronoColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return _GroupSwitcherSheet(
          social: social,
          onSelectGroup: (id) async {
            Navigator.of(sheetCtx).pop();
            await social.selectGroup(id);
          },
          onCreateGroup: () {
            Navigator.of(sheetCtx).pop();
            _showCreateGroupDialog();
          },
          onJoinGroup: () {
            Navigator.of(sheetCtx).pop();
            _showJoinGroupDialog();
          },
          onLeaveGroup: (group) {
            Navigator.of(sheetCtx).pop();
            _confirmLeaveGroup(group);
          },
          onOpenWrapped: () {
            Navigator.of(sheetCtx).pop();
            final wrapped = social.buildGroupWeeklyWrapped();
            if (wrapped == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupWrappedScreen(wrapped: wrapped),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCommentsSheet(
    BuildContext context,
    SocialController social,
    SharedFeedItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        social: social,
        initialItem: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.social,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final social = widget.social;

        if (!social.isSignedIn) {
          return _SignedOutView(
            social: social,
            onOpenSettings: widget.onOpenSettings,
          );
        }

        final activeGroup = social.selectedGroup;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.socialTitle),
            actions: [
              // Compact Group Switcher Pill in Header (next to Profile & Settings)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  key: const ValueKey('social_group_switcher_btn'),
                  onTap: () => _showGroupSwitcherSheet(context, social),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: TronoColors.surface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: TronoColors.border(context),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeGroup != null) ...[
                          Text(
                            activeGroup.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              activeGroup.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: TronoColors.ink(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: TronoColors.muted(context),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: TronoColors.terracotta,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            s.newGroupPill,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: TronoColors.ink(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Compact Profile Avatar Button (with subtle sync status dot)
              if (social.myProfile != null)
                Padding(
                  padding: EdgeInsets.only(
                    right: widget.onOpenSettings != null ? 2 : 12,
                  ),
                  child: InkWell(
                    key: const ValueKey('social_profile_btn'),
                    onTap: () => showEditProfileDialog(context, social),
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TronoColors.surface(context),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: TronoColors.border(context),
                              width: 2,
                            ),
                          ),
                          child: social.isSyncing
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TronoColors.terracotta,
                                  ),
                                )
                              : Text(
                                  social.myProfile!.avatarEmoji,
                                  style: const TextStyle(fontSize: 17),
                                ),
                        ),
                        if (social.pendingSyncCount > 0 && !social.isSyncing)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: TronoColors.gold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: TronoColors.bg(context),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (widget.onOpenSettings != null) ...[
                IconButton(
                  tooltip: s.navSettings,
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          body: social.isLoadingSocial && social.groups.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: TronoColors.terracotta,
                  ),
                )
              : activeGroup == null
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _NoGroupsCard(
                          onCreate: _showCreateGroupDialog,
                          onJoin: _showJoinGroupDialog,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Pinned 3-way Sub-Tabs (matching Stats & Map pattern)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: [
                                ButtonSegment(
                                  value: 0,
                                  label: Text(s.socialTabFeedShort),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text(s.socialTabRanking),
                                ),
                                ButtonSegment(
                                  value: 2,
                                  label: Text(s.socialTabChallenges),
                                ),
                              ],
                              selected: {_subTab},
                              onSelectionChanged: (set) =>
                                  setState(() => _subTab = set.first),
                              showSelectedIcon: false,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            color: TronoColors.terracotta,
                            onRefresh: social.syncAndRefreshSocial,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              children: switch (_subTab) {
                                0 => _buildFeedWidgets(
                                    context,
                                    social,
                                    activeGroup,
                                  ),
                                1 => _buildLeaderboardWidgets(context, social),
                                _ => _buildChallengesWidgets(context, social),
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  List<Widget> _buildFeedWidgets(
    BuildContext context,
    SocialController social,
    SocialGroup activeGroup,
  ) {
    final s = AppStrings.of(context);
    final widgets = <Widget>[];

    if (activeGroup.memberCount <= 1) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChunkyCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () => _showGroupSwitcherSheet(context, social),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 19,
                  color: TronoColors.terracotta,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.soloGroupInviteHint(activeGroup.inviteCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: TronoColors.ink(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: TronoColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (social.feed.isEmpty) {
      widgets.add(
        ChunkyCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('👑🚽', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 10),
              Text(
                s.emptyFeedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.emptyFeedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: TronoColors.muted(context),
                ),
              ),
            ],
          ),
        ),
      );
      return widgets;
    }

    final duoByLogId = social.socialPlus.duoByLogId;
    widgets.addAll(
      social.feed.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _FeedItemCard(
            item: item,
            currentUserId: social.currentUserId,
            syncedDuo: duoByLogId[item.logId],
            onReact: (emoji) {
              HapticFeedback.selectionClick();
              social.toggleReaction(item.logId, emoji);
            },
            onOpenComments: () {
              HapticFeedback.selectionClick();
              _showCommentsSheet(context, social, item);
            },
          ),
        );
      }),
    );
    return widgets;
  }

  List<Widget> _buildChallengesWidgets(
    BuildContext context,
    SocialController social,
  ) {
    return [
      if (social.challenges.challenges.isNotEmpty) ...[
        GroupChallengesCard(snapshot: social.challenges),
        const SizedBox(height: 14),
      ],
      _SocialBadgesCard(snapshot: social.socialPlus),
    ];
  }

  List<Widget> _buildLeaderboardWidgets(
    BuildContext context,
    SocialController social,
  ) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      Row(
        children: [
          _PeriodChip(
            label: s.rankingPeriodWeek,
            selected: social.leaderboardDays == 7,
            onTap: () => social.setLeaderboardDays(7),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: s.rankingPeriodMonth,
            selected: social.leaderboardDays == 30,
            onTap: () => social.setLeaderboardDays(30),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: s.rankingPeriodAll,
            selected: social.leaderboardDays == 0,
            onTap: () => social.setLeaderboardDays(0),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...social.leaderboard.asMap().entries.map((entry) {
        final rankIndex = entry.key;
        final row = entry.value;
        final isFirst = rankIndex == 0 && row.poopCount > 0;
        final isMe = row.userId == social.currentUserId;
        final medal = switch (rankIndex) {
          0 => '🥇',
          1 => '🥈',
          2 => '🥉',
          _ => '#${rankIndex + 1}',
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChunkyCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            color: isFirst
                ? (isDark ? const Color(0xFF2B2618) : const Color(0xFFFFF8E6))
                : null,
            borderColor: isFirst ? TronoColors.gold : null,
            lipColor: isFirst ? TronoColors.goldLip : null,
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    medal,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: rankIndex < 3 ? 22 : 14,
                      fontWeight: FontWeight.w900,
                      color: TronoColors.muted(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TronoColors.terracotta.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    row.avatarEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              row.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: TronoColors.terracotta.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.youBadge,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: TronoColors.terracotta,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            '🌍 ${s.awayPctShort(row.awayPercent)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                          Text(
                            '🔥 ${s.daysShort(row.currentStreak)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                          Text(
                            '⚡ ${row.totalXp} XP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${row.poopCount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: TronoColors.terracotta,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.poopsUnit,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.social, this.onOpenSettings});

  final SocialController social;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.socialTitle),
        actions: [
          if (onOpenSettings != null) ...[
            IconButton(
              tooltip: s.navSettings,
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
              ChunkyCard(
                color: TronoColors.obsidian,
                borderColor: const Color(0xFF343B4D),
                lipColor: TronoColors.obsidianLip,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TronoColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '👑',
                            style: TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.socialHeroTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.socialHeroSubtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.74),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _PerkRow(
                      icon: Icons.groups_rounded,
                      color: TronoColors.gold,
                      title: s.socialPerkGroupsTitle,
                      body: s.socialPerkGroupsBody,
                    ),
                    const SizedBox(height: 12),
                    _PerkRow(
                      icon: Icons.cloud_done_rounded,
                      color: TronoColors.sage,
                      title: s.socialPerkSyncTitle,
                      body: s.socialPerkSyncBody,
                    ),
                    const SizedBox(height: 12),
                    _PerkRow(
                      icon: Icons.lock_rounded,
                      color: TronoColors.terracotta,
                      title: s.socialPerkPrivacyTitle,
                      body: s.socialPerkPrivacyBody,
                    ),
                    const SizedBox(height: 22),
                    ChunkyButton(
                      width: double.infinity,
                      color: TronoColors.terracotta,
                      lipColor: TronoColors.terracottaLip,
                      onPressed: () => showAuthSheet(
                        context,
                        social,
                        initialSignUp: true,
                      ),
                      child: Center(
                        child: Text(
                          s.createAccountBtn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ChunkyButton(
                      width: double.infinity,
                      color: const Color(0xFF2B3140),
                      lipColor: TronoColors.obsidianLip,
                      borderColor: const Color(0xFF3E465B),
                      lipHeight: 4,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      onPressed: () => showAuthSheet(
                        context,
                        social,
                        initialSignUp: false,
                      ),
                      child: Center(
                        child: Text(
                          s.haveAccountSignIn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoGroupsCard extends StatelessWidget {
  const _NoGroupsCard({
    required this.onCreate,
    required this.onJoin,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ChunkyCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text('👥👑', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            s.noGroupsTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.noGroupsBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: TronoColors.muted(context),
            ),
          ),
          const SizedBox(height: 18),
          ChunkyButton(
            width: double.infinity,
            color: TronoColors.terracotta,
            lipColor: TronoColors.terracottaLip,
            onPressed: onCreate,
            child: Center(
              child: Text(
                s.createGroupBtn,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            width: double.infinity,
            color: TronoColors.surface(context),
            lipColor: TronoColors.lip(context),
            borderColor: TronoColors.border(context),
            lipHeight: 4,
            onPressed: onJoin,
            child: Center(
              child: Text(
                s.joinGroupBtn,
                style: TextStyle(
                  color: TronoColors.ink(context),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSwitcherSheet extends StatelessWidget {
  const _GroupSwitcherSheet({
    required this.social,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.onLeaveGroup,
    required this.onOpenWrapped,
  });

  final SocialController social;
  final ValueChanged<String> onSelectGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final ValueChanged<SocialGroup> onLeaveGroup;
  final VoidCallback onOpenWrapped;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final activeGroup = social.selectedGroup;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.groupsSheetTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: TronoColors.ink(context),
              ),
            ),
            const SizedBox(height: 12),
            ...social.groups.map((g) {
              final selected = g.id == activeGroup?.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? TronoColors.terracotta.withValues(alpha: 0.12)
                      : TronoColors.bg(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selected
                          ? TronoColors.terracotta
                          : TronoColors.border(context),
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => onSelectGroup(g.id),
                    leading: Text(
                      g.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      g.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TronoColors.ink(context),
                      ),
                    ),
                    subtitle: Text(
                      s.membersCountLabel(g.memberCount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TronoColors.muted(context),
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: TronoColors.terracotta,
                          )
                        : null,
                  ),
                ),
              );
            }),
            if (activeGroup != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TronoColors.obsidian,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF343B4D), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.inviteCodeLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeGroup.inviteCode,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  color: TronoColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: s.copyCodeBtn,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: activeGroup.inviteCode),
                            );
                            if (!context.mounted) return;
                            showTronoToast(context, s.codeCopiedToast);
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: TronoColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(
                                text: s.inviteShareMessage(
                                  activeGroup.name,
                                  activeGroup.inviteCode,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: Text(
                            s.shareCodeBtn,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (activeGroup.members.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: activeGroup.members.map((m) {
                          final isMe = m.userId == social.currentUserId;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? TronoColors.gold.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${m.avatarEmoji} ${m.displayName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isMe ? TronoColors.gold : Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (FeatureFlags.showWrapped) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ChunkyButton(
                          color: TronoColors.gold,
                          lipColor: TronoColors.goldLip,
                          lipHeight: 4,
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          onPressed: onOpenWrapped,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: TronoColors.obsidian,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                s.groupWrappedButton,
                                style: const TextStyle(
                                  color: TronoColors.obsidian,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => onLeaveGroup(activeGroup),
                        style: TextButton.styleFrom(
                          foregroundColor: TronoColors.coral,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          s.leaveGroupBtn,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    color: TronoColors.terracotta,
                    lipColor: TronoColors.terracottaLip,
                    lipHeight: 4,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onPressed: onCreateGroup,
                    child: Center(
                      child: Text(
                        s.createGroupBtn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChunkyButton(
                    color: TronoColors.bg(context),
                    lipColor: TronoColors.lip(context),
                    borderColor: TronoColors.border(context),
                    lipHeight: 4,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onPressed: onJoinGroup,
                    child: Center(
                      child: Text(
                        s.joinGroupBtn,
                        style: TextStyle(
                          color: TronoColors.ink(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialBadgesCard extends StatelessWidget {
  const _SocialBadgesCard({required this.snapshot});

  final SocialPlusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (snapshot.badges.isEmpty) return const SizedBox.shrink();

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: TronoColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.socialBadgesTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TronoColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${snapshot.unlockedCount}/${snapshot.badges.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: TronoColors.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...snapshot.badges.map((badge) {
            final unlocked = badge.isUnlocked;
            final bg = unlocked
                ? (isDark ? const Color(0xFF2B2618) : const Color(0xFFFFF8E6))
                : TronoColors.bg(context);
            final border =
                unlocked ? TronoColors.gold : TronoColors.border(context);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: border,
                    width: unlocked ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Opacity(
                      opacity: unlocked ? 1.0 : 0.45,
                      child: Text(
                        badge.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.socialBadgeTitle(badge.id),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: unlocked
                                  ? TronoColors.ink(context)
                                  : TronoColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.socialBadgeDesc(badge.id),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: TronoColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    unlocked
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: TronoColors.sage,
                            size: 20,
                          )
                        : Text(
                            '${badge.current}/${badge.target}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: TronoColors.muted(context),
                            ),
                          ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({
    required this.item,
    required this.currentUserId,
    required this.onReact,
    required this.onOpenComments,
    this.syncedDuo,
  });

  final SharedFeedItem item;
  final String? currentUserId;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenComments;
  final SyncedDuoPair? syncedDuo;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isMe = item.userId == currentUserId;

    return ChunkyCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TronoColors.terracotta.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  item.avatarEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${s.youBadge})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TronoColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'NV.${item.rankLevel}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.goldLip,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.type.emoji} ${s.typeName(item.type)} · ${s.relativeTime(item.timestamp)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.locationKind != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: TronoColors.bg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TronoColors.border(context)),
                  ),
                  child: Text(
                    '${item.locationKind!.emoji} ${s.locationKindName(item.locationKind!)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),

          if (syncedDuo != null) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2B2618)
                    : const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: TronoColors.gold, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      s.syncedDuoPill(
                        syncedDuo!.partnerEmojiFor(item.logId),
                        syncedDuo!.partnerNameFor(item.logId),
                        syncedDuo!.gapMinutes,
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: TronoColors.ink(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (item.shareLevel == ShareLevel.full) ...[
            if (item.bristolType != null ||
                item.size != null ||
                item.effort != null ||
                item.durationSeconds != null ||
                (item.placeLabel?.trim().isNotEmpty ?? false) ||
                item.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.bristolType != null)
                    _MiniDetailPill(
                      '${s.bristolEmoji(item.bristolType!)} ${s.bristolShort(item.bristolType!)}',
                    ),
                  if (item.size != null)
                    _MiniDetailPill(
                      '${item.size!.emoji} ${s.sizeName(item.size!)}',
                    ),
                  if (item.effort != null)
                    _MiniDetailPill(
                      '${item.effort!.emoji} ${s.effortName(item.effort!)}',
                    ),
                  if (item.durationSeconds != null)
                    _MiniDetailPill(
                      '⏱️ ${s.formatDuration(item.durationSeconds!)}',
                    ),
                  if (item.placeLabel != null &&
                      item.placeLabel!.trim().isNotEmpty)
                    _MiniDetailPill('📍 ${item.placeLabel!.trim()}'),
                  ...item.tags.map((t) => _MiniDetailPill(s.tagLabel(t))),
                ],
              ),
            ],
            if (item.note != null && item.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '“${item.note!.trim()}”',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: TronoColors.ink(context),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              ...kReactionEmojis.map((emoji) {
                final count = item.countForEmoji(emoji);
                final mine = item.hasReacted(emoji, currentUserId);
                return GestureDetector(
                  onTap: () => onReact(emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? TronoColors.terracotta.withValues(alpha: 0.16)
                          : TronoColors.bg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: mine
                            ? TronoColors.terracotta
                            : TronoColors.border(context),
                        width: mine ? 1.8 : 1.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: mine
                                  ? TronoColors.terracotta
                                  : TronoColors.ink(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: TronoColors.border(context).withValues(alpha: 0.75),
          ),
          const SizedBox(height: 6),
          InkWell(
            key: ValueKey('feed_comment_btn_${item.logId}'),
            onTap: onOpenComments,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.comments.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          item.comments.last.avatarEmoji,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${item.comments.last.displayName} ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: TronoColors.ink(context),
                                  ),
                                ),
                                TextSpan(
                                  text: item.comments.last.body,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: TronoColors.muted(context),
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: item.comments.isNotEmpty
                            ? TronoColors.terracotta
                            : TronoColors.muted(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.comments.isNotEmpty
                              ? s.viewCommentsCta(item.comments.length)
                              : s.addCommentCta,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: item.comments.isNotEmpty
                                ? TronoColors.terracotta
                                : TronoColors.muted(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: TronoColors.muted(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.social,
    required this.initialItem,
  });

  final SocialController social;
  final SharedFeedItem initialItem;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  SharedFeedItem _resolveItem() {
    for (final entry in widget.social.feed) {
      if (entry.logId == widget.initialItem.logId) {
        return entry;
      }
    }
    return widget.initialItem;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final raw = _inputCtrl.text;
    final clean = LogComment.validateBody(raw);
    if (clean == null) return;

    final s = AppStrings.of(context);
    setState(() => _submitting = true);
    _inputCtrl.clear();

    final ok = await widget.social.addComment(widget.initialItem.logId, clean);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      _inputCtrl.text = raw;
      _inputCtrl.selection = TextSelection.collapsed(offset: raw.length);
      showTronoToast(context, s.commentFailedToast);
    }
  }

  Future<void> _deleteComment(LogComment comment) async {
    final s = AppStrings.of(context);
    HapticFeedback.selectionClick();
    final ok = await widget.social.deleteComment(
      widget.initialItem.logId,
      comment.id,
    );
    if (!mounted) return;
    if (!ok) {
      showTronoToast(context, s.commentDeleteFailedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    final canSend =
        !_submitting && LogComment.validateBody(_inputCtrl.text) != null;

    return ListenableBuilder(
      listenable: widget.social,
      builder: (context, _) {
        final item = _resolveItem();
        final currentUid = widget.social.currentUserId;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: TronoColors.bg(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: TronoColors.border(context),
                width: 2,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: TronoColors.border(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TronoColors.terracotta.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.avatarEmoji,
                            style: const TextStyle(fontSize: 19),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: TronoColors.ink(context),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${item.type.emoji} ${s.typeName(item.type)} · ${s.relativeTime(item.timestamp)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TronoColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: TronoColors.surface(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: TronoColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '💬 ${item.comments.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.ink(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1.5,
                    color: TronoColors.border(context),
                  ),
                  if (item.comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 34,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            s.noCommentsYet,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: item.comments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final comment = item.comments[index];
                          final isMine =
                              currentUid != null &&
                              comment.userId == currentUid;

                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            decoration: BoxDecoration(
                              color: TronoColors.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: TronoColors.border(context),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: TronoColors.terracotta.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    comment.avatarEmoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              comment.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: TronoColors.ink(context),
                                              ),
                                            ),
                                          ),
                                          if (isMine) ...[
                                            const SizedBox(width: 5),
                                            Text(
                                              '(${s.youBadge})',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: TronoColors.muted(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 6),
                                          Text(
                                            s.relativeTime(comment.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: TronoColors.muted(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        comment.body,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: TronoColors.ink(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isMine)
                                  IconButton(
                                    key: ValueKey(
                                      'comment_delete_btn_${comment.id}',
                                    ),
                                    tooltip: s.deleteCommentTooltip,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteComment(comment),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: TronoColors.muted(context),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  Divider(
                    height: 1,
                    thickness: 1.5,
                    color: TronoColors.border(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('comment_input_field'),
                            controller: _inputCtrl,
                            maxLength: LogComment.maxBodyLength,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: s.commentInputHint,
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: TronoColors.surface(context),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: TronoColors.border(context),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: TronoColors.border(context),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: TronoColors.terracotta,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          key: const ValueKey('comment_send_btn'),
                          tooltip: s.commentSendTooltip,
                          style: IconButton.styleFrom(
                            backgroundColor: TronoColors.terracotta,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: TronoColors.border(
                              context,
                            ),
                            disabledForegroundColor: TronoColors.muted(context),
                            minimumSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: canSend ? _submit : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 19),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniDetailPill extends StatelessWidget {
  const _MiniDetailPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: TronoColors.border(context)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({
    required this.social,
    required this.initialSignUp,
  });

  final SocialController social;
  final bool initialSignUp;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  late bool _isSignUp;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _selectedEmoji = '👑';
  bool _submitting = false;
  bool _submittingGoogle = false;
  bool _autoClosed = false;
  String? _error;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
    widget.social.addListener(_onSocialChanged);
  }

  @override
  void dispose() {
    widget.social.removeListener(_onSocialChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onSocialChanged() {
    if (!mounted || _autoClosed) return;
    if (widget.social.isSignedIn) {
      _autoClosed = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitGoogle() async {
    final s = AppStrings.of(context);
    setState(() {
      _submittingGoogle = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final launched = await widget.social.signInWithGoogle();
      if (!mounted) return;
      if (widget.social.isSignedIn) {
        _autoClosed = true;
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _submittingGoogle = false;
        if (launched) {
          _infoMessage = s.googleAuthBrowserNotice;
        } else {
          _error = s.googleAuthLaunchError;
        }
      });
    } on GoogleSignInCancelledException {
      if (!mounted) return;
      setState(() => _submittingGoogle = false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingGoogle = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submittingGoogle = false;
        _error = s.googleAuthLaunchError;
      });
    }
  }

  Future<void> _submit() async {
    final s = AppStrings.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || !email.contains('@') || password.length < 6) {
      setState(() => _error = s.authGenericError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final outcome = _isSignUp
          ? await widget.social.signUp(
              email: email,
              password: password,
              displayName: name.isEmpty ? email.split('@').first : name,
              avatarEmoji: _selectedEmoji,
            )
          : await widget.social.signIn(
              email: email,
              password: password,
            );

      if (!mounted) return;
      if (outcome.status == AuthOutcomeStatus.needsEmailConfirmation) {
        setState(() {
          _submitting = false;
          _isSignUp = false;
          _infoMessage = s.confirmEmailNotice;
        });
      } else {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = s.authGenericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNav = bottomInset > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TronoColors.border(context), width: 2),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset + bottomNav),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: TronoColors.border(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(s.createAccountBtn)),
                  ButtonSegment(value: false, label: Text(s.signInBtn)),
                ],
                selected: {_isSignUp},
                onSelectionChanged: (set) => setState(() {
                  _isSignUp = set.first;
                  _error = null;
                }),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 18),

            // 1-tap Google OAuth button (works for both sign-up and sign-in)
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.surface(context),
              lipColor: TronoColors.lip(context),
              borderColor: TronoColors.border(context),
              onPressed: (_submitting || _submittingGoogle)
                  ? null
                  : _submitGoogle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_submittingGoogle)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: TronoColors.terracotta,
                      ),
                    )
                  else
                    const _GoogleGLogo(size: 18),
                  const SizedBox(width: 10),
                  Text(
                    s.continueWithGoogleBtn,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TronoColors.ink(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: TronoColors.border(context),
                    thickness: 1.2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    s.orWithEmailDivider,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TronoColors.muted(context),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: TronoColors.border(context),
                    thickness: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isSignUp) ...[
              Text(
                s.chooseAvatarLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: kAvatarEmojis.map((emoji) {
                    final active = emoji == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? TronoColors.terracotta.withValues(alpha: 0.16)
                              : TronoColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? TronoColors.terracotta
                                : TronoColors.border(context),
                            width: active ? 2.5 : 1.5,
                          ),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: s.displayNameLabel,
                  hintText: s.displayNameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: s.emailLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: s.passwordLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),

            if (_infoMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TronoColors.sage.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TronoColors.sage),
                ),
                child: Text(
                  _infoMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TronoColors.sage,
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: TronoColors.coral,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 18),
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.terracotta,
              lipColor: TronoColors.terracottaLip,
              onPressed: (_submitting || _submittingGoogle) ? null : _submit,
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp ? s.createAccountBtn : s.signInBtn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crisp vector Google "G" emblem rendered cleanly without external assets.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.2;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Red top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.55, 1.85, false, paint);
    // Yellow left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.38, false, paint);
    // Green bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.72, 1.65, false, paint);
    // Blue right arc + crossbar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.05, 0.82, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
