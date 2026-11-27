import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/group_challenges.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

/// Tactile Chunky 3D card showing the active group's 🔥 Group Streak
/// and 3 auto-scaled Weekly Challenges (computed 100% client-side).
class GroupChallengesCard extends StatelessWidget {
  const GroupChallengesCard({super.key, required this.snapshot});

  final GroupChallengesSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.challenges.isEmpty) return const SizedBox.shrink();

    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allDone = snapshot.allCompleted;
    final hasStreak = snapshot.groupStreakDays > 0;

    final goldSurface =
        isDark ? const Color(0xFF2B2618) : const Color(0xFFFFF8E6);

    return ChunkyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: allDone ? TronoColors.gold : TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.groupChallengesTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: allDone
                      ? (isDark
                          ? const Color(0xFF1A2922)
                          : const Color(0xFFEBF7F0))
                      : TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allDone
                        ? TronoColors.sage
                        : TronoColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${snapshot.completedCount}/${snapshot.totalCount}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: allDone
                        ? TronoColors.sage
                        : TronoColors.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                key: const ValueKey('group_streak_pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasStreak ? goldSurface : TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasStreak
                        ? TronoColors.gold
                        : TronoColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '🔥 ${s.groupStreakPill(snapshot.groupStreakDays)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: hasStreak
                        ? (isDark ? TronoColors.gold : TronoColors.obsidian)
                        : TronoColors.muted(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TronoColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '📅 ${s.groupActiveDaysLabel(snapshot.activeDaysThisWeek)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: TronoColors.muted(context),
                  ),
                ),
              ),
            ],
          ),
          if (allDone) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('challenges_all_done_banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: goldSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TronoColors.gold, width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.groupChallengesAllDoneTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? TronoColors.gold
                                : TronoColors.obsidian,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.groupChallengesAllDoneSub,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TronoColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...snapshot.challenges.asMap().entries.map((entry) {
            final idx = entry.key;
            final challenge = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: idx == snapshot.challenges.length - 1 ? 0 : 10,
              ),
              child: _ChallengeRow(
                key: ValueKey('challenge_row_${challenge.type.name}'),
                challenge: challenge,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({super.key, required this.challenge});

  final GroupChallenge challenge;

  String get _emoji => switch (challenge.type) {
    GroupChallengeType.teamVolume => '👑',
    GroupChallengeType.awaySquad => '🌍',
    GroupChallengeType.syncedDuo => '⚡',
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final done = challenge.isCompleted;
    final barColor = done ? TronoColors.sage : TronoColors.terracotta;
    final rowBg = done
        ? (isDark ? const Color(0xFF1A2922) : const Color(0xFFEBF7F0))
        : TronoColors.bg(context);
    final rowBorder = done
        ? TronoColors.sage.withValues(alpha: 0.5)
        : TronoColors.border(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rowBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_emoji, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.groupChallengeTitle(challenge.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: TronoColors.ink(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      s.groupChallengeSubtitle(
                        challenge.type,
                        challenge.target,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${challenge.current}/${challenge.target}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: done
                          ? TronoColors.sage
                          : TronoColors.ink(context),
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: TronoColors.sage,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * challenge.progress;
              return Container(
                height: 8,
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: TronoColors.border(context),
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
