import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/favorite_place.dart';
import '../models/stats_summary.dart';
import '../services/location_service.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/trono_toast.dart';

class FavoritePlacesScreen extends StatefulWidget {
  const FavoritePlacesScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final TronoController controller;
  final bool embedded;

  @override
  State<FavoritePlacesScreen> createState() => _FavoritePlacesScreenState();
}

class _FavoritePlacesScreenState extends State<FavoritePlacesScreen> {
  Future<void> _showAddFavoritePlaceDialog() async {
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController();
    String selectedEmoji = kFavoritePlaceEmojis.first;
    LocationKind selectedKind = LocationKind.work;
    bool capturing = false;
    String? errorMsg;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text(s.addFavoritePlaceTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: s.favoritePlaceNameLabel,
                        hintText: s.favoritePlaceNameHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.favoritePlaceEmojiLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: kFavoritePlaceEmojis.map((emoji) {
                          final active = emoji == selectedEmoji;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                selectedEmoji = emoji;
                                if (emoji == '🏠') {
                                  selectedKind = LocationKind.home;
                                } else if (emoji == '🏢') {
                                  selectedKind = LocationKind.work;
                                }
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active
                                    ? TronoColors.terracotta.withValues(
                                        alpha: 0.16,
                                      )
                                    : TronoColors.surface(ctx),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? TronoColors.terracotta
                                      : TronoColors.border(ctx),
                                  width: active ? 2.5 : 1.5,
                                ),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.favoritePlaceKindLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('🏠 ${s.quickHomeButton}'),
                            selected: selectedKind == LocationKind.home,
                            onSelected: (_) => setModalState(
                              () => selectedKind = LocationKind.home,
                            ),
                          ),
                          ChoiceChip(
                            label: Text('💼 ${s.quickWorkButton}'),
                            selected: selectedKind == LocationKind.work,
                            onSelected: (_) => setModalState(
                              () => selectedKind = LocationKind.work,
                            ),
                          ),
                          ChoiceChip(
                            label: Text('🌍 ${s.quickAwayButton}'),
                            selected: selectedKind == LocationKind.away,
                            onSelected: (_) => setModalState(
                              () => selectedKind = LocationKind.away,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: TronoColors.muted(ctx),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.favoritePlaceGpsNotice,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: TronoColors.muted(ctx),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: TronoColors.coral,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: capturing
                      ? null
                      : () => Navigator.of(ctx).pop(false),
                  child: Text(s.cancelTimer),
                ),
                FilledButton.icon(
                  onPressed: capturing
                      ? null
                      : () async {
                          final trimmed = nameCtrl.text.trim();
                          if (trimmed.isEmpty) return;
                          setModalState(() {
                            capturing = true;
                            errorMsg = null;
                          });
                          final pos =
                              await LocationService.requestAndGetPosition();
                          if (!ctx.mounted) return;
                          if (pos == null) {
                            setModalState(() {
                              capturing = false;
                              errorMsg = s.gpsUnavailableToast;
                            });
                            return;
                          }
                          await widget.controller.addFavoritePlace(
                            name: trimmed,
                            emoji: selectedEmoji,
                            locationKind: selectedKind,
                            latitude: pos.latitude,
                            longitude: pos.longitude,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(true);
                          }
                        },
                  icon: capturing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 17),
                  label: Text(s.saveButton),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();

    if (saved == true && mounted) {
      showTronoToast(context, s.favoritePlaceSavedToast);
    }
  }

  Future<void> _deletePlace(FavoritePlace place) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.lightImpact();
    await widget.controller.deleteFavoritePlace(place.id);
    if (!mounted) return;
    showTronoToastOnMessenger(
      messenger,
      s.favoritePlaceDeletedToast,
      actionLabel: s.undoAction,
      onAction: () => widget.controller.addFavoritePlace(
        name: place.name,
        emoji: place.emoji,
        locationKind: place.locationKind,
        latitude: place.latitude,
        longitude: place.longitude,
        radiusMeters: place.radiusMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final places = widget.controller.favoritePlaces;
        final topPlaces = widget.controller.topPlaces;
        final stats = widget.controller.stats;

        final content = ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            widget.embedded ? 4 : 8,
            16,
            32,
          ),
          children: [
            // Territory Home vs Away ratio summary
            _TerritorySummaryCard(stats: stats),
            const SizedBox(height: 16),

            // Primary CTA: Save current location
            ChunkyButton(
                width: double.infinity,
                color: TronoColors.terracotta,
                lipColor: TronoColors.terracottaLip,
                lipHeight: 5,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                onPressed: _showAddFavoritePlaceDialog,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_location_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.saveCurrentLocationButton.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section 1: Saved Favorite Places
              _SectionHeader(
                title: s.savedPlacesSectionTitle,
                count: places.length,
              ),
              const SizedBox(height: 10),
              if (places.isEmpty)
                ChunkyCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: TronoColors.terracotta.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.pin_drop_rounded,
                          color: TronoColors.terracotta,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.noFavoritePlacesTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.noFavoritePlacesBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...places.map(
                  (place) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FavoritePlaceCard(
                      place: place,
                      onDelete: () => _deletePlace(place),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Section 2: Top Baños ranking
              _SectionHeader(
                title: s.topBathroomsSectionTitle,
                count: topPlaces.length,
              ),
              const SizedBox(height: 10),
              if (topPlaces.isEmpty)
                ChunkyCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: TronoColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.star_rounded,
                          color: TronoColors.gold,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.noTopBathroomsTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.noTopBathroomsBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(topPlaces.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TopBathroomCard(
                      rank: index + 1,
                      stat: topPlaces[index],
                    ),
                  );
                }),
            ],
        );

        if (widget.embedded) return content;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              s.favoritePlacesTitle,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          body: content,
        );
      },
    );
  }
}

