import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/social_models.dart';
import '../services/supabase_sync_service.dart';
import '../state/social_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/trono_toast.dart';

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
  const SocialScreen({super.key, required this.social});

  final SocialController social;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _subTab = 0; // 0 = Live Feed, 1 = Leaderboard

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.social,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final social = widget.social;

        if (!social.isSignedIn) {
          return _SignedOutView(social: social);
        }

        final activeGroup = social.selectedGroup;

        return RefreshIndicator(
          color: TronoColors.terracotta,
          onRefresh: social.syncAndRefreshSocial,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                title: Text(s.socialTitle),
                actions: [
                  if (social.myProfile != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => showEditProfileDialog(context, social),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                              Text(
                                social.myProfile!.avatarEmoji,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 96),
                                child: Text(
                                  social.myProfile!.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: TronoColors.ink(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: s.syncNowBtn,
                    onPressed: social.isSyncing
                        ? null
                        : () => social.syncAndRefreshSocial(),
                    icon: social.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: TronoColors.terracotta,
                            ),
                          )
                        : Icon(
                            social.pendingSyncCount > 0
                                ? Icons.cloud_upload_rounded
                                : Icons.cloud_done_rounded,
                            color: social.pendingSyncCount > 0
                                ? TronoColors.gold
                                : TronoColors.sage,
                          ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                sliver: SliverList.list(
                  children: [
                    // Group Selector Strip
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...social.groups.map((g) {
                            final selected = g.id == activeGroup?.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => social.selectGroup(g.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? TronoColors.terracotta
                                        : TronoColors.surface(context),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? TronoColors.terracottaLip
                                          : TronoColors.border(context),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        g.emoji,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        g.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: selected
                                              ? Colors.white
                                              : TronoColors.ink(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          _SmallActionPill(
                            icon: Icons.add_rounded,
                            label: s.createGroupBtn,
                            onTap: _showCreateGroupDialog,
                          ),
                          const SizedBox(width: 8),
                          _SmallActionPill(
                            icon: Icons.tag_rounded,
                            label: s.joinGroupBtn,
                            onTap: _showJoinGroupDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (social.isLoadingSocial && social.groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: TronoColors.terracotta,
                          ),
                        ),
                      )
                    else if (activeGroup == null)
                      _NoGroupsCard(
                        onCreate: _showCreateGroupDialog,
                        onJoin: _showJoinGroupDialog,
                      )
                    else ...[
                      _ActiveGroupHeaderCard(
                        group: activeGroup,
                        currentUserId: social.currentUserId,
                        onLeave: () => _confirmLeaveGroup(activeGroup),
                      ),
                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          segments: [
                            ButtonSegment(
                              value: 0,
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: Text(s.socialTabFeed),
                            ),
                            ButtonSegment(
                              value: 1,
                              icon: const Icon(
                                Icons.leaderboard_rounded,
                                size: 18,
                              ),
                              label: Text(s.socialTabRanking),
                            ),
                          ],
                          selected: {_subTab},
                          onSelectionChanged: (set) =>
                              setState(() => _subTab = set.first),
                          showSelectedIcon: false,
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_subTab == 0)
                        ..._buildFeedWidgets(context, social)
                      else
                        ..._buildLeaderboardWidgets(context, social),
                    ],
                  ],
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
  ) {
    final s = AppStrings.of(context);
    if (social.feed.isEmpty) {
      return [
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
      ];
    }

    return social.feed.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _FeedItemCard(
          item: item,
          currentUserId: social.currentUserId,
          onReact: (emoji) {
            HapticFeedback.selectionClick();
            social.toggleReaction(item.logId, emoji);
          },
        ),
      );
    }).toList();
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
  const _SignedOutView({required this.social});

  final SocialController social;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(s.socialTitle),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          sliver: SliverList.list(
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
        ),
      ],
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

class _ActiveGroupHeaderCard extends StatelessWidget {
  const _ActiveGroupHeaderCard({
    required this.group,
    required this.currentUserId,
    required this.onLeave,
  });

  final SocialGroup group;
  final String? currentUserId;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ChunkyCard(
      color: TronoColors.obsidian,
      borderColor: const Color(0xFF343B4D),
      lipColor: TronoColors.obsidianLip,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TronoColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(group.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      s.membersCountLabel(group.memberCount),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                onSelected: (val) {
                  if (val == 'leave') onLeave();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'leave',
                    child: Text(
                      s.leaveGroupBtn,
                      style: const TextStyle(
                        color: TronoColors.coral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (group.members.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: group.members.map((m) {
                final isMe = m.userId == currentUserId;
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
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
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.inviteCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: TronoColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: group.inviteCode),
                    );
                    if (!context.mounted) return;
                    showTronoToast(context, s.codeCopiedToast);
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    s.copyCodeBtn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
                          group.name,
                          group.inviteCode,
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
          ),
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
  });

  final SharedFeedItem item;
  final String? currentUserId;
  final ValueChanged<String> onReact;

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
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '👥 ${s.summaryOnlyBadge}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: TronoColors.muted(context),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: kReactionEmojis.map((emoji) {
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
            }).toList(),
          ),
        ],
      ),
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

class _SmallActionPill extends StatelessWidget {
  const _SmallActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: TronoColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TronoColors.border(context), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: TronoColors.terracotta),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: TronoColors.ink(context),
              ),
            ),
          ],
        ),
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
  String? _error;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TronoColors.border(context), width: 2),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
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
              onPressed: _submitting ? null : _submit,
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
