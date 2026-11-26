import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';
import 'confetti_overlay.dart';

Future<void> showUnlockCelebrationIfNeeded(
  BuildContext context,
  UnlockEvent event,
) async {
  if (!event.hasAnything || !context.mounted) return;
  final s = AppStrings.of(context);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Dialog(
            backgroundColor: TronoColors.surface(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: TronoColors.border(ctx), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (event.newRank != null) ...[
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: TronoColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: TronoColors.gold, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        event.newRank!.emoji,
                        style: const TextStyle(fontSize: 38),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.rankUpTitle.toUpperCase(),
                      style: const TextStyle(
                        color: TronoColors.terracotta,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.rankName(event.newRank!.id),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (event.newAchievements.isNotEmpty)
                      const Divider(height: 28),
                  ],
                  if (event.newAchievements.isNotEmpty) ...[
                    Text(
                      s.unlockedCelebrationTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...event.newAchievements.map(
                      (a) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TronoColors.bg(ctx),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: TronoColors.border(ctx),
                            width: 1.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(a.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.achievementTitle(a.id),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    s.achievementDesc(a.id),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: TronoColors.muted(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: TronoColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${a.xpReward} XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: TronoColors.goldLip,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ChunkyButton(
                    width: double.infinity,
                    color: TronoColors.terracotta,
                    lipColor: TronoColors.terracottaLip,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Center(
                      child: Text(
                        s.awesomeButton.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: ConfettiBurstOverlay(),
          ),
        ],
      );
    },
  );
}
