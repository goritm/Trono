import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/achievement_unlock_dialog.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/log_detail_sheet.dart';
import '../widgets/log_tile.dart';

enum _QuickLocationMode { auto, home, away }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _QuickLocationMode _locationMode = _QuickLocationMode.auto;

  TronoController get controller => widget.controller;

  LocationKind? get _selectedLocationKind => switch (_locationMode) {
    _QuickLocationMode.auto => null,
    _QuickLocationMode.home => LocationKind.home,
    _QuickLocationMode.away => LocationKind.away,
  };

  Future<void> _handleQuickTap(
    BuildContext context,
    BathroomType type, {
    LocationKind? locationKind,
  }) async {
    HapticFeedback.mediumImpact();
    final s = AppStrings.of(context);
    final (savedLog, initialUnlocks) = await controller.quickLog(
      type,
      locationKind: locationKind,
    );

    if (!context.mounted) return;
    final prefix =
        locationKind != null ? '${locationKind.emoji} ' : '${type.emoji} ';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$prefix${s.savedInstantToast}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: s.undoAction,
          textColor: TronoColors.gold,
          onPressed: () async {
            await controller.deleteLog(savedLog.id);
            messenger.showSnackBar(
              SnackBar(
                content: Text(s.undoneToast),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );

    final result = await showLogDetailSheet(
      context,
      mode: LogSheetMode.quickFollowUp,
      initialLog: savedLog,
      defaultShareLevel: controller.defaultShareLevel,
    );

    if (result?.deleted == true) {
      await controller.deleteLog(savedLog.id);
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(s.undoneToast),
            duration: const Duration(seconds: 2),
          ),
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
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(s.detailsSavedToast),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    );
    if (result?.savedLog == null) return;
    final unlocks = await controller.saveLog(result!.savedLog!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.savedInstantToast)),
    );
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
    );
    if (result == null) return;
    if (result.deleted) {
      await controller.deleteLog(log.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.logDeletedToast)),
        );
      }
    } else if (result.savedLog != null) {
      final unlocks = await controller.saveLog(result.savedLog!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.detailsSavedToast)),
        );
        if (unlocks.hasAnything) {
          await showUnlockCelebrationIfNeeded(context, unlocks);
        }
      }
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
      _QuickLocationMode.home => '🏠 ${s.quickHomeButton} · ${s.oneTapHint}',
      _QuickLocationMode.away => '🌍 ${s.quickAwayButton} · ${s.oneTapHint}',
    };

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(
            s.appName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: TronoColors.ink(context),
            ),
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
            ),
            const SizedBox(width: 16),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          sliver: SliverList.list(
            children: [
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
                    Container(
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
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Compact Location Mode Selector (Auto · Casa · Fuera)
              _LocationModeSelector(
                selected: _locationMode,
                autoLabel: s.quickAutoChip,
                homeLabel: s.quickHomeButton,
                awayLabel: s.quickAwayButton,
                onChanged: (mode) {
                  HapticFeedback.selectionClick();
                  setState(() => _locationMode = mode);
                },
              ),
              const SizedBox(height: 10),

              // THE SINGLE CHUNKY 3D HERO BUTTON
              ChunkyButton(
                width: double.infinity,
                color: TronoColors.terracotta,
                lipColor: TronoColors.terracottaLip,
                lipHeight: 7,
                borderRadius: 26,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                onPressed: () => _handleQuickTap(
                  context,
                  BathroomType.poop,
                  locationKind: _selectedLocationKind,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💩', style: TextStyle(fontSize: 36)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.heroLogTitle.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            heroSub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Active Live Timer Pill OR Clean Subtle Utility Strip
              if (controller.isTimerRunning)
                ChunkyCard(
                  color: TronoColors.obsidian,
                  borderColor: TronoColors.gold.withValues(alpha: 0.6),
                  lipColor: TronoColors.obsidianLip,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: TronoColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: TronoColors.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.timerRunning} ${_formatClock(controller.elapsedTimerSeconds)}',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              s.timerHint,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: controller.cancelTimer,
                        tooltip: s.cancelTimer,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: TronoColors.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: TronoColors.border(context),
                      width: 1.6,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _UtilityAction(
                            icon: Icons.timer_outlined,
                            label: s.timerShort,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.startTimer();
                            },
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1.4,
                          indent: 10,
                          endIndent: 10,
                          color: TronoColors.border(context),
                        ),
                        Expanded(
                          child: _UtilityAction(
                            icon: Icons.air_rounded,
                            label: s.typeName(BathroomType.falseAlarm),
                            onTap: () => _handleQuickTap(
                              context,
                              BathroomType.falseAlarm,
                              locationKind: _selectedLocationKind,
                            ),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1.4,
                          indent: 10,
                          endIndent: 10,
                          color: TronoColors.border(context),
                        ),
                        Expanded(
                          child: _UtilityAction(
                            icon: Icons.history_rounded,
                            label: s.pastVisitShort,
                            onTap: () => _handleAddPast(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),

              // Today / Recent History Header
              Text(
                (todayLogs.isNotEmpty ? s.todayHistory : s.recentHistory)
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: TronoColors.muted(context),
                ),
              ),
              const SizedBox(height: 10),

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
                      log: log,
                      showDate: todayLogs.isEmpty,
                      onTap: () => _handleEditLog(context, log),
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

class _LocationModeSelector extends StatelessWidget {
  const _LocationModeSelector({
    required this.selected,
    required this.autoLabel,
    required this.homeLabel,
    required this.awayLabel,
    required this.onChanged,
  });

  final _QuickLocationMode selected;
  final String autoLabel;
  final String homeLabel;
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
            icon: Icons.my_location_rounded,
            label: autoLabel,
            active: selected == _QuickLocationMode.auto,
            onTap: () => onChanged(_QuickLocationMode.auto),
          ),
          _ModeTab(
            icon: Icons.home_rounded,
            label: homeLabel,
            active: selected == _QuickLocationMode.home,
            activeColor: TronoColors.goldLip,
            onTap: () => onChanged(_QuickLocationMode.home),
          ),
          _ModeTab(
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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityAction extends StatelessWidget {
  const _UtilityAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = TronoColors.muted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
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
    );
  }
}
