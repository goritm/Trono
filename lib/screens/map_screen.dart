import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../services/location_service.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/log_detail_sheet.dart';
import '../widgets/log_tile.dart';

enum _MapFilter { all, thisMonth, awayOnly, workOnly, homeOnly }

class _PinCluster {
  _PinCluster({required this.center, required this.logs});

  final LatLng center;
  final List<BathroomLog> logs;

  bool get isMultiple => logs.length > 1;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  _MapFilter _filter = _MapFilter.all;
  _PinCluster? _selectedCluster;

  List<BathroomLog> _filteredLogs() {
    final now = DateTime.now();
    return widget.controller.geotaggedLogs.where((log) {
      return switch (_filter) {
        _MapFilter.all => true,
        _MapFilter.thisMonth =>
          log.timestamp.year == now.year && log.timestamp.month == now.month,
        _MapFilter.awayOnly =>
          log.effectiveLocationKind?.isAwayFromHome == true,
        _MapFilter.workOnly =>
          log.effectiveLocationKind == LocationKind.work,
        _MapFilter.homeOnly =>
          log.effectiveLocationKind == LocationKind.home,
      };
    }).toList();
  }

  List<_PinCluster> _buildClusters(List<BathroomLog> logs) {
    final clusters = <_PinCluster>[];
    for (final log in logs) {
      if (!log.hasCoordinates) continue;
      final lat = log.latitude!;
      final lng = log.longitude!;
      _PinCluster? match;
      for (final c in clusters) {
        final d = LocationService.distanceMeters(
          c.center.latitude,
          c.center.longitude,
          lat,
          lng,
        );
        if (d <= LocationService.distinctSpotRadiusMeters) {
          match = c;
          break;
        }
      }
      if (match != null) {
        match.logs.add(log);
      } else {
        clusters.add(_PinCluster(center: LatLng(lat, lng), logs: [log]));
      }
    }
    return clusters;
  }

  LatLng _initialCenter() {
    final geoLogs = widget.controller.geotaggedLogs;
    if (geoLogs.isNotEmpty) {
      return LatLng(geoLogs.first.latitude!, geoLogs.first.longitude!);
    }
    if (widget.controller.hasHomeLocation) {
      return LatLng(widget.controller.homeLat!, widget.controller.homeLng!);
    }
    return const LatLng(40.4168, -3.7038);
  }

