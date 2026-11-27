import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/insights.dart';
import '../services/update_checker_service.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/achievement_unlock_dialog.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/log_detail_sheet.dart';
import '../widgets/log_tile.dart';
import '../widgets/trono_toast.dart';
import '../widgets/update_banner_card.dart';

/// Formats the instant quick-log toast, appending live paid-on-the-throne
/// earnings (`💰 +€X.XX` or `💰 ~€X.XX`) whenever the visit is at Work or WFH
/// and the user has configured an hourly rate.
String formatQuickLogToast({
  required String baseMessage,
  required BathroomLog log,
  required double? hourlyRate,
  required String currencySymbol,
}) {
  final earnings = InsightsEngine.calculateLogEarnings(
    log,
    hourlyRate: hourlyRate,
  );
  if (earnings == null || earnings.amount <= 0) return baseMessage;
  final sign = earnings.isEstimated ? '~' : '+';
  final formatted = '$sign$currencySymbol${earnings.amount.toStringAsFixed(2)}';
  if (baseMessage.endsWith(')')) {
    return '${baseMessage.substring(0, baseMessage.length - 1)} · 💰 $formatted)';
  }
  return '$baseMessage · 💰 $formatted';
}

enum _QuickLocationMode { auto, home, wfh, work, away }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onOpenSettings,
    this.onOpenAwards,
  });

  final TronoController controller;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAwards;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _QuickLocationMode _locationMode = _QuickLocationMode.auto;

  TronoController get controller => widget.controller;

  LocationKind? get _selectedLocationKind => switch (_locationMode) {
    _QuickLocationMode.auto => null,
    _QuickLocationMode.home => LocationKind.home,
    _QuickLocationMode.wfh => LocationKind.home,
    _QuickLocationMode.work => LocationKind.work,
    _QuickLocationMode.away => LocationKind.away,
  };

  List<String> get _selectedInitialTags =>
      _locationMode == _QuickLocationMode.wfh
          ? const [BathroomLog.wfhTag]
          : const [];

  Future<void> _handleQuickTap(
    BuildContext context,
    BathroomType type, {
    LocationKind? locationKind,
    List<String> tags = const [],
    Duration sheetDelay = Duration.zero,
  }) async {
    HapticFeedback.mediumImpact();
    final s = AppStrings.of(context);
    final (savedLog, initialUnlocks) = await controller.quickLog(
      type,
      locationKind: locationKind,
      tags: tags,
    );

    if (!context.mounted) return;
    final prefix = tags.contains(BathroomLog.wfhTag)
        ? '💻 '
        : (locationKind != null ? '${locationKind.emoji} ' : '${type.emoji} ');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (sheetDelay > Duration.zero) {
      await Future<void>.delayed(sheetDelay);
      if (!context.mounted) return;
    }

    final result = await showLogDetailSheet(
      context,
      mode: LogSheetMode.quickFollowUp,
      initialLog: savedLog,
      defaultShareLevel: controller.defaultShareLevel,
      favoritePlaces: controller.favoritePlaces,
    );

    if (result?.deleted == true) {
      await controller.deleteLog(savedLog.id);
      if (context.mounted) {
        showTronoToastOnMessenger(
          messenger,
          s.undoneToast,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    UnlockEvent combinedUnlocks = initialUnlocks;
    if (result?.savedLog != null) {
      final followUpUnlocks = await controller.saveLog(result!.savedLog!);
      combinedUnlocks = UnlockEvent(
        newAchievements: [
          ...initialUnlocks.newAchievements,
          ...followUpUnlocks.newAchievements,
        ],
        newRank: followUpUnlocks.newRank ?? initialUnlocks.newRank,
      );
      if (context.mounted) {
        final finalLog = result.savedLog!;
        showTronoToastOnMessenger(
          messenger,
          formatQuickLogToast(
            baseMessage: s.detailsSavedToast,
            log: finalLog,
            hourlyRate: controller.hourlyRate,
            currencySymbol: controller.currencySymbol,
          ),
          duration: const Duration(seconds: 2),
        );
      }
    } else if (context.mounted) {
      // User skipped/dismissed the detail sheet — show crisp toast with Undo!
      showTronoToastOnMessenger(
        messenger,
        formatQuickLogToast(
          baseMessage: '$prefix${s.savedInstantToast}',
          log: savedLog,
          hourlyRate: controller.hourlyRate,
          currencySymbol: controller.currencySymbol,
        ),
        actionLabel: s.undoAction,
        onAction: () async {
          await controller.deleteLog(savedLog.id);
          showTronoToastOnMessenger(
            messenger,
            s.undoneToast,
            duration: const Duration(seconds: 2),
          );
        },
      );
    }

    if (context.mounted && combinedUnlocks.hasAnything) {
      await showUnlockCelebrationIfNeeded(context, combinedUnlocks);
    }
  }

  Future<void> _handleAddPast(BuildContext context) async {
    final s = AppStrings.of(context);
    final result = await showLogDetailSheet(
      context,
      mode: LogSheetMode.createPast,
      defaultShareLevel: controller.defaultShareLevel,
      favoritePlaces: controller.favoritePlaces,
    );
    if (result?.savedLog == null) return;
    final unlocks = await controller.saveLog(result!.savedLog!);
    if (!context.mounted) return;
    showTronoToast(context, s.savedInstantToast);
    if (unlocks.hasAnything) {
      await showUnlockCelebrationIfNeeded(context, unlocks);
    }
  }

  Future<void> _handleEditLog(BuildContext context, BathroomLog log) async {
    final s = AppStrings.of(context);
    final result = await showLogDetailSheet(
      context,
      mode: LogSheetMode.editExisting,
      initialLog: log,
      defaultShareLevel: controller.defaultShareLevel,
      favoritePlaces: controller.favoritePlaces,
    );
    if (result == null) return;
    if (result.deleted) {
      await controller.deleteLog(log.id);
      if (context.mounted) {
        showTronoToast(context, s.logDeletedToast);
      }
    } else if (result.savedLog != null) {
      final unlocks = await controller.saveLog(result.savedLog!);
      if (context.mounted) {
        showTronoToast(context, s.detailsSavedToast);
        if (unlocks.hasAnything) {
          await showUnlockCelebrationIfNeeded(context, unlocks);
        }
      }
    }
  }

  Future<void> _handleDeleteWithUndo(
    BuildContext context,
    BathroomLog log,
  ) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await controller.deleteLog(log.id);
    if (!context.mounted) return;
    showTronoToastOnMessenger(
      messenger,
      s.logDeletedToast,
      actionLabel: s.undoAction,
      onAction: () => controller.saveLog(log),
    );
  }

  Future<void> _showLocationModeSheet(BuildContext context, AppStrings s) async {
    final picked = await showModalBottomSheet<_QuickLocationMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: TronoColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        final options = <({
          _QuickLocationMode mode,
          ValueKey<String> key,
          IconData icon,
          Color color,
          String title,
          String subtitle,
        })>[
          (
            mode: _QuickLocationMode.auto,
            key: const ValueKey('quick_loc_auto'),
            icon: Icons.my_location_rounded,
            color: TronoColors.terracotta,
            title: s.locationAutoTitle,
            subtitle: s.locationAutoSub,
          ),
          (
            mode: _QuickLocationMode.home,
            key: const ValueKey('quick_loc_home'),
            icon: Icons.home_rounded,
            color: TronoColors.goldLip,
            title: s.quickHomeButton,
            subtitle: s.locationHomeSub,
          ),
          (
            mode: _QuickLocationMode.wfh,
            key: const ValueKey('quick_loc_wfh'),
            icon: Icons.laptop_mac_rounded,
            color: TronoColors.sage,
            title: s.wfhLocationName,
            subtitle: s.locationWfhSub,
          ),
          (
            mode: _QuickLocationMode.work,
            key: const ValueKey('quick_loc_work'),
            icon: Icons.work_rounded,
            color: Theme.of(sheetCtx).brightness == Brightness.dark
                ? TronoColors.darkInk
                : TronoColors.obsidian,
            title: s.quickWorkButton,
            subtitle: s.locationWorkSub,
          ),
          (
            mode: _QuickLocationMode.away,
            key: const ValueKey('quick_loc_away'),
            icon: Icons.public_rounded,
            color: TronoColors.terracotta,
            title: s.quickAwayButton,
            subtitle: s.locationAwaySub,
          ),
        ];

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.locationField,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: TronoColors.ink(sheetCtx),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final active = opt.mode == _locationMode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      key: opt.key,
                      color: active
                          ? TronoColors.terracotta.withValues(alpha: 0.12)
                          : TronoColors.bg(sheetCtx),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: active
                              ? TronoColors.terracotta
                              : TronoColors.border(sheetCtx),
                          width: active ? 2 : 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(sheetCtx).pop(opt.mode);
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: opt.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(opt.icon, color: opt.color, size: 21),
                        ),
                        title: Text(
                          opt.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: TronoColors.ink(sheetCtx),
                          ),
                        ),
                        subtitle: Text(
                          opt.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TronoColors.muted(sheetCtx),
                          ),
                        ),
                        trailing: active
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: TronoColors.terracotta,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _locationMode = picked);
    }
  }

  String _formatClock(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final stats = controller.stats;
    final gam = controller.gamification;
    final todayLogs = controller.logsForDay(DateTime.now());
    final recentLogs = todayLogs.isNotEmpty
        ? todayLogs
        : controller.logs.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final heroSub = switch (_locationMode) {
      _QuickLocationMode.auto => s.oneTapHint,
      _QuickLocationMode.home => '🏠 ${s.locationKindName(LocationKind.home)} · ${s.oneTapHint}',
      _QuickLocationMode.wfh => '💻 ${s.wfhLocationName} · ${s.oneTapHint}',
      _QuickLocationMode.work => '💼 ${s.locationKindName(LocationKind.work)} · ${s.oneTapHint}',
      _QuickLocationMode.away => '🌍 ${s.locationKindName(LocationKind.away)} · ${s.oneTapHint}',
    };

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 60,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.appName,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: TronoColors.ink(context),
                ),
              ),
              const SizedBox(width: 7),
              _TronoBrandMark(
                key: const ValueKey('home_brand_mark'),
                size: 27,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ],
          ),
          actions: [
            ChunkyHudPill(
              icon: Icons.local_fire_department_rounded,
              iconColor: TronoColors.terracotta,
              label: '${stats.currentStreak}',
            ),
            const SizedBox(width: 8),
            ChunkyHudPill(
              icon: Icons.bolt_rounded,
              iconColor: TronoColors.gold,
              label: '${gam.totalXp}',
              onTap: widget.onOpenAwards,
            ),
            if (widget.onOpenSettings != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: s.navSettings,
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ] else
              const SizedBox(width: 16),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          sliver: SliverList.list(
            children: [
              if (controller.showHomeUpdateBanner &&
                  controller.availableUpdate != null) ...[
                UpdateBannerCard(
                  release: controller.availableUpdate!,
                  onDownload: () async {
                    final ok = await UpdateCheckerService.openDownload(
                      controller.availableUpdate!,
                    );
                    if (!ok && context.mounted) {
                      showTronoToast(context, s.updateOpenFailedToast);
                    }
                  },
                  onDismiss: controller.dismissUpdateBanner,
                ),
                const SizedBox(height: 16),
              ],
              // Clean Bold Numbers Strip (Today + 7d Avg)
              ChunkyCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.todayCountLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: TronoColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stats.todayPoop}',
                            style: const TextStyle(
                              fontSize: 38,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.terracotta,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 46,
                      color: TronoColors.border(context),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.dailyAvgLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: TronoColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stats.weeklyAvg.avgPoopPerDay.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 38,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.ink(context),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onOpenAwards,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TronoColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'NV.${gam.currentRank.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? TronoColors.gold
                                : TronoColors.goldLip,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Clean Single-Pill Location Selector (opens full-label bottom sheet)
              _LocationPickerPill(
                key: const ValueKey('home_location_picker_btn'),
                selected: _locationMode,
                hasSalary: controller.hasHourlyRate,
                onTap: () => _showLocationModeSheet(context, s),
              ),
              const SizedBox(height: 16),

              // THE DUAL-MODE 3D HERO BUTTON (Instant Claim OR Active Live Session Timer)
              if (controller.isTimerRunning) ...[
                _LiveTimerHeroButton(
                  key: const ValueKey('home_hero_timer_btn'),
                  clockText: _formatClock(controller.elapsedTimerSeconds),
                  subtitle: s.timerFinishSubtitle,
                  liveEarningsText: (controller.hasHourlyRate &&
                          (_locationMode == _QuickLocationMode.wfh ||
                              _locationMode == _QuickLocationMode.work))
                      ? '💰 +${controller.currencySymbol}${((controller.elapsedTimerSeconds / 3600.0) * controller.hourlyRate!).toStringAsFixed(2)}'
                      : null,
                  onFinishTap: () => _handleQuickTap(
                    context,
                    BathroomType.poop,
                    locationKind: _selectedLocationKind,
                    tags: _selectedInitialTags,
                    sheetDelay: const Duration(milliseconds: 200),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('home_cancel_timer_btn'),
                    onPressed: controller.cancelTimer,
                    style: TextButton.styleFrom(
                      foregroundColor: TronoColors.muted(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: Text(
                      s.cancelTimerFull,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                _AnimatedHeroLogButton(
                  title: s.heroLogTitle.toUpperCase(),
                  successTitle: s.heroLoggedFlash.toUpperCase(),
                  subtitle: heroSub,
                  onConfirmedTap: () => _handleQuickTap(
                    context,
                    BathroomType.poop,
                    locationKind: _selectedLocationKind,
                    tags: _selectedInitialTags,
                    sheetDelay: const Duration(milliseconds: 360),
                  ),
                ),
                const SizedBox(height: 14),
                ChunkyButton(
                  key: const ValueKey('home_start_timer_btn'),
                  width: double.infinity,
                  color: TronoColors.surface(context),
                  lipColor: TronoColors.lip(context),
                  borderColor: TronoColors.border(context),
                  lipHeight: 3,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    controller.startTimer();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 19,
                        color: TronoColors.terracotta,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.startTimer,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.ink(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),

              // Today / Recent History Header + discreet "+ Past" shortcut
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (todayLogs.isNotEmpty ? s.todayHistory : s.recentHistory)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('home_add_past_btn'),
                    onPressed: () => _handleAddPast(context),
                    style: TextButton.styleFrom(
                      foregroundColor: TronoColors.terracotta,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      s.addPastShortBtn,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (recentLogs.isEmpty)
                ChunkyCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: TronoColors.terracotta.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.touch_app_rounded,
                          color: TronoColors.terracotta,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.noLogsYetTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.noLogsYetBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TronoColors.muted(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...recentLogs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LogTile(
                      key: ValueKey(log.id),
                      log: log,
                      showDate: todayLogs.isEmpty,
                      hourlyRate: controller.hourlyRate,
                      currencySymbol: controller.currencySymbol,
                      onTap: () => _handleEditLog(context, log),
                      onDelete: () => _handleDeleteWithUndo(context, log),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedHeroLogButton extends StatefulWidget {
  const _AnimatedHeroLogButton({
    required this.title,
    required this.successTitle,
    required this.subtitle,
    required this.onConfirmedTap,
  });

  final String title;
  final String successTitle;
  final String subtitle;
  final Future<void> Function() onConfirmedTap;

  @override
  State<_AnimatedHeroLogButton> createState() => _AnimatedHeroLogButtonState();
}

class _AnimatedHeroLogButtonState extends State<_AnimatedHeroLogButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final Animation<double> _emojiScale;
  late final Animation<double> _emojiTilt;
  late final Animation<double> _cardBounce;

  bool _pressed = false;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _emojiScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.30), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.30, end: 0.94), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutCubic));

    _emojiTilt = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.16), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.16, end: 0.14), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeInOut));

    _cardBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.02), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerTap() async {
    if (_celebrating) return;
    setState(() {
      _pressed = false;
      _celebrating = true;
    });
    _popCtrl.forward(from: 0);

    try {
      await widget.onConfirmedTap();
    } finally {
      if (mounted) {
        setState(() => _celebrating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLip = _pressed ? 1.5 : 7.0;
    final topOffset = _pressed ? 5.5 : 0.0;
    final faceColor = _celebrating ? TronoColors.gold : TronoColors.terracotta;
    final lipColor =
        _celebrating ? TronoColors.goldLip : TronoColors.terracottaLip;
    final fgColor = _celebrating ? TronoColors.obsidian : Colors.white;

    return GestureDetector(
      onTapDown: (_) {
        if (_celebrating) return;
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => _triggerTap(),
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _popCtrl,
        builder: (context, child) {
          final scale = _popCtrl.isAnimating ? _cardBounce.value : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          width: double.infinity,
          margin: EdgeInsets.only(top: topOffset),
          padding: EdgeInsets.only(bottom: currentLip),
          decoration: BoxDecoration(
            color: lipColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: _pressed
                ? null
                : [
                    BoxShadow(
                      color: faceColor.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: faceColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _popCtrl,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _emojiTilt.value,
                      child: Transform.scale(
                        scale: _emojiScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: fgColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text('👑', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Align(
                          key: ValueKey(_celebrating),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _celebrating ? widget.successTitle : widget.title,
                            style: TextStyle(
                              color: fgColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fgColor.withValues(alpha: 0.86),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: fgColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _celebrating ? Icons.check_rounded : Icons.add_rounded,
                      key: ValueKey(_celebrating),
                      color: fgColor,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationPickerPill extends StatelessWidget {
  const _LocationPickerPill({
    super.key,
    required this.selected,
    required this.hasSalary,
    required this.onTap,
  });

  final _QuickLocationMode selected;
  final bool hasSalary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPaid =
        selected == _QuickLocationMode.wfh ||
        selected == _QuickLocationMode.work;

    final (IconData icon, Color accent, String label) = switch (selected) {
      _QuickLocationMode.auto => (
        Icons.my_location_rounded,
        TronoColors.terracotta,
        s.locationAutoTitle,
      ),
      _QuickLocationMode.home => (
        Icons.home_rounded,
        TronoColors.goldLip,
        s.quickHomeButton,
      ),
      _QuickLocationMode.wfh => (
        Icons.laptop_mac_rounded,
        TronoColors.sage,
        s.wfhLocationName,
      ),
      _QuickLocationMode.work => (
        Icons.work_rounded,
        isDark ? TronoColors.darkInk : TronoColors.obsidian,
        s.quickWorkButton,
      ),
      _QuickLocationMode.away => (
        Icons.public_rounded,
        TronoColors.terracotta,
        s.quickAwayButton,
      ),
    };

    return Material(
      color: TronoColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPaid
              ? TronoColors.gold
              : TronoColors.border(context),
          width: isPaid ? 2 : 1.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                '${s.locationField}:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TronoColors.muted(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: TronoColors.ink(context),
                  ),
                ),
              ),
              if (isPaid && hasSalary) ...[
                const Text('💰', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: TronoColors.muted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TronoBrandMark extends StatelessWidget {
  const _TronoBrandMark({
    super.key,
    required this.size,
    required this.isDark,
  });

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TronoBrandMarkPainter(isDark: isDark),
    );
  }
}

/// Always-white crowned-throne vector silhouette with Warm Gold crown and
/// Terracotta accents. In light mode, adds a crisp Obsidian sticker outline +
/// subtle tactile drop shadow so white pops cleanly on Warm Cream without any
/// dark square box.
class _TronoBrandMarkPainter extends CustomPainter {
  const _TronoBrandMarkPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    canvas.save();
    canvas.scale(sx, sy);

    final crownPath = Path()
      ..moveTo(5.4, 6.7)
      ..lineTo(4.6, 2.8)
      ..lineTo(7.3, 4.8)
      ..lineTo(9.0, 1.9)
      ..lineTo(10.7, 4.8)
      ..lineTo(13.4, 2.8)
      ..lineTo(12.6, 6.7)
      ..close();

    final thronePath = Path()
      ..moveTo(5.2, 8.0)
      ..lineTo(12.8, 8.0)
      ..cubicTo(13.1, 8.0, 13.4, 8.3, 13.4, 8.6)
      ..lineTo(13.4, 12.2)
      ..lineTo(19.4, 12.2)
      ..cubicTo(19.9, 12.2, 20.3, 12.6, 20.3, 13.1)
      ..cubicTo(20.3, 16.1, 18.1, 18.2, 15.1, 18.4)
      ..lineTo(15.6, 20.5)
      ..lineTo(16.3, 20.5)
      ..cubicTo(16.7, 20.5, 17.0, 20.8, 17.0, 21.2)
      ..cubicTo(17.0, 21.6, 16.7, 21.9, 16.3, 21.9)
      ..lineTo(6.9, 21.9)
      ..cubicTo(6.5, 21.9, 6.2, 21.6, 6.2, 21.2)
      ..cubicTo(6.2, 20.8, 6.5, 20.5, 6.9, 20.5)
      ..lineTo(7.5, 20.5)
      ..lineTo(8.1, 17.8)
      ..cubicTo(6.1, 17.3, 4.6, 15.6, 4.6, 13.4)
      ..lineTo(4.6, 8.6)
      ..cubicTo(4.6, 8.3, 4.9, 8.0, 5.2, 8.0)
      ..close();

    // Subtle chunky drop-lip in light mode so white throne pops off Warm Cream
    if (!isDark) {
      canvas.save();
      canvas.translate(0.55, 0.75);
      final lipPaint = Paint()..color = TronoColors.lightLip;
      canvas.drawPath(thronePath, lipPaint);
      canvas.restore();
    }

    // 1. Always-white throne fill + crisp Obsidian outline in light mode
    canvas.drawPath(thronePath, Paint()..color = Colors.white);
    if (!isDark) {
      canvas.drawPath(
        thronePath,
        Paint()
          ..color = TronoColors.obsidian
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Subtle Terracotta flush lever detail on the tank
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.3, 9.6, 2.3, 0.9),
        const Radius.circular(0.45),
      ),
      Paint()..color = TronoColors.terracotta,
    );

    // 2. Royal crown in Warm Gold + crisp outline in light mode
    canvas.drawPath(crownPath, Paint()..color = TronoColors.gold);
    if (!isDark) {
      canvas.drawPath(
        crownPath,
        Paint()
          ..color = TronoColors.obsidian
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Terracotta crown band
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.2, 6.1, 7.6, 1.0),
        const Radius.circular(0.5),
      ),
      Paint()..color = TronoColors.terracotta,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TronoBrandMarkPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _LiveTimerHeroButton extends StatelessWidget {
  const _LiveTimerHeroButton({
    super.key,
    required this.clockText,
    required this.subtitle,
    required this.onFinishTap,
    this.liveEarningsText,
  });

  final String clockText;
  final String subtitle;
  final String? liveEarningsText;
  final VoidCallback onFinishTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyButton(
      width: double.infinity,
      color: TronoColors.obsidian,
      lipColor: TronoColors.obsidianLip,
      borderColor: TronoColors.gold,
      lipHeight: 6,
      borderRadius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      onPressed: onFinishTap,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: TronoColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.timer_rounded,
              color: TronoColors.gold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      clockText,
                      style: const TextStyle(
                        color: TronoColors.gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (liveEarningsText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2618),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: TronoColors.gold.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          liveEarningsText!,
                          style: const TextStyle(
                            color: TronoColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: TronoColors.sage,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
