import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../services/update_checker_service.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/achievement_unlock_dialog.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/log_detail_sheet.dart';
import '../widgets/log_tile.dart';
import '../widgets/trono_toast.dart';
import '../widgets/update_banner_card.dart';

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
        showTronoToastOnMessenger(
          messenger,
          s.detailsSavedToast,
          duration: const Duration(seconds: 2),
        );
      }
    } else if (context.mounted) {
      // User skipped/dismissed the detail sheet — show crisp toast with Undo!
      showTronoToastOnMessenger(
        messenger,
        '$prefix${s.savedInstantToast}',
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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TronoColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: Image.asset(
                    'assets/icon/trono_icon.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                s.appName,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: TronoColors.ink(context),
                ),
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

              // Compact Location Mode Selector (Auto · Home · WFH · Work · Away)
              _LocationModeSelector(
                selected: _locationMode,
                autoLabel: s.quickAutoChip,
                homeLabel: s.quickHomeButton,
                wfhLabel: s.quickWfhButton,
                workLabel: s.quickWorkCompactButton,
                awayLabel: s.quickAwayButton,
                onChanged: (mode) {
                  HapticFeedback.selectionClick();
                  setState(() => _locationMode = mode);
                },
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

class _LocationModeSelector extends StatelessWidget {
  const _LocationModeSelector({
    required this.selected,
    required this.autoLabel,
    required this.homeLabel,
    required this.wfhLabel,
    required this.workLabel,
    required this.awayLabel,
    required this.onChanged,
  });

  final _QuickLocationMode selected;
  final String autoLabel;
  final String homeLabel;
  final String wfhLabel;
  final String workLabel;
  final String awayLabel;
  final ValueChanged<_QuickLocationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : const Color(0xFFECE6DA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ModeTab(
            key: const ValueKey('quick_loc_auto'),
            icon: Icons.my_location_rounded,
            label: autoLabel,
            active: selected == _QuickLocationMode.auto,
            onTap: () => onChanged(_QuickLocationMode.auto),
          ),
          _ModeTab(
            key: const ValueKey('quick_loc_home'),
            icon: Icons.home_rounded,
            label: homeLabel,
            active: selected == _QuickLocationMode.home,
            activeColor: TronoColors.goldLip,
            onTap: () => onChanged(_QuickLocationMode.home),
          ),
          _ModeTab(
            key: const ValueKey('quick_loc_wfh'),
            icon: Icons.laptop_mac_rounded,
            label: wfhLabel,
            active: selected == _QuickLocationMode.wfh,
            activeColor: TronoColors.sage,
            onTap: () => onChanged(_QuickLocationMode.wfh),
          ),
          _ModeTab(
            key: const ValueKey('quick_loc_work'),
            icon: Icons.work_rounded,
            label: workLabel,
            active: selected == _QuickLocationMode.work,
            activeColor: isDark ? TronoColors.darkInk : TronoColors.obsidian,
            onTap: () => onChanged(_QuickLocationMode.work),
          ),
          _ModeTab(
            key: const ValueKey('quick_loc_away'),
            icon: Icons.public_rounded,
            label: awayLabel,
            active: selected == _QuickLocationMode.away,
            activeColor: TronoColors.terracotta,
            onTap: () => onChanged(_QuickLocationMode.away),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? (activeColor ?? TronoColors.ink(context))
        : TronoColors.muted(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: active ? TronoColors.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 2.5),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: fg,
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