  Future<void> _editLog(BathroomLog log) async {
    final s = AppStrings.of(context);
    final res = await showLogDetailSheet(
      context,
      mode: LogSheetMode.editExisting,
      initialLog: log,
      defaultShareLevel: widget.controller.defaultShareLevel,
    );
    if (res == null) return;
    if (res.deleted) {
      await widget.controller.deleteLog(log.id);
      if (mounted) {
        setState(() => _selectedCluster = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.logDeletedToast)),
        );
      }
    } else if (res.savedLog != null) {
      await widget.controller.saveLog(res.savedLog!);
      if (mounted) {
        setState(() => _selectedCluster = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final filtered = _filteredLogs();
        final clusters = _buildClusters(filtered);
        final stats = widget.controller.stats;
        final hasHome = widget.controller.hasHomeLocation;

        final markers = <Marker>[];

        if (hasHome) {
          markers.add(
            Marker(
              point: LatLng(
                widget.controller.homeLat!,
                widget.controller.homeLng!,
              ),
              width: 44,
              height: 44,
              child: Tooltip(
                message: s.homePinLabel,
                child: Container(
                  decoration: BoxDecoration(
                    color: TronoColors.obsidian,
                    shape: BoxShape.circle,
                    border: Border.all(color: TronoColors.gold, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home_rounded,
                    color: TronoColors.gold,
                    size: 22,
                  ),
                ),
              ),
            ),
          );
        }

        for (final cluster in clusters) {
          final isSelected = _selectedCluster != null &&
              _selectedCluster!.center == cluster.center;
          final leadLog = cluster.logs.first;
          final isAway = leadLog.effectiveLocationKind != LocationKind.home;

          markers.add(
            Marker(
              point: cluster.center,
              width: isSelected ? 52 : (cluster.isMultiple ? 46 : 40),
              height: isSelected ? 52 : (cluster.isMultiple ? 46 : 40),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCluster = cluster),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: isAway ? TronoColors.terracotta : TronoColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? TronoColors.obsidian : Colors.white,
                      width: isSelected ? 3.5 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: cluster.isMultiple
                      ? Text(
                          '${cluster.logs.length}',
                          style: TextStyle(
                            color: isAway ? Colors.white : TronoColors.obsidian,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        )
                      : Text(
                          leadLog.type.emoji,
                          style: TextStyle(fontSize: isSelected ? 22 : 18),
                        ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(s.mapScreenTitle),
            actions: [
              if (hasHome)
                IconButton(
                  tooltip: s.homePinLabel,
                  onPressed: () {
                    _mapController.move(
                      LatLng(
                        widget.controller.homeLat!,
                        widget.controller.homeLng!,
                      ),
                      14.5,
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter(),
                  initialZoom: filtered.isNotEmpty || hasHome ? 13.5 : 5.0,
                  onTap: (_, _) {
                    if (_selectedCluster != null) {
                      setState(() => _selectedCluster = null);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.trono.trono',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Top floating Counter + Filter Pills
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChunkyCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            color: TronoColors.terracotta,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.spotsConqueredLabel(clusters.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (stats.classifiedLocationCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: TronoColors.terracotta.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${stats.awayPercent.round()}% ${s.awayShort}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: TronoColors.terracotta,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterPill(
                            label: s.mapFilterAll,
                            selected: _filter == _MapFilter.all,
                            onTap: () => setState(() {
                              _filter = _MapFilter.all;
                              _selectedCluster = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterPill(
                            label: s.mapFilterMonth,
                            selected: _filter == _MapFilter.thisMonth,
                            onTap: () => setState(() {
                              _filter = _MapFilter.thisMonth;
                              _selectedCluster = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterPill(
                            label: s.mapFilterAway,
                            selected: _filter == _MapFilter.awayOnly,
                            onTap: () => setState(() {
                              _filter = _MapFilter.awayOnly;
                              _selectedCluster = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterPill(
                            label: s.mapFilterWork,
                            selected: _filter == _MapFilter.workOnly,
                            onTap: () => setState(() {
                              _filter = _MapFilter.workOnly;
                              _selectedCluster = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterPill(
                            label: s.mapFilterHome,
                            selected: _filter == _MapFilter.homeOnly,
                            onTap: () => setState(() {
                              _filter = _MapFilter.homeOnly;
                              _selectedCluster = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.controller.geotaggedLogs.isEmpty)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: ChunkyCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🗺️', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text(
                          s.mapEmptyTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.mapEmptyBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TronoColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Selected Single Pin or Multi-Visit Cluster Card
              if (_selectedCluster != null)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: _selectedCluster!.isMultiple
                      ? _ClusterListCard(
                          cluster: _selectedCluster!,
                          onEditLog: _editLog,
                          onDeleteLog: (log) async {
                            final s = AppStrings.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.controller.deleteLog(log.id);
                            if (mounted) {
                              setState(() => _selectedCluster = null);
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(s.logDeletedToast),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: s.undoAction,
                                    textColor: TronoColors.gold,
                                    onPressed: () =>
                                        widget.controller.saveLog(log),
                                  ),
                                ),
                              );
                            }
                          },
                          onClose: () =>
                              setState(() => _selectedCluster = null),
                        )
                      : _SelectedPinCard(
                          log: _selectedCluster!.logs.first,
                          homeLat: widget.controller.homeLat,
                          homeLng: widget.controller.homeLng,
                          onEdit: () => _editLog(_selectedCluster!.logs.first),
                          onClose: () =>
                              setState(() => _selectedCluster = null),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? TronoColors.terracotta
              : TronoColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? TronoColors.terracottaLip
                : TronoColors.border(context),
            width: 1.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : TronoColors.ink(context),
          ),
        ),
      ),
    );
  }
}

class _ClusterListCard extends StatelessWidget {
  const _ClusterListCard({
    required this.cluster,
    required this.onEditLog,
    required this.onDeleteLog,
    required this.onClose,
  });

  final _PinCluster cluster;
  final ValueChanged<BathroomLog> onEditLog;
  final ValueChanged<BathroomLog> onDeleteLog;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ChunkyCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                color: TronoColors.terracotta,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.clusterHeader(cluster.logs.length),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cluster.logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => LogTile(
                key: ValueKey(cluster.logs[i].id),
                log: cluster.logs[i],
                showDate: true,
                onTap: () => onEditLog(cluster.logs[i]),
                onDelete: () => onDeleteLog(cluster.logs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPinCard extends StatelessWidget {
  const _SelectedPinCard({
    required this.log,
    required this.homeLat,
    required this.homeLng,
    required this.onEdit,
    required this.onClose,
  });

  final BathroomLog log;
  final double? homeLat;
  final double? homeLng;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final loc = log.effectiveLocationKind;
    final dateStr = DateFormat(
      'EEE, d MMM · HH:mm',
      s.locale.languageCode,
    ).format(log.timestamp);

    String? distLabel;
    if (homeLat != null && homeLng != null && log.hasCoordinates) {
      final meters = LocationService.distanceMeters(
        homeLat!,
        homeLng!,
        log.latitude!,
        log.longitude!,
      );
      distLabel = meters < 1000
          ? '${meters.round()} m'
          : '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return ChunkyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(log.type.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.placeLabel?.trim().isNotEmpty == true
                          ? log.placeLabel!.trim()
                          : (loc != null
                              ? '${loc.emoji} ${s.locationKindName(loc)}'
                              : s.typeName(log.type)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      distLabel != null ? '$dateStr · $distLabel' : dateStr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TronoColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          if (log.bristolType != null ||
              log.durationSeconds != null ||
              (log.note != null && log.note!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (log.bristolType != null)
                  _Pill(s.bristolShort(log.bristolType!)),
                if (log.durationSeconds != null && log.durationSeconds! > 0)
                  _Pill(s.formatDuration(log.durationSeconds!)),
                if (loc != null) _Pill('${loc.emoji} ${s.locationKindName(loc)}'),
              ],
            ),
            if (log.note != null && log.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                log.note!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
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

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: TronoColors.bg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TronoColors.border(context), width: 1.2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
