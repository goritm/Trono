import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/monthly_comparison.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

/// Tactile Chunky 3D card comparing the current month against the previous month.
class MonthlyComparisonCard extends StatelessWidget {
  const MonthlyComparisonCard({super.key, required this.snapshot});

  final MonthlyComparisonSnapshot snapshot;

  String _formatShortMonth(DateTime date, String localeCode) {
    try {
      final raw = DateFormat('MMM', localeCode).format(date).replaceAll('.', '');
      if (raw.isEmpty) return raw;
      return raw[0].toUpperCase() + raw.substring(1);
    } catch (_) {
      final raw = DateFormat('MMM').format(date).replaceAll('.', '');
      if (raw.isEmpty) return raw;
      return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final curMonthLabel = _formatShortMonth(
      snapshot.currentMonth,
      s.locale.languageCode,
    );
    final prevMonthLabel = _formatShortMonth(
      snapshot.previousMonth,
      s.locale.languageCode,
    );

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows_rounded,
                color: TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.monthlyComparisonTitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: TronoColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$curMonthLabel vs $prevMonthLabel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: TronoColors.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
              _DeltaPill(
                deltaPercent: snapshot.poopsDeltaPercent,
                hasCurrentData: snapshot.currentMonthPoops > 0,
                newLabel: s.comparisonDeltaNew,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!snapshot.hasMonthlyData)
            Text(
              s.comparisonEmptyHint,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TronoColors.muted(context),
              ),
            )
          else ...[
            // Side-by-side total pupús hero tiles
            Row(
              children: [
                Expanded(
                  child: _MonthHeroTile(
                    monthLabel: curMonthLabel,
                    count: snapshot.currentMonthPoops,
                    unit: s.poopUnitFor(snapshot.currentMonthPoops),
                    isHighlighted: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MonthHeroTile(
                    monthLabel: prevMonthLabel,
                    count: snapshot.previousMonthPoops,
                    unit: s.poopUnitFor(snapshot.previousMonthPoops),
                    isHighlighted: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metric comparison rows
            _ComparisonMetricRow(
              label: s.dailyAvgLabel,
              currentValue: snapshot.currentMonthAvgPerDay.toStringAsFixed(1),
              previousValue: snapshot.previousMonthAvgPerDay.toStringAsFixed(1),
              currentMonthShort: curMonthLabel,
              previousMonthShort: prevMonthLabel,
              showColumnHeaders: true,
            ),
            Divider(height: 16, thickness: 1.5, color: TronoColors.border(context)),
            _ComparisonMetricRow(
              label: s.comparisonAwayLabel,
              currentValue: snapshot.currentMonthAwayPercent != null
                  ? '${snapshot.currentMonthAwayPercent}%'
                  : '—',
              previousValue: snapshot.previousMonthAwayPercent != null
                  ? '${snapshot.previousMonthAwayPercent}%'
                  : '—',
              currentMonthShort: curMonthLabel,
              previousMonthShort: prevMonthLabel,
            ),
            Divider(height: 16, thickness: 1.5, color: TronoColors.border(context)),
            _ComparisonMetricRow(
              label: s.comparisonBristolLabel,
              currentValue: snapshot.currentMonthAvgBristol != null
                  ? snapshot.currentMonthAvgBristol!.toStringAsFixed(1)
                  : '—',
              previousValue: snapshot.previousMonthAvgBristol != null
                  ? snapshot.previousMonthAvgBristol!.toStringAsFixed(1)
                  : '—',
              currentMonthShort: curMonthLabel,
              previousMonthShort: prevMonthLabel,
              trailingBadge: snapshot.currentMonthAvgBristol != null
                  ? _BristolZonePill(
                      avgBristol: snapshot.currentMonthAvgBristol!,
                      idealPercent: snapshot.idealBristolPercent,
                      isDark: isDark,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.deltaPercent,
    required this.hasCurrentData,
    required this.newLabel,
  });

  final int? deltaPercent;
  final bool hasCurrentData;
  final String newLabel;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color bg;
    final Color fg;

    if (deltaPercent == null) {
      if (!hasCurrentData) {
        return const SizedBox.shrink();
      }
      text = newLabel;
      bg = TronoColors.terracotta.withValues(alpha: 0.14);
      fg = TronoColors.terracotta;
    } else if (deltaPercent! > 0) {
      text = '+$deltaPercent%';
      bg = TronoColors.terracotta.withValues(alpha: 0.14);
      fg = TronoColors.terracotta;
    } else if (deltaPercent! < 0) {
      text = '$deltaPercent%';
      bg = TronoColors.sage.withValues(alpha: 0.16);
      fg = TronoColors.sage;
    } else {
      text = '=';
      bg = TronoColors.border(context).withValues(alpha: 0.7);
      fg = TronoColors.muted(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MonthHeroTile extends StatelessWidget {
  const _MonthHeroTile({
    required this.monthLabel,
    required this.count,
    required this.unit,
    required this.isHighlighted,
  });

  final String monthLabel;
  final int count;
  final String unit;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? TronoColors.terracotta.withValues(alpha: 0.55)
              : TronoColors.border(context),
          width: isHighlighted ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: isHighlighted
                  ? TronoColors.terracotta
                  : TronoColors.muted(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: isHighlighted
                      ? TronoColors.terracotta
                      : TronoColors.ink(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  unit,
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
        ],
      ),
    );
  }
}

class _ComparisonMetricRow extends StatelessWidget {
  const _ComparisonMetricRow({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.currentMonthShort,
    required this.previousMonthShort,
    this.showColumnHeaders = false,
    this.trailingBadge,
  });

  final String label;
  final String currentValue;
  final String previousValue;
  final String currentMonthShort;
  final String previousMonthShort;
  final bool showColumnHeaders;
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showColumnHeaders) ...[
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Text(
                  currentMonthShort.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: TronoColors.terracotta,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  previousMonthShort.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: TronoColors.ink(context),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                currentValue,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: TronoColors.ink(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                previousValue,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: TronoColors.muted(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        if (trailingBadge != null) ...[
          const SizedBox(height: 8),
          trailingBadge!,
        ],
      ],
    );
  }
}

class _BristolZonePill extends StatelessWidget {
  const _BristolZonePill({
    required this.avgBristol,
    required this.idealPercent,
    required this.isDark,
  });

  final double avgBristol;
  final int? idealPercent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final bool isIdeal = avgBristol >= 3.0 && avgBristol <= 4.5;
    final bool isFirm = avgBristol < 3.0;

    final Color fg;
    final Color bg;
    final String zoneLabel;
    final IconData icon;

    if (isIdeal) {
      fg = TronoColors.sage;
      bg = TronoColors.sage.withValues(alpha: 0.14);
      zoneLabel = s.bristolZoneIdeal;
      icon = Icons.check_circle_rounded;
    } else if (isFirm) {
      fg = isDark ? TronoColors.gold : TronoColors.goldLip;
      bg = TronoColors.gold.withValues(alpha: 0.18);
      zoneLabel = s.bristolZoneFirm;
      icon = Icons.info_rounded;
    } else {
      fg = TronoColors.terracotta;
      bg = TronoColors.terracotta.withValues(alpha: 0.14);
      zoneLabel = s.bristolZoneSoft;
      icon = Icons.water_drop_rounded;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                zoneLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        if (idealPercent != null)
          Text(
            s.idealBristolPctSub(idealPercent!),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: TronoColors.muted(context),
            ),
          ),
      ],
    );
  }
}

/// Interactive 8-week Monday–Sunday tactile bar chart with average reference line
/// and tap-to-inspect selected week details.
class WeeklyTrendChartCard extends StatefulWidget {
  const WeeklyTrendChartCard({super.key, required this.weeks});

  final List<WeeklyTrendBucket> weeks;

  @override
  State<WeeklyTrendChartCard> createState() => _WeeklyTrendChartCardState();
}

class _WeeklyTrendChartCardState extends State<WeeklyTrendChartCard> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = math.max(0, widget.weeks.length - 1);
  }

  @override
  void didUpdateWidget(covariant WeeklyTrendChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weeks.isEmpty) {
      _selectedIndex = 0;
    } else if (_selectedIndex >= widget.weeks.length) {
      _selectedIndex = widget.weeks.length - 1;
    }
  }

  String _ddMm(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = widget.weeks;

    final maxCount = weeks.fold<int>(0, (m, b) => math.max(m, b.poopCount));
    final totalPoops = weeks.fold<int>(0, (sum, b) => sum + b.poopCount);
    final avgPoops = weeks.isEmpty ? 0.0 : totalPoops / weeks.length;
    final priorBarColor = isDark
        ? const Color(0xFF525A6E)
        : TronoColors.obsidian;

    const double barAreaHeight = 104.0;
    final double avgRatio =
        (maxCount > 0 && avgPoops > 0) ? (avgPoops / maxCount).clamp(0.0, 1.0) : 0.0;

    final selected =
        weeks.isNotEmpty ? weeks[_selectedIndex.clamp(0, weeks.length - 1)] : null;

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.weeklyTrendTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
              if (avgPoops > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TronoColors.bg(context),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: TronoColors.border(context),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    s.weeklyAvgPill(avgPoops),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: TronoColors.muted(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (weeks.isEmpty)
            Text(
              s.noPeakHourYet,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TronoColors.muted(context),
              ),
            )
          else ...[
            // Bar chart with dashed average reference line
            SizedBox(
              height: barAreaHeight + 44,
              child: Stack(
                children: [
                  if (avgRatio > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 20,
                      height: barAreaHeight,
                      child: CustomPaint(
                        painter: _AverageLinePainter(
                          ratioFromBottom: avgRatio,
                          color: TronoColors.muted(context)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(weeks.length, (i) {
                      final b = weeks[i];
                      final isSelected = i == _selectedIndex;
                      final ratio =
                          maxCount <= 0 ? 0.0 : b.poopCount / maxCount;
                      final barHeight = b.poopCount == 0
                          ? 6.0
                          : math.max(12.0, ratio * (barAreaHeight - 4));

                      final Color barColor = b.isCurrentWeek
                          ? TronoColors.terracotta
                          : b.poopCount > 0
                              ? priorBarColor
                              : TronoColors.border(context);

                      final Color? selectionBorder = isSelected
                          ? (b.isCurrentWeek
                              ? TronoColors.terracottaLip
                              : TronoColors.gold)
                          : null;

                      return Expanded(
                        child: GestureDetector(
                          key: ValueKey('weekly_trend_bar_$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 18,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${b.poopCount}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected || b.isCurrentWeek
                                            ? FontWeight.w900
                                            : FontWeight.w800,
                                        color: b.isCurrentWeek
                                            ? TronoColors.terracotta
                                            : b.poopCount > 0
                                                ? TronoColors.ink(context)
                                                : TronoColors.muted(context),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: barAreaHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 240),
                                      curve: Curves.easeOutCubic,
                                      width: double.infinity,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: barColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: selectionBorder != null
                                            ? Border.all(
                                                color: selectionBorder,
                                                width: 2.2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _ddMm(b.weekStart),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected || b.isCurrentWeek
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? (b.isCurrentWeek
                                              ? TronoColors.terracotta
                                              : TronoColors.ink(context))
                                          : TronoColors.muted(context),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // Interactive selected week inspection pill
            if (selected != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('weekly_trend_inspector'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected.isCurrentWeek
                        ? TronoColors.terracotta.withValues(alpha: 0.45)
                        : TronoColors.border(context),
                    width: 1.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.weekRangeLabel(
                              _ddMm(selected.weekStart),
                              _ddMm(selected.weekEnd),
                            ),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.ink(context),
                            ),
                          ),
                        ),
                        if (selected.isCurrentWeek)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: TronoColors.terracotta
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.currentWeekBadge,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: TronoColors.terracotta,
                              ),
                            ),
                          )
                        else
                          Text(
                            s.tapBarInspectHint,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: TronoColors.muted(context),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _InspectorChip(
                          emoji: '💩',
                          text: s.poopsCountLabel(selected.poopCount),
                          highlight: selected.isCurrentWeek,
                        ),
                        _InspectorChip(
                          emoji: '📈',
                          text:
                              '${selected.avgPerDay.toStringAsFixed(1)}${s.perDayShort}',
                        ),
                        _InspectorChip(
                          emoji: '🎯',
                          text:
                              '${s.bristolShortLabel} ${selected.avgBristol != null ? selected.avgBristol!.toStringAsFixed(1) : '—'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InspectorChip extends StatelessWidget {
  const _InspectorChip({
    required this.emoji,
    required this.text,
    this.highlight = false,
  });

  final String emoji;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: highlight
                ? TronoColors.terracotta
                : TronoColors.ink(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AverageLinePainter extends CustomPainter {
  const _AverageLinePainter({
    required this.ratioFromBottom,
    required this.color,
  });

  final double ratioFromBottom;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - (ratioFromBottom * (size.height - 4));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    double x = 0;
    while (x < size.width) {
      final endX = math.min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _AverageLinePainter oldDelegate) {
    return oldDelegate.ratioFromBottom != ratioFromBottom ||
        oldDelegate.color != color;
  }
}
