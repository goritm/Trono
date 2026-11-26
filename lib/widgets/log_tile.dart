import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

class LogTile extends StatefulWidget {
  const LogTile({
    super.key,
    required this.log,
    required this.onTap,
    this.onDelete,
    this.showDate = false,
  });

  final BathroomLog log;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showDate;

  @override
  State<LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<LogTile> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 124.0;

  late final AnimationController _slideCtrl;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _slideCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  void _open() {
    HapticFeedback.selectionClick();
    _slideCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onDelete == null) return;
    _isDragging = true;
    final delta = -details.primaryDelta! / _actionWidth;
    _slideCtrl.value = (_slideCtrl.value + delta).clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity < -260) {
      _open();
    } else if (velocity > 260) {
      _close();
    } else if (_slideCtrl.value >= 0.42) {
      _open();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final log = widget.log;
    final isPoop = log.type == BathroomType.poop;
    final accent = isPoop ? TronoColors.terracotta : TronoColors.muted(context);
    final timeStr = widget.showDate
        ? DateFormat('d MMM · HH:mm', s.locale.languageCode)
            .format(log.timestamp)
        : DateFormat('HH:mm').format(log.timestamp);

    final chips = <String>[];
    final loc = log.effectiveLocationKind;
    if (log.placeLabel != null && log.placeLabel!.trim().isNotEmpty) {
      chips.add('${loc?.emoji ?? '📍'} ${log.placeLabel!.trim()}');
    } else if (loc != null) {
      chips.add('${loc.emoji} ${s.locationKindName(loc)}');
    } else if (log.hasCoordinates) {
      chips.add('📍 GPS');
    }
    if (log.bristolType != null) {
      chips.add(s.bristolShort(log.bristolType!));
    }
    if (log.size != null) {
      chips.add(s.sizeName(log.size!));
    }
    if (log.effort != null) {
      chips.add(s.effortName(log.effort!));
    }
    if (log.durationSeconds != null && log.durationSeconds! > 0) {
      chips.add(s.formatDuration(log.durationSeconds!));
    }
    for (final tag in log.tags.take(3)) {
      chips.add(s.tagLabel(tag));
    }

    final card = ChunkyCard(
      onTap: () {
        if (_slideCtrl.value > 0.05) {
          _close();
        } else {
          widget.onTap();
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: isPoop
                ? const Text('👑', style: TextStyle(fontSize: 22))
                : Icon(Icons.air_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.typeName(log.type),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    if (log.color != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: log.color!.swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TronoColors.border(context),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: TronoColors.muted(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (chips.isNotEmpty || log.rating != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (log.rating != null)
                        _RatingPill(rating: log.rating!),
                      ...chips.map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: TronoColors.bg(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: TronoColors.border(context),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: TronoColors.ink(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (log.note != null && log.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    log.note!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: TronoColors.muted(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.onDelete == null) return card;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Revealed right-side drawer actions (Edit + Delete) — 100% hidden when closed
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _slideCtrl,
              builder: (context, child) {
                final t = _slideCtrl.value;
                if (t <= 0.01) return const SizedBox.shrink();
                return Opacity(
                  opacity: (t * 2.4).clamp(0.0, 1.0),
                  child: IgnorePointer(ignoring: t < 0.25, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 2, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DrawerActionBtn(
                      icon: Icons.edit_rounded,
                      color: TronoColors.obsidian,
                      iconColor: TronoColors.gold,
                      tooltip: s.editLogTitle,
                      onTap: () {
                        _close();
                        widget.onTap();
                      },
                    ),
                    const SizedBox(width: 8),
                    _DrawerActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: TronoColors.coral,
                      iconColor: Colors.white,
                      tooltip: s.deleteButton,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _close();
                        widget.onDelete?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sliding foreground card
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-_slideCtrl.value * _actionWidth, 0),
                child: child,
              );
            },
            child: card,
          ),
        ],
      ),
    );
  }
}

class _DrawerActionBtn extends StatelessWidget {
  const _DrawerActionBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 54,
            height: double.infinity,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3014) : const Color(0xFFFEF3D2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TronoColors.gold, width: 1.3),
      ),
      child: Text(
        '⭐ $rating',
        style: TextStyle(
          fontSize: 11.5,
          color: isDark ? TronoColors.gold : const Color(0xFF694B05),
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
