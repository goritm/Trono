import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/insights.dart';
import '../models/stats_summary.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/achievement_unlock_dialog.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/log_detail_sheet.dart';
import '../widgets/log_tile.dart';
import '../widgets/trono_toast.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'wrapped_screen.dart';

class CalendarStatsScreen extends StatefulWidget {
  const CalendarStatsScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<CalendarStatsScreen> createState() => _CalendarStatsScreenState();
}

class _CalendarStatsScreenState extends State<CalendarStatsScreen> {
  StatsPeriod _period = StatsPeriod.week;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _openDaySheet(DateTime day) async {
    final s = AppStrings.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final dayLogs = widget.controller.logsForDay(day);
            final title = DateFormat(
              'EEEE, d MMM yyyy',
              s.locale.languageCode,
            ).format(day);

            return DraggableScrollableSheet(
              initialChildSize: 0.62,
              minChildSize: 0.35,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _capitalize(title),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          ChunkyButton(
                            color: TronoColors.terracotta,
                            lipColor: TronoColors.terracottaLip,
                            lipHeight: 3,
                            borderRadius: 14,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            onPressed: () async {
                              final res = await showLogDetailSheet(
                                context,
                                mode: LogSheetMode.createPast,
                                initialDate: day,
                                defaultShareLevel:
                                    widget.controller.defaultShareLevel,
                                favoritePlaces:
                                    widget.controller.favoritePlaces,
                              );
                              if (res?.savedLog != null) {
                                final unlocks = await widget.controller.saveLog(
                                  res!.savedLog!,
                                );
                                if (context.mounted && unlocks.hasAnything) {
                                  await showUnlockCelebrationIfNeeded(
                                    context,
                                    unlocks,
                                  );
                                }
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s.navLog,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: dayLogs.isEmpty
                            ? Center(
                                child: Text(
                                  s.noVisitsThisDay,
                                  style: TextStyle(
                                    color: TronoColors.muted(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: dayLogs.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final log = dayLogs[i];
                                  return LogTile(
                                    key: ValueKey(log.id),
                                    log: log,
                                    onTap: () => _editLog(context, log),
                                    onDelete: () =>
                                        _deleteWithUndo(context, log),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteWithUndo(BuildContext context, BathroomLog log) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.controller.deleteLog(log.id);
    if (!context.mounted) return;
    showTronoToastOnMessenger(
      messenger,
      s.logDeletedToast,
      actionLabel: s.undoAction,
      onAction: () => widget.controller.saveLog(log),
    );
  }

  Future<void> _editLog(BuildContext context, BathroomLog log) async {
    final s = AppStrings.of(context);
    final res = await showLogDetailSheet(
      context,
      mode: LogSheetMode.editExisting,
      initialLog: log,
      defaultShareLevel: widget.controller.defaultShareLevel,
      favoritePlaces: widget.controller.favoritePlaces,
    );
    if (res == null) return;
    if (res.deleted) {
      await widget.controller.deleteLog(log.id);
      if (context.mounted) {
        showTronoToast(context, s.logDeletedToast);
      }
    } else if (res.savedLog != null) {
      final unlocks = await widget.controller.saveLog(res.savedLog!);
      if (context.mounted && unlocks.hasAnything) {
        await showUnlockCelebrationIfNeeded(context, unlocks);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final stats = widget.controller.stats;
    final avg = stats.averageFor(_period);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(s.calendarStatsTitle),
          actions: [
            IconButton(
              tooltip: s.wrappedTitle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WrappedScreen(controller: widget.controller),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            IconButton(
              tooltip: s.mapScreenTitle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MapScreen(controller: widget.controller),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          sliver: SliverList.list(
            children: [
              // 1. Clean Terracotta & Charcoal Daily Average Hero Card
              ChunkyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.dailyAverageTitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: TronoColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<StatsPeriod>(
                        segments: [
                          ButtonSegment(
                            value: StatsPeriod.week,
                            label: Text(s.periodWeek),
                          ),
                          ButtonSegment(
                            value: StatsPeriod.month,
                            label: Text(s.periodMonth),
                          ),
                          ButtonSegment(
                            value: StatsPeriod.allTime,
                            label: Text(s.periodAll),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (set) {
                          setState(() => _period = set.first);
                        },
                        showSelectedIcon: false,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _AvgMetricReadout(
                            label: s.poopPerDay,
                            value: avg.avgPoopPerDay.toStringAsFixed(1),
                            sub: avg.daysSpan > 0
                                ? s.visitsTotalSub(
                                    avg.poopVisits,
                                    avg.daysSpan,
                                  )
                                : '—',
                            valueColor: TronoColors.terracotta,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 58,
                          color: TronoColors.border(context),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _AvgMetricReadout(
                            label: s.totalVisitsPerDay,
                            value: avg.avgTotalPerDay.toStringAsFixed(1),
                            sub: avg.daysSpan > 0
                                ? s.visitsTotalSub(
                                    avg.totalVisits,
                                    avg.daysSpan,
                                  )
                                : '—',
                            valueColor: TronoColors.ink(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1.5 Territory: Home vs Away Ratio & Throne Map Card
              _TerritoryStatsCard(
                stats: stats,
                onOpenMap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MapScreen(controller: widget.controller),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 1.6 Paid on the Throne Card (Work Earnings)
              _PaidOnThroneCard(
                paid: widget.controller.paidOnThrone,
                hasSalary: widget.controller.hasHourlyRate,
                currency: widget.controller.currencySymbol,
                onConfigure: () =>
                    showSalaryConfigDialog(context, widget.controller),
              ),
              const SizedBox(height: 16),

              // 1.7 Automatic Pattern Insights
              if (widget.controller.insights.isNotEmpty) ...[
                _InsightsCard(insights: widget.controller.insights),
                const SizedBox(height: 16),
              ],

              // 2. Monochromatic Warm Terracotta Monthly Heatmap
              ChunkyCard(
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
                                _capitalize(
                                  DateFormat(
                                    'MMMM yyyy',
                                    s.locale.languageCode,
                                  ).format(_visibleMonth),
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                s.tapDayHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: TronoColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => _shiftMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: () => _shiftMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MonthlyHeatmapGrid(
                      month: _visibleMonth,
                      dailyCounts: stats.dailyCounts,
                      weekdayHeaders: s.weekdayShorts,
                      onTapDay: _openDaySheet,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          s.heatmapLegendLess,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: TronoColors.muted(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...[0, 1, 2, 4, 6].map(
                          (lvl) => Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _heatColor(lvl, context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.heatmapLegendMore,
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
              const SizedBox(height: 16),

              // 3. Peak Hours Chart (Charcoal bars + Terracotta Peak Bar)
              ChunkyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.peakHoursTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (stats.peakHour != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TronoColors.terracotta.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${stats.peakHour!.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: TronoColors.terracotta,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.peakHour != null
                          ? s.peakHourSummary(stats.peakHour!)
                          : s.noPeakHourYet,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TronoColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PeakHoursChart(
                      hourlyCounts: stats.hourlyCounts,
                      peakHour: stats.peakHour,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Clean Cohesive Personal Records Grid (Terracotta + Gold only)
              Text(
                s.recordsTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: TronoColors.muted(context),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.42,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RecordCard(
                    icon: Icons.emoji_events_rounded,
                    accent: TronoColors.gold,
                    label: s.recordDayLabel,
                    value: stats.recordDayCount > 0
                        ? s.visitsCount(stats.recordDayCount)
                        : '—',
                    sub: stats.recordDayDate != null
                        ? DateFormat(
                            'd MMM yyyy',
                            s.locale.languageCode,
                          ).format(stats.recordDayDate!)
                        : '',
                  ),
                  _RecordCard(
                    icon: Icons.local_fire_department_rounded,
                    accent: TronoColors.terracotta,
                    label: s.longestStreakLabel,
                    value: stats.longestStreak > 0
                        ? s.daysCount(stats.longestStreak)
                        : '—',
                    sub: stats.currentStreak > 0
                        ? '${s.streakLabel}: ${s.daysShort(stats.currentStreak)}'
                        : '',
                  ),
                  _RecordCard(
                    icon: Icons.timer_rounded,
                    accent: TronoColors.terracotta,
                    label: s.longestSessionLabel,
                    value: stats.longestSessionSeconds > 0
                        ? s.formatDuration(stats.longestSessionSeconds)
                        : '—',
                    sub: stats.longestSessionDate != null
                        ? DateFormat(
                            'd MMM',
                            s.locale.languageCode,
                          ).format(stats.longestSessionDate!)
                        : '',
                  ),
                  _RecordCard(
                    icon: Icons.hourglass_bottom_rounded,
                    accent: TronoColors.gold,
                    label: s.totalTimeLabel,
                    value: stats.totalBathroomSeconds > 0
                        ? s.formatDuration(stats.totalBathroomSeconds)
                        : '—',
                    sub: s.visitsCount(stats.allTimeAvg.totalVisits),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Shareable Trono Wrapped Banner at the bottom
              ChunkyButton(
                width: double.infinity,
                color: TronoColors.obsidian,
                lipColor: TronoColors.obsidianLip,
                borderColor: TronoColors.gold.withValues(alpha: 0.5),
                lipHeight: 4,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WrappedScreen(controller: widget.controller),
                    ),
                  );
                },
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
                        Icons.auto_awesome_rounded,
                        color: TronoColors.gold,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.wrappedButtonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: TronoColors.gold,
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

Color _heatColor(int count, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (count <= 0) {
    return isDark ? const Color(0xFF252A36) : const Color(0xFFEDE7DC);
  }
  if (count == 1) {
    return isDark
        ? TronoColors.terracotta.withValues(alpha: 0.30)
        : const Color(0xFFFBE0D6);
  }
  if (count == 2) {
    return isDark
        ? TronoColors.terracotta.withValues(alpha: 0.52)
        : const Color(0xFFF3B198);
  }
  if (count <= 4) {
    return isDark
        ? TronoColors.terracotta.withValues(alpha: 0.78)
        : const Color(0xFFE87D55);
  }
  return TronoColors.terracotta;
}

class _PaidOnThroneCard extends StatelessWidget {
  const _PaidOnThroneCard({
    required this.paid,
    required this.hasSalary,
    required this.currency,
    required this.onConfigure,
  });

  final PaidOnThroneSummary paid;
  final bool hasSalary;
  final String currency;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_rounded,
                color: TronoColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.paidThroneTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onConfigure,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TronoColors.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.configureSalaryButton,
                    style: const TextStyle(
                      color: TronoColors.terracotta,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSalary)
            Text(
              s.paidSetupHint,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TronoColors.muted(context),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currency${paid.earnedThisMonth.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? TronoColors.gold
                              : TronoColors.goldLip,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        s.paidThisMonthLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 44,
                  color: TronoColors.border(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currency${paid.earnedAllTime.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: TronoColors.ink(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        s.paidAllTimeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.workVisitsSub(
                paid.workVisitsTotal,
                s.formatDuration(paid.workSecondsTotal),
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TronoColors.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<TronoInsight> insights;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                s.insightsTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: TronoColors.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TronoColors.border(context),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.insightText(
                          item.type.name,
                          int1: item.intValue,
                          int2: item.intValue2,
                          str: item.stringValue,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerritoryStatsCard extends StatelessWidget {
  const _TerritoryStatsCard({
    required this.stats,
    required this.onOpenMap,
  });

  final StatsSummary stats;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final hasRatio = stats.classifiedLocationCount > 0;
    final homeFlex = stats.homePoopCount;
    final awayFlex = stats.awayPoopCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.territoryTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: TronoColors.muted(context),
                ),
              ),
              const Spacer(),
              if (stats.distinctSpotsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TronoColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    s.spotsConqueredLabel(stats.distinctSpotsCount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? TronoColors.gold : TronoColors.goldLip,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasRatio)
            Text(
              s.noLocationDataYet,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TronoColors.muted(context),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.homePercent.round()}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? TronoColors.gold
                              : TronoColors.obsidian,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '🏠 ${s.homeShort} (${stats.homePoopCount})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stats.awayPercent.round()}%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: TronoColors.terracotta,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '🌍 ${s.awayShort} (${stats.awayPoopCount})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (homeFlex > 0)
                      Expanded(
                        flex: homeFlex,
                        child: Container(color: TronoColors.gold),
                      ),
                    if (awayFlex > 0)
                      Expanded(
                        flex: awayFlex,
                        child: Container(color: TronoColors.terracotta),
                      ),
                  ],
                ),
              ),
            ),
            if (stats.maxDistanceFromHomeKm >= 0.5) ...[
              const SizedBox(height: 8),
              Text(
                s.farthestDropLabel(stats.maxDistanceFromHomeKm),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TronoColors.muted(context),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          ChunkyButton(
            width: double.infinity,
            color: isDark ? const Color(0xFF282E3C) : TronoColors.obsidian,
            lipColor: TronoColors.obsidianLip,
            lipHeight: 4,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: onOpenMap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map_rounded,
                  color: TronoColors.gold,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(
                  s.openMapButton.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.4,
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

class _AvgMetricReadout extends StatelessWidget {
  const _AvgMetricReadout({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: valueColor,
            letterSpacing: -1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: TronoColors.ink(context),
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 11.5,
            color: TronoColors.muted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthlyHeatmapGrid extends StatelessWidget {
  const _MonthlyHeatmapGrid({
    required this.month,
    required this.dailyCounts,
    required this.weekdayHeaders,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<DateTime, int> dailyCounts;
  final List<String> weekdayHeaders;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingBlanks = firstDay.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;

    return Column(
      children: [
        Row(
          children: weekdayHeaders
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final dayNum = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, dayNum);
            final count = dailyCounts[date] ?? 0;
            final isToday = date == today;
            final fill = _heatColor(count, context);
            final highIntensity = count >= 3;

            return InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onTapDay(date),
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(11),
                  border: isToday
                      ? Border.all(color: TronoColors.obsidian, width: 2.2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: highIntensity
                            ? Colors.white
                            : TronoColors.ink(context),
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: highIntensity
                              ? Colors.white.withValues(alpha: 0.92)
                              : TronoColors.terracottaLip,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  const _PeakHoursChart({
    required this.hourlyCounts,
    required this.peakHour,
  });

  final List<int> hourlyCounts;
  final int? peakHour;

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlyCounts.fold<int>(0, math.max);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBase = isDark ? const Color(0xFF525A6E) : TronoColors.obsidian;

    return Column(
      children: [
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (hour) {
              final count = hourlyCounts[hour];
              final ratio = maxVal <= 0 ? 0.0 : count / maxVal;
              final isPeak = peakHour == hour && count > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Tooltip(
                    message: '${hour.toString().padLeft(2, '0')}h: $count',
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        height: math.max(5, ratio * 104),
                        decoration: BoxDecoration(
                          color: isPeak
                              ? TronoColors.terracotta
                              : count > 0
                                  ? barBase
                                  : TronoColors.border(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['00h', '06h', '12h', '18h', '23h']
              .map(
                (lbl) => Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 11,
                    color: TronoColors.muted(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: TronoColors.ink(context),
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: TronoColors.muted(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
