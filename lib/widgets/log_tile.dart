import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

class LogTile extends StatelessWidget {
  const LogTile({
    super.key,
    required this.log,
    required this.onTap,
    this.showDate = false,
  });

  final BathroomLog log;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isPoop = log.type == BathroomType.poop;
    final accent = isPoop ? TronoColors.terracotta : TronoColors.muted(context);
    final timeStr = showDate
        ? DateFormat('d MMM · HH:mm', s.locale.languageCode).format(log.timestamp)
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

    return ChunkyCard(
      onTap: onTap,
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
                ? const Text('💩', style: TextStyle(fontSize: 22))
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
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .map(
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
                        )
                        .toList(),
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
  }
}
