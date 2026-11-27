import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/insights.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';

class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  final _cardKey = GlobalKey();
  WrappedPeriod _period = WrappedPeriod.thisMonth;
  bool _showEarnings = true;
  bool _sharing = false;

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(dir.path, 'trono_wrapped_$stamp.png'));
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '👑 Trono Wrapped',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final wrapped = widget.controller.buildWrapped(_period);
    final gam = widget.controller.gamification;
    final symbol = widget.controller.currencySymbol;
    final now = DateTime.now();
    final periodLabel = _period == WrappedPeriod.thisMonth
        ? DateFormat('MMMM yyyy', s.locale.languageCode)
            .format(now)
            .toUpperCase()
        : s.wrappedAllTime.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(s.wrappedTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<WrappedPeriod>(
            segments: [
              ButtonSegment(
                value: WrappedPeriod.thisMonth,
                label: Text(s.wrappedThisMonth),
              ),
              ButtonSegment(
                value: WrappedPeriod.allTime,
                label: Text(s.wrappedAllTime),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (set) => setState(() => _period = set.first),
            showSelectedIcon: false,
          ),
          if (wrapped.earnedAtWork > 0) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                s.showEarningsToggle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              value: _showEarnings,
              onChanged: (v) => setState(() => _showEarnings = v),
            ),
          ] else
            const SizedBox(height: 16),

          // Shareable Poster Card
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF191C24), Color(0xFF262B38)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: TronoColors.gold.withValues(alpha: 0.45),
                  width: 2.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: TronoColors.terracotta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          periodLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${gam.currentRank.emoji} ${s.levelBadge(gam.currentRank.level)}',
                        style: const TextStyle(
                          color: TronoColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    s.archetypeTitle(wrapped.archetype.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.rankName(gam.currentRank.id),
                    style: TextStyle(
                      color: TronoColors.gold.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 2x2 Big Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _WrappedStatBox(
                          overrideLabel: 'PUPÚS',
                          value: '${wrapped.totalPoops}',
                          accent: TronoColors.terracotta,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WrappedStatBox(
                          overrideLabel: s.dailyAvgLabel.toUpperCase(),
                          value: wrapped.avgPerDay.toStringAsFixed(1),
                          accent: TronoColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _WrappedStatBox(
                          overrideLabel: wrapped.hasLocationRatio
                              ? '🌍 ${s.awayShort.toUpperCase()}'
                              : s.peakHoursTitle.toUpperCase(),
                          value: wrapped.hasLocationRatio
                              ? '${wrapped.awayPercent}%'
                              : (wrapped.peakHour != null
                                  ? '${wrapped.peakHour!.toString().padLeft(2, '0')}:00'
                                  : '—'),
                          accent: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WrappedStatBox(
                          overrideLabel: s.totalTimeLabel.toUpperCase(),
                          value: wrapped.totalSeconds > 0
                              ? s.formatDuration(wrapped.totalSeconds)
                              : '—',
                          accent: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  if (wrapped.earnedAtWork > 0 && _showEarnings) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: TronoColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: TronoColors.gold.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('💰', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.paidThroneTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            '$symbol${wrapped.earnedAtWork.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: TronoColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (wrapped.topBristol != null)
                        _FooterChip(
                          '${s.bristolEmoji(wrapped.topBristol!)} Bristol ${wrapped.topBristol}',
                        ),
                      if (wrapped.distinctSpots > 0) ...[
                        const SizedBox(width: 8),
                        _FooterChip('🗺️ ${wrapped.distinctSpots}'),
                      ],
                      const Spacer(),
                      Text(
                        s.wrappedFooter,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          ChunkyButton(
            width: double.infinity,
            color: TronoColors.terracotta,
            lipColor: TronoColors.terracottaLip,
            lipHeight: 5,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: _sharing ? null : _shareCard,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sharing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  s.shareWrappedButton.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
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

class _WrappedStatBox extends StatelessWidget {
  const _WrappedStatBox({
    required this.overrideLabel,
    required this.value,
    required this.accent,
  });

  final String overrideLabel;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overrideLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  const _FooterChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
