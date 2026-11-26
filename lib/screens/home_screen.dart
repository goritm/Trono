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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final TronoController controller;

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
    final prefix = locationKind != null ? '${locationKind.emoji} ' : '${type.emoji} ';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$prefix${s.savedInstantToast}'),
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await showLogDetailSheet(
      context,
      mode: LogSheetMode.quickFollowUp,
      initialLog: savedLog,
      defaultShareLevel: controller.defaultShareLevel,
    );

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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
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
              // Clean Bold Numbers Dashboard Strip (Today + 7d Avg)
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

              // THE GIANT CHUNKY 3D TERRACOTTA HERO BUTTON
              ChunkyButton(
                width: double.infinity,
                color: TronoColors.terracotta,
                lipColor: TronoColors.terracottaLip,
                lipHeight: 7,
                borderRadius: 26,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 22,
                ),
                onPressed: () => _handleQuickTap(context, BathroomType.poop),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💩', style: TextStyle(fontSize: 34)),
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
                            s.oneTapHint,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
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

              // 1-Tap Location Shortcuts: Home vs Away (+1 Pupu immediately!)
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      color: TronoColors.surface(context),
                      lipColor: TronoColors.goldLip,
                      borderColor: TronoColors.gold,
                      lipHeight: 4,
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      onPressed: () => _handleQuickTap(
                        context,
                        BathroomType.poop,
                        locationKind: LocationKind.home,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.home_rounded,
                            size: 19,
                            color: TronoColors.goldLip,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${s.quickHomeButton} +1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: TronoColors.ink(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChunkyButton(
                      color: TronoColors.surface(context),
                      lipColor: TronoColors.terracottaLip,
                      borderColor: TronoColors.terracotta,
                      lipHeight: 4,
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      onPressed: () => _handleQuickTap(
                        context,
                        BathroomType.poop,
                        locationKind: LocationKind.away,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            size: 19,
                            color: TronoColors.terracotta,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${s.quickAwayButton} +1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: TronoColors.ink(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Timer Active Card OR Chunky Secondary Actions Row
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: TronoColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: TronoColors.gold,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              s.timerHint,
                              style: TextStyle(
                                fontSize: 12,
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
                Row(
                  children: [
                    Expanded(
                      child: ChunkyButton(
                        color: TronoColors.surface(context),
                        lipColor: TronoColors.lip(context),
                        borderColor: TronoColors.border(context),
                        lipHeight: 4,
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        onPressed: () =>
                            _handleQuickTap(context, BathroomType.falseAlarm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.air_rounded,
                              size: 19,
                              color: TronoColors.muted(context),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                s.typeName(BathroomType.falseAlarm),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: TronoColors.ink(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChunkyButton(
                        color: isDark
                            ? const Color(0xFF282E3C)
                            : TronoColors.obsidian,
                        lipColor: TronoColors.obsidianLip,
                        lipHeight: 4,
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        onPressed: controller.startTimer,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_rounded,
                              size: 19,
                              color: TronoColors.gold,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                s.startTimer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),

              // Subtle Past Visit Action
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => _handleAddPast(context),
                  icon: Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: TronoColors.muted(context),
                  ),
                  label: Text(
                    s.addPastVisit,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TronoColors.muted(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
