import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/trigger_lab.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

/// Interactive Tactile Chunky 3D card correlating food/lifestyle triggers
/// against the user's Bristol Scale & effort history (100% local).
class TriggerLabCard extends StatefulWidget {
  const TriggerLabCard({super.key, required this.snapshot});

  final TriggerLabSnapshot snapshot;

  @override
  State<TriggerLabCard> createState() => _TriggerLabCardState();
}

class _TriggerLabCardState extends State<TriggerLabCard> {
  String? _selectedTagKey;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final snap = widget.snapshot;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final TriggerStat? selected = snap.triggers.isEmpty
        ? null
        : snap.triggers.firstWhere(
            (t) => t.tagKey == _selectedTagKey,
            orElse: () => snap.triggers.first,
          );

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_rounded,
                color: TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.triggerLabTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
              if (snap.baselineBristol != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TronoColors.bg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: TronoColors.border(context),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    s.triggerLabBaselinePill(snap.baselineBristol!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: TronoColors.ink(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!snap.hasEnoughData) ...[
            Text(
              s.triggerLabEmptyHint,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: TronoColors.muted(context),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TronoColors.bg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TronoColors.border(context),
                  width: 1.5,
                ),
              ),
              child: Text(
                s.triggerLabProgressChip(snap.taggedLogCount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: TronoColors.ink(context),
                ),
              ),
            ),
          ] else ...[
            if (snap.bestAlly != null || snap.topDisruptor != null) ...[
              Row(
                children: [
                  if (snap.bestAlly != null)
                    Expanded(
                      child: _HighlightTile(
                        title: s.triggerLabBestAllyLabel,
                        tagLabel: s.tagLabel(snap.bestAlly!.tagKey),
                        accent: TronoColors.sage,
                        fillColor: isDark
                            ? const Color(0xFF1A2922)
                            : const Color(0xFFEBF7F0),
                      ),
                    ),
                  if (snap.bestAlly != null && snap.topDisruptor != null)
                    const SizedBox(width: 10),
                  if (snap.topDisruptor != null)
                    Expanded(
                      child: _HighlightTile(
                        title: s.triggerLabTopDisruptorLabel,
                        tagLabel: s.tagLabel(snap.topDisruptor!.tagKey),
                        accent: TronoColors.coral,
                        fillColor: isDark
                            ? const Color(0xFF2D1B1C)
                            : const Color(0xFFFDEEEE),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...snap.triggers.map((stat) {
              final isSelected = selected?.tagKey == stat.tagKey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TriggerRow(
                  key: ValueKey('trigger_row_${stat.tagKey}'),
                  stat: stat,
                  baselineBristol: snap.baselineBristol,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTagKey = stat.tagKey);
                  },
                ),
              );
            }),
            if (selected != null) ...[
              const SizedBox(height: 4),
              _TriggerInspector(
                stat: selected,
                baselineBristol: snap.baselineBristol,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.title,
    required this.tagLabel,
    required this.accent,
    required this.fillColor,
  });

  final String title;
  final String tagLabel;
  final Color accent;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            tagLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: TronoColors.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriggerRow extends StatelessWidget {
  const _TriggerRow({
    super.key,
    required this.stat,
    required this.baselineBristol,
    required this.isSelected,
    required this.onTap,
  });

  final TriggerStat stat;
  final double? baselineBristol;
  final bool isSelected;
  final VoidCallback onTap;

  Color _impactColor(BuildContext context) => switch (stat.impact) {
    TriggerImpact.ally => TronoColors.sage,
    TriggerImpact.softer => TronoColors.coral,
    TriggerImpact.firmer => TronoColors.terracotta,
    TriggerImpact.intense => TronoColors.coral,
    TriggerImpact.neutral => TronoColors.muted(context),
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final accent = _impactColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isSelected
        ? (isDark ? const Color(0xFF232834) : const Color(0xFFFDF7EE))
        : TronoColors.bg(context);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? TronoColors.terracotta
              : TronoColors.border(context),
          width: isSelected ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.tagLabel(stat.tagKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.ink(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stat.totalCount}×',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: TronoColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stat.bristolDelta != null &&
                      stat.bristolDelta!.abs() >= 0.1) ...[
                    Text(
                      '${stat.bristolDelta! >= 0 ? '+' : ''}${stat.bristolDelta!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.triggerImpactLabel(stat.impact),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (stat.avgBristol != null) ...[
                const SizedBox(height: 8),
                _MiniBristolBar(
                  avgBristol: stat.avgBristol!,
                  baselineBristol: baselineBristol,
                  dotColor: accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBristolBar extends StatelessWidget {
  const _MiniBristolBar({
    required this.avgBristol,
    required this.baselineBristol,
    required this.dotColor,
  });

  final double avgBristol;
  final double? baselineBristol;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final normAvg = ((avgBristol - 1.0) / 6.0).clamp(0.0, 1.0);
    final normBase = baselineBristol != null
        ? ((baselineBristol! - 1.0) / 6.0).clamp(0.0, 1.0)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Ideal Bristol 3..4 band spans [2/6, 3/6] of [1..7]
        final idealLeft = (2.0 / 6.0) * w;
        final idealWidth = (1.0 / 6.0) * w;

        return SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Track
              Container(
                height: 6,
                width: w,
                decoration: BoxDecoration(
                  color: TronoColors.border(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              // Ideal 3–4 band
              Positioned(
                left: idealLeft,
                width: idealWidth,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: TronoColors.sage.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              // Baseline vertical tick
              if (normBase != null)
                Positioned(
                  left: (normBase * (w - 2)).clamp(0.0, w - 2),
                  child: Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: TronoColors.muted(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Trigger average dot
              Positioned(
                left: (normAvg * (w - 12)).clamp(0.0, w - 12),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TronoColors.surface(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TriggerInspector extends StatelessWidget {
  const _TriggerInspector({
    required this.stat,
    required this.baselineBristol,
  });

  final TriggerStat stat;
  final double? baselineBristol;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TronoColors.border(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.tagLabel(stat.tagKey)} · ${s.poopsCountLabel(stat.totalCount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: TronoColors.ink(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (stat.avgBristol != null)
                _MetricPill(
                  emoji: '🎯',
                  text: baselineBristol != null
                      ? s.triggerLabBristolCompare(
                          stat.avgBristol!,
                          baselineBristol!,
                        )
                      : 'Bristol ${stat.avgBristol!.toStringAsFixed(1)}',
                )
              else
                _MetricPill(
                  emoji: '🎯',
                  text: s.triggerLabNoBristolYet,
                ),
              if (stat.idealRate != null)
                _MetricPill(
                  emoji: '✅',
                  text: s.idealBristolPctSub(stat.idealRate!),
                ),
              if (stat.urgentOrStruggledRate != null)
                _MetricPill(
                  emoji: '⚡',
                  text: s.triggerLabDifficultPct(stat.urgentOrStruggledRate!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.emoji, required this.text});

  final String emoji;
  final String text;

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
            fontWeight: FontWeight.w700,
            color: TronoColors.ink(context),
          ),
        ),
      ],
    );
  }
}
