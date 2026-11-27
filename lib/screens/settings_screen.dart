import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/app_update.dart';
import '../models/bathroom_log.dart';
import '../models/reminder_schedule.dart';
import '../services/backup_service.dart';
import '../services/update_checker_service.dart';
import '../state/social_controller.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/trono_toast.dart';
import '../widgets/update_banner_card.dart';
import 'achievements_screen.dart';
import 'favorite_places_screen.dart';
import 'social_screen.dart';

Future<void> showSalaryConfigDialog(
  BuildContext context,
  TronoController controller,
) async {
  final s = AppStrings.of(context);
  bool monthlyMode = true;
  String currency = controller.currencySymbol;
  final initialMonthly =
      controller.hourlyRate != null ? (controller.hourlyRate! * 160).round() : null;
  final amountCtrl = TextEditingController(
    text: initialMonthly != null ? '$initialMonthly' : '',
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(s.salaryDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(s.salaryModeMonthly)),
                    ButtonSegment(value: false, label: Text(s.salaryModeHourly)),
                  ],
                  selected: {monthlyMode},
                  onSelectionChanged: (set) =>
                      setModalState(() => monthlyMode = set.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['€', r'$', '£'].map((sym) {
                    return ChoiceChip(
                      label: Text(sym),
                      selected: currency == sym,
                      onSelected: (_) => setModalState(() => currency = sym),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    hintText: monthlyMode ? s.salaryAmountHint : '15',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              if (controller.hasHourlyRate)
                TextButton(
                  onPressed: () async {
                    await controller.setSalaryConfig(
                      hourlyRate: null,
                      currencySymbol: currency,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop(false);
                  },
                  child: Text(
                    s.clearSalaryButton,
                    style: const TextStyle(color: TronoColors.coral),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(s.cancelTimer),
              ),
              FilledButton(
                onPressed: () async {
                  final raw = double.tryParse(
                    amountCtrl.text.trim().replaceAll(',', '.'),
                  );
                  if (raw == null || raw <= 0) return;
                  final hourly = monthlyMode ? raw / 160.0 : raw;
                  await controller.setSalaryConfig(
                    hourlyRate: hourly,
                    currencySymbol: currency,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                },
                child: Text(s.saveButton),
              ),
            ],
          );
        },
      );
    },
  );
  amountCtrl.dispose();

  if (saved == true && context.mounted) {
    showTronoToast(context, s.salarySavedToast);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.social,
  });

  final TronoController controller;
  final SocialController social;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localAuth = LocalAuthentication();
  bool _biometricsSupported = false;
  bool _capturingHome = false;

  Future<void> _handleSetHome() async {
    final s = AppStrings.of(context);
    setState(() => _capturingHome = true);
    final ok = await widget.controller.captureCurrentAsHome();
    if (!mounted) return;
    setState(() => _capturingHome = false);
    showTronoToast(
      context,
      ok ? s.homeSavedToast : s.gpsUnavailableToast,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (mounted) setState(() => _biometricsSupported = supported);
    } catch (_) {}
  }

  Future<void> _showSetPinDialog() async {
    final s = AppStrings.of(context);
    final pinCtrl = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.enterNewPin),
        content: TextField(
          controller: pinCtrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '••••',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancelTimer),
          ),
          FilledButton(
            onPressed: () {
              if (pinCtrl.text.length == 4) {
                Navigator.of(ctx).pop(pinCtrl.text);
              }
            },
            child: Text(s.saveButton),
          ),
        ],
      ),
    );
    pinCtrl.dispose();

    if (saved != null && saved.length == 4) {
      await widget.controller.setPin(saved);
      if (mounted) {
        showTronoToast(context, s.pinSavedToast);
      }
    }
  }

  Future<void> _handleImport() async {
    final s = AppStrings.of(context);
    try {
      final logs = await BackupService.pickAndParseBackup();
      if (logs == null) return;
      final count = await widget.controller.importLogs(logs);
      if (mounted) {
        showTronoToast(context, s.importedCountToast(count));
      }
    } catch (_) {
      if (mounted) {
        showTronoToast(context, s.importFailedToast);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final ctrl = widget.controller;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                title: Text(s.settingsTitle),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                sliver: SliverList.list(
                  children: [
              _SectionTitle(s.accountCloudSection),
              ListenableBuilder(
                listenable: widget.social,
                builder: (context, _) {
                  final social = widget.social;
                  if (!social.isSignedIn) {
                    return ChunkyCard(
                      color: TronoColors.obsidian,
                      borderColor: const Color(0xFF343B4D),
                      lipColor: TronoColors.obsidianLip,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ColorIcon(Icons.cloud_done_rounded, TronoColors.gold),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.cloudConnectTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.cloudConnectBody,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.72),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ChunkyButton(
                                  color: TronoColors.terracotta,
                                  lipColor: TronoColors.terracottaLip,
                                  lipHeight: 4,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
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
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ChunkyButton(
                                color: const Color(0xFF2B3140),
                                lipColor: TronoColors.obsidianLip,
                                borderColor: const Color(0xFF3E465B),
                                lipHeight: 4,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                onPressed: () => showAuthSheet(
                                  context,
                                  social,
                                  initialSignUp: false,
                                ),
                                child: Text(
                                  s.signInBtn,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final profile = social.myProfile;
                  return ChunkyCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TronoColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(
                              profile?.avatarEmoji ?? '👑',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            profile?.displayName ?? (social.currentEmail ?? 'Trono'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            social.isSyncing
                                ? s.syncingLabel
                                : social.pendingSyncCount > 0
                                    ? s.pendingSyncLabel(social.pendingSyncCount)
                                    : '${social.currentEmail ?? ''} · ${s.allSyncedLabel}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.edit_rounded, size: 19),
                          onTap: () => showEditProfileDialog(context, social),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _ColorIcon(
                            Icons.sync_rounded,
                            TronoColors.sage,
                          ),
                          title: Text(
                            s.syncNowBtn,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          trailing: social.isSyncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: social.isSyncing
                              ? null
                              : () async {
                                  final report = await social.syncNow(
                                    refreshFeedAfter: true,
                                  );
                                  if (!context.mounted) return;
                                  showTronoToast(
                                    context,
                                    s.syncedToast(
                                      report.pushedCount,
                                      report.pulledCount,
                                    ),
                                  );
                                },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _ColorIcon(
                            Icons.logout_rounded,
                            TronoColors.coral,
                          ),
                          title: Text(
                            s.signOutBtn,
                            style: const TextStyle(
                              color: TronoColors.coral,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(s.signOutBtn),
                                content: Text(s.signOutConfirmBody),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(s.cancelTimer),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: TronoColors.coral,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(s.signOutBtn),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await social.signOut();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              ChunkyCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: _ColorIcon(
                    Icons.emoji_events_rounded,
                    TronoColors.gold,
                  ),
                  title: Text(
                    s.achievementsTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${ctrl.gamification.currentRank.emoji} ${s.rankName(ctrl.gamification.currentRank.id)} · ${ctrl.gamification.totalXp} XP · ${ctrl.gamification.unlockedCount}/${ctrl.gamification.achievements.length}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AchievementsScreen(controller: ctrl),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.appearanceSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.languageLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'en', label: Text('English')),
                                ButtonSegment(value: 'es', label: Text('Español')),
                              ],
                              selected: {ctrl.locale.languageCode},
                              onSelectionChanged: (set) =>
                                  ctrl.setLocale(Locale(set.first)),
                              showSelectedIcon: false,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.themeLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text(s.themeSystem),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text(s.themeLight),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text(s.themeDark),
                                ),
                              ],
                              selected: {ctrl.themeMode},
                              onSelectionChanged: (set) =>
                                  ctrl.setThemeMode(set.first),
                              showSelectedIcon: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: _ColorIcon(
                          Icons.waving_hand_rounded,
                          TronoColors.gold,
                        ),
                        title: Text(
                          s.replayWelcomeLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(s.replayWelcomeSub),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await ctrl.resetOnboarding();
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.remindersSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      key: const ValueKey('streak_reminder_switch'),
                      secondary: const _ColorIcon(
                        Icons.local_fire_department_rounded,
                        TronoColors.terracotta,
                      ),
                      title: Text(
                        s.streakReminderLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        s.streakReminderSub(ctrl.streakReminderHour),
                      ),
                      value: ctrl.streakReminderEnabled,
                      onChanged: (enabled) async {
                        final ok = await ctrl.setStreakReminderEnabled(enabled);
                        if (!ok && context.mounted) {
                          showTronoToast(
                            context,
                            s.reminderPermissionDeniedToast,
                          );
                        }
                      },
                    ),
                    if (ctrl.streakReminderEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.reminderTimeLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: TronoColors.muted(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ReminderConfig.selectableStreakHours
                                  .map((hour) {
                                    final label =
                                        '${hour.toString().padLeft(2, '0')}:00';
                                    return ChoiceChip(
                                      key: ValueKey('streak_hour_chip_$hour'),
                                      label: Text(label),
                                      selected: ctrl.streakReminderHour == hour,
                                      onSelected: (_) =>
                                          ctrl.setStreakReminderHour(hour),
                                    );
                                  })
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const ValueKey('weekly_recap_switch'),
                      secondary: const _ColorIcon(
                        Icons.auto_awesome_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.weeklyRecapReminderLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.weeklyRecapReminderSub),
                      value: ctrl.weeklyRecapReminderEnabled,
                      onChanged: (enabled) async {
                        final ok = await ctrl.setWeeklyRecapReminderEnabled(
                          enabled,
                        );
                        if (!ok && context.mounted) {
                          showTronoToast(
                            context,
                            s.reminderPermissionDeniedToast,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.socialNotificationsSection),
              ListenableBuilder(
                listenable: widget.social,
                builder: (context, _) {
                  final prefs = widget.social.socialNotificationPrefs;
                  return ChunkyCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const ValueKey('push_friend_thrones_switch'),
                          secondary: const _ColorIcon(
                            Icons.workspace_premium_rounded,
                            TronoColors.terracotta,
                          ),
                          title: Text(
                            s.pushFriendThronesLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(s.pushFriendThronesSub),
                          value: prefs.friendThrones,
                          onChanged: (v) =>
                              widget.social.setSocialNotificationPrefs(
                                prefs.copyWith(friendThrones: v),
                              ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          key: const ValueKey('push_friend_comments_switch'),
                          secondary: const _ColorIcon(
                            Icons.chat_bubble_rounded,
                            TronoColors.sage,
                          ),
                          title: Text(
                            s.pushFriendCommentsLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(s.pushFriendCommentsSub),
                          value: prefs.friendComments,
                          onChanged: (v) =>
                              widget.social.setSocialNotificationPrefs(
                                prefs.copyWith(friendComments: v),
                              ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          key: const ValueKey('push_friend_reactions_switch'),
                          secondary: const _ColorIcon(
                            Icons.local_fire_department_rounded,
                            TronoColors.gold,
                          ),
                          title: Text(
                            s.pushFriendReactionsLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(s.pushFriendReactionsSub),
                          value: prefs.friendReactions,
                          onChanged: (v) =>
                              widget.social.setSocialNotificationPrefs(
                                prefs.copyWith(friendReactions: v),
                              ),
                        ),
                        const Divider(height: 1),
                        Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            key: const ValueKey(
                              'open_android_notif_settings_tile',
                            ),
                            leading: const _ColorIcon(
                              Icons.tune_rounded,
                              TronoColors.obsidian,
                            ),
                            title: Text(
                              s.androidNotifSettingsLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(s.androidNotifSettingsSub),
                            trailing: const Icon(Icons.open_in_new_rounded),
                            onTap: () =>
                                widget.social.openSystemNotificationSettings(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.locationSettingsSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        s.autoGpsLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.autoGpsSub),
                      value: ctrl.autoGpsEnabled,
                      onChanged: ctrl.setAutoGpsEnabled,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.home_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.setHomeLocationLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        ctrl.hasHomeLocation
                            ? s.homeConfiguredSub
                            : s.homeNotSetSub,
                      ),
                      trailing: _capturingHome
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ctrl.hasHomeLocation
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: TronoColors.sage,
                                  size: 22,
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                      onTap: _capturingHome ? null : _handleSetHome,
                    ),
                    if (ctrl.hasHomeLocation) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: _ColorIcon(
                          Icons.location_off_rounded,
                          TronoColors.coral,
                        ),
                        title: Text(
                          s.clearHomeLabel,
                          style: const TextStyle(
                            color: TronoColors.coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: ctrl.clearHomeLocation,
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.star_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.favoritePlacesMenuTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        s.favoritePlacesMenuSub(ctrl.favoritePlaces.length),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FavoritePlacesScreen(controller: ctrl),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.salarySettingsSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: _ColorIcon(
                    Icons.payments_rounded,
                    TronoColors.gold,
                  ),
                  title: Text(
                    s.salarySettingsLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    ctrl.hasHourlyRate
                        ? s.salaryConfiguredSub(
                            ctrl.currencySymbol,
                            ctrl.hourlyRate!,
                          )
                        : s.salaryNotSetSub,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showSalaryConfigDialog(context, ctrl),
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.securitySection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        s.appLockLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.appLockSubtitle),
                      value: ctrl.lockEnabled,
                      onChanged: (enabled) async {
                        if (enabled && !ctrl.hasPin && !_biometricsSupported) {
                          await _showSetPinDialog();
                          if (!ctrl.hasPin) return;
                        }
                        await ctrl.setLockEnabled(enabled);
                      },
                    ),
                    if (ctrl.lockEnabled) ...[
                      const Divider(height: 1),
                      if (_biometricsSupported)
                        SwitchListTile(
                          title: Text(s.biometricLabel),
                          value: ctrl.biometricEnabled,
                          onChanged: ctrl.setBiometricEnabled,
                        ),
                      ListTile(
                        leading: _ColorIcon(
                          Icons.pin_rounded,
                          TronoColors.terracotta,
                        ),
                        title: Text(
                          s.setPinLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: ctrl.hasPin
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: TronoColors.sage,
                                size: 22,
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _showSetPinDialog,
                      ),
                      if (ctrl.hasPin && _biometricsSupported)
                        ListTile(
                          leading: _ColorIcon(
                            Icons.lock_open_rounded,
                            TronoColors.coral,
                          ),
                          title: Text(
                            s.removePinLabel,
                            style: const TextStyle(
                              color: TronoColors.coral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: ctrl.clearPin,
                        ),
                    ],
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.defaultPrivacyLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ShareLevel.selectableValues.map((lvl) {
                              return ChoiceChip(
                                label: Text(s.shareLevelName(lvl)),
                                selected:
                                    ctrl.defaultShareLevel.normalizedForUi ==
                                    lvl,
                                onSelected: (_) =>
                                    ctrl.setDefaultShareLevel(lvl),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.backupSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: _ColorIcon(
                        Icons.data_object_rounded,
                        TronoColors.terracotta,
                      ),
                      title: Text(
                        s.exportJsonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.exportJsonSub),
                      trailing: const Icon(Icons.ios_share_rounded, size: 20),
                      onTap: () => BackupService.exportJson(ctrl.logs),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.table_chart_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.exportCsvLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.exportCsvSub),
                      trailing: const Icon(Icons.ios_share_rounded, size: 20),
                      onTap: () => BackupService.exportCsv(ctrl.logs),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.file_upload_rounded,
                        TronoColors.obsidian,
                      ),
                      title: Text(
                        s.importBackupLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.importBackupSub),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _handleImport,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.widgetSection),
              ChunkyCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ColorIcon(Icons.widgets_rounded, TronoColors.terracotta),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.widgetGuideBody,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.updatesSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (ctrl.availableUpdate != null) ...[
                      ListTile(
                        leading: _ColorIcon(
                          Icons.system_update_rounded,
                          TronoColors.terracotta,
                        ),
                        title: Text(
                          s.updateAvailableTitle(ctrl.availableUpdate!.tagName),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          ReleaseNotesFormatter.extractLines(
                            ctrl.availableUpdate!.releaseNotes,
                          ).isNotEmpty
                              ? '${s.updateAvailableSub} · ${s.updateWhatsNewBtn}'
                              : s.updateAvailableSub,
                        ),
                        onTap: () {
                          final release = ctrl.availableUpdate!;
                          final hasNotes = ReleaseNotesFormatter.extractLines(
                            release.releaseNotes,
                          ).isNotEmpty;
                          if (hasNotes) {
                            showReleaseNotesSheet(
                              context,
                              release: release,
                              onDownload: () async {
                                final ok =
                                    await UpdateCheckerService.openDownload(
                                  release,
                                );
                                if (!ok && context.mounted) {
                                  showTronoToast(
                                    context,
                                    s.updateOpenFailedToast,
                                  );
                                }
                              },
                            );
                          }
                        },
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TronoColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () async {
                            final ok = await UpdateCheckerService.openDownload(
                              ctrl.availableUpdate!,
                            );
                            if (!ok && context.mounted) {
                              showTronoToast(context, s.updateOpenFailedToast);
                            }
                          },
                          child: Text(
                            s.updateDownloadBtn,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: _ColorIcon(
                        Icons.refresh_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.checkUpdatesLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        s.installedVersionSub(ctrl.installedVersion),
                      ),
                      trailing: ctrl.isCheckingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: ctrl.isCheckingUpdate
                          ? null
                          : () async {
                              final res = await ctrl.checkForUpdates(
                                force: true,
                              );
                              if (!context.mounted) return;
                              switch (res.status) {
                                case UpdateCheckStatus.updateAvailable:
                                  showTronoToast(
                                    context,
                                    s.updateAvailableTitle(
                                      res.release!.tagName,
                                    ),
                                  );
                                case UpdateCheckStatus.upToDate:
                                  showTronoToast(context, s.upToDateToast);
                                case UpdateCheckStatus.failed:
                                  showTronoToast(
                                    context,
                                    s.updateCheckFailedToast,
                                  );
                                case UpdateCheckStatus.throttled:
                                  break;
                              }
                            },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const ValueKey('settings_changelog_tile'),
                      leading: _ColorIcon(
                        Icons.auto_awesome_rounded,
                        TronoColors.terracotta,
                      ),
                      title: Text(
                        s.changelogMenuTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('v${ctrl.installedVersion}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final release = await ctrl.fetchInstalledReleaseNotes();
                        if (!context.mounted) return;
                        if (release != null &&
                            ReleaseNotesFormatter.extractLines(
                              release.releaseNotes,
                            ).isNotEmpty) {
                          await showReleaseNotesSheet(
                            context,
                            release: release,
                          );
                        } else {
                          showTronoToast(context, s.changelogUnavailableToast);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
          ),
        );
      },
    );
  }
}

class _ColorIcon extends StatelessWidget {
  const _ColorIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = (color == TronoColors.obsidian && isDark)
        ? TronoColors.darkInk
        : color;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 21),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: TronoColors.muted(context),
        ),
      ),
    );
  }
}
