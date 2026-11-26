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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  BathroomLog? _selectedLog;

  LatLng _initialCenter() {
    final geoLogs = widget.controller.geotaggedLogs;
    if (geoLogs.isNotEmpty) {
      return LatLng(geoLogs.first.latitude!, geoLogs.first.longitude!);
    }
    if (widget.controller.hasHomeLocation) {
      return LatLng(widget.controller.homeLat!, widget.controller.homeLng!);
    }
    // Neutral fallback (Madrid) when empty
    return const LatLng(40.4168, -3.7038);
  }

  Future<void> _editSelected(BathroomLog log) async {
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
        setState(() => _selectedLog = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.logDeletedToast)),
        );
      }
    } else if (res.savedLog != null) {
      await widget.controller.saveLog(res.savedLog!);
      if (mounted) {
        setState(() => _selectedLog = res.savedLog);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final geoLogs = widget.controller.geotaggedLogs;
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

        for (final log in geoLogs) {
          final isSelected = _selectedLog?.id == log.id;
          final isAway = log.effectiveLocationKind != LocationKind.home;
          markers.add(
            Marker(
              point: LatLng(log.latitude!, log.longitude!),
              width: isSelected ? 48 : 40,
              height: isSelected ? 48 : 40,
              child: GestureDetector(
                onTap: () => setState(() => _selectedLog = log),
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
                  child: Text(
                    log.type.emoji,
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
                  initialZoom: geoLogs.isNotEmpty || hasHome ? 13.5 : 5.0,
                  onTap: (_, _) {
                    if (_selectedLog != null) {
                      setState(() => _selectedLog = null);
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

              // Top floating Territory Counter Pill
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: ChunkyCard(
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
                          s.spotsConqueredLabel(stats.distinctSpotsCount),
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
              ),

              // Empty overlay when no GPS pins yet
              if (geoLogs.isEmpty)
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

              // Selected Pin Detail Card
              if (_selectedLog != null)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: _SelectedPinCard(
                    log: _selectedLog!,
                    homeLat: widget.controller.homeLat,
                    homeLng: widget.controller.homeLng,
                    onEdit: () => _editSelected(_selectedLog!),
                    onClose: () => setState(() => _selectedLog = null),
                  ),
                ),
            ],
          ),
        );
      },
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
