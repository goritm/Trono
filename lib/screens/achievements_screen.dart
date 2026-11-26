import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/achievement.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';

enum _BadgeFilter { all, unlocked, locked }

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final TronoController controller;
  final bool embedded;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  _BadgeFilter _filter = _BadgeFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final gam = widget.controller.gamification;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = gam.achievements.where((a) {
      return switch (_filter) {
        _BadgeFilter.all => true,
        _BadgeFilter.unlocked => a.isUnlocked,
        _BadgeFilter.locked => !a.isUnlocked,
      };
    }).toList()
      ..sort((a, b) {
        if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
        return b.progress.compareTo(a.progress);
      });

    final scroll = CustomScrollView(
      slivers: [
        if (!widget.embedded)
          SliverAppBar(
            floating: true,
            title: Text(s.achievementsTitle),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 4 : 6, 16, 28),
          sliver: SliverList.list(
            children: [
              // Sleek Obsidian 3D Rank Hero Card with Warm Gold Progress
              ChunkyCard(
                color: TronoColors.obsidian,
                borderColor: const Color(0xFF343B4D),
                lipColor: TronoColors.obsidianLip,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: TronoColors.gold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: TronoColors.gold.withValues(alpha: 0.7),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            gam.currentRank.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NIVEL ${gam.currentRank.level}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: TronoColors.gold,
                                ),
                              ),
                              Text(
                                s.rankName(gam.currentRank.id),
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${gam.totalXp} XP · ${gam.unlockedCount}/${gam.achievements.length} ${s.badgesTitle.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: gam.rankProgress,
                        minHeight: 11,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        color: TronoColors.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gam.nextRank == null
                                ? s.maxRankReached
                                : s.xpToNext(
                                    gam.nextRank!.minXp - gam.totalXp,
                                    s.rankName(gam.nextRank!.id),
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        Text(
                          '${gam.totalXp} XP',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: TronoColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rank Ladder Horizontal Strip
              Text(
                s.rankLadderTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: TronoColors.muted(context),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: GamificationEngine.ranks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final rank = GamificationEngine.ranks[idx];
                    final reached = gam.totalXp >= rank.minXp;
                    final isCurrent = gam.currentRank.level == rank.level;
                    return Container(
                      width: 120,
                      padding: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? TronoColors.goldLip
                            : TronoColors.lip(context),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? (isDark
                                  ? const Color(0xFF2B2618)
                                  : const Color(0xFFFFF8E6))
                              : TronoColors.surface(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isCurrent
                                ? TronoColors.gold
                                : TronoColors.border(context),
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: reached ? 1.0 : 0.42,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rank.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.rankName(rank.id),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${rank.minXp} XP',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: TronoColors.muted(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Badges Header & Filter
              Row(
                children: [
                  Text(
                    s.badgesTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: TronoColors.muted(context),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TronoColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${gam.unlockedCount}/${gam.achievements.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? TronoColors.gold : TronoColors.goldLip,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<_BadgeFilter>(
                segments: [
                  ButtonSegment(
                    value: _BadgeFilter.all,
                    label: Text(s.filterAll),
                  ),
                  ButtonSegment(
                    value: _BadgeFilter.unlocked,
                    label: Text(s.filterUnlocked),
                  ),
                  ButtonSegment(
                    value: _BadgeFilter.locked,
                    label: Text(s.filterLocked),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (set) => setState(() => _filter = set.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 14),

              // Clean 2-Column Badge Grid (Gold Unlocked / Muted Locked)
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) => _BadgeGridCard(
                  achievement: filtered[index],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return widget.embedded ? scroll : Scaffold(body: scroll);
  }
}

class _BadgeGridCard extends StatelessWidget {
  const _BadgeGridCard({required this.achievement});

  final AchievementProgress achievement;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final unlocked = achievement.isUnlocked;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChunkyCard(
      padding: const EdgeInsets.all(14),
      color: unlocked
          ? TronoColors.surface(context)
          : (isDark ? const Color(0xFF181B22) : const Color(0xFFEEEAE1)),
      borderColor: unlocked ? TronoColors.gold : TronoColors.border(context),
      lipColor: unlocked ? TronoColors.goldLip : TronoColors.lip(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unlocked
                    ? '✓ +${achievement.xpReward}'
                    : '+${achievement.xpReward} XP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: unlocked
                      ? (isDark ? TronoColors.gold : TronoColors.goldLip)
                      : TronoColors.muted(context),
                ),
              ),
              if (!unlocked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: TronoColors.muted(context),
                ),
            ],
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked
                  ? TronoColors.gold.withValues(alpha: 0.22)
                  : TronoColors.border(context).withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: unlocked ? TronoColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Opacity(
              opacity: unlocked ? 1.0 : 0.4,
              child: Text(
                achievement.emoji,
                style: const TextStyle(fontSize: 27),
              ),
            ),
          ),
          Column(
            children: [
              Text(
                s.achievementTitle(achievement.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: unlocked
                      ? TronoColors.ink(context)
                      : TronoColors.muted(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.achievementDesc(achievement.id),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: TronoColors.muted(context),
                ),
              ),
            ],
          ),
          if (!unlocked)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: achievement.progress,
                      minHeight: 6,
                      backgroundColor: TronoColors.border(context),
                      color: TronoColors.terracotta,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${achievement.current.clamp(0, achievement.target)}/${achievement.target}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: TronoColors.muted(context),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