class _TerritorySummaryCard extends StatelessWidget {
  const _TerritorySummaryCard({required this.stats});

  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final hasRatio = stats.classifiedLocationCount > 0;
    final homePct = stats.homePercent.round();
    final awayPct = stats.awayPercent.round();

    return ChunkyCard(
      padding: const EdgeInsets.all(16),
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
                Text(
                  '📍 ${stats.distinctSpotsCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: TronoColors.terracotta,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
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
                Text(
                  '🏠 ${s.homeShort} $homePct%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '🌍 ${s.awayShort} $awayPct%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: TronoColors.terracotta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (homePct > 0)
                      Expanded(
                        flex: homePct,
                        child: Container(color: TronoColors.gold),
                      ),
                    if (awayPct > 0)
                      Expanded(
                        flex: awayPct,
                        child: Container(color: TronoColors.terracotta),
                      ),
                  ],
                ),
              ),
            ),
            if (stats.maxDistanceFromHomeKm >= 0.5) ...[
              const SizedBox(height: 8),
              Text(
                '🧭 ${s.farthestDropLabel(stats.maxDistanceFromHomeKm)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TronoColors.muted(context),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: TronoColors.muted(context),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: TronoColors.terracotta.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: TronoColors.terracotta,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FavoritePlaceCard extends StatelessWidget {
  const _FavoritePlaceCard({
    required this.place,
    required this.onDelete,
  });

  final FavoritePlace place;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ChunkyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: TronoColors.terracotta.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(place.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TronoColors.bg(context),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: TronoColors.border(context),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '${place.locationKind.emoji} ${s.locationKindName(place.locationKind)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: TronoColors.ink(context),
                        ),
                      ),
                    ),
                    Text(
                      s.radiusMetersLabel(place.radiusMeters.round()),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.deleteButton,
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: TronoColors.coral,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBathroomCard extends StatelessWidget {
  const _TopBathroomCard({
    required this.rank,
    required this.stat,
  });

  final int rank;
  final TopPlaceStat stat;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLeader = rank == 1;

    final badgeBg = isLeader
        ? TronoColors.gold
        : (rank <= 3
            ? TronoColors.terracotta.withValues(alpha: 0.16)
            : TronoColors.bg(context));
    final badgeFg = isLeader
        ? TronoColors.obsidian
        : (rank <= 3 ? TronoColors.terracotta : TronoColors.muted(context));

    return ChunkyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      borderColor: isLeader ? TronoColors.gold : null,
      lipColor: isLeader ? TronoColors.goldLip : null,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(11),
              border: isLeader
                  ? null
                  : Border.all(
                      color: TronoColors.border(context),
                      width: 1.2,
                    ),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: badgeFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: TronoColors.bg(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: TronoColors.border(context), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Text(stat.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.locationKind != null
                      ? '${s.placeVisitsCount(stat.visitCount)} · ${s.locationKindName(stat.locationKind!)}'
                      : s.placeVisitsCount(stat.visitCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: TronoColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (stat.averageRating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3A3014)
                    : const Color(0xFFFEF3D2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TronoColors.gold, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    stat.averageRating!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? TronoColors.gold
                          : const Color(0xFF694B05),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              s.unratedLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: TronoColors.muted(context),
              ),
            ),
        ],
      ),
    );
  }
}
