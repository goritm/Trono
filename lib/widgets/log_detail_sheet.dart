import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../models/favorite_place.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'trono_toast.dart';
import 'chunky_widgets.dart';

enum LogSheetMode {
  quickFollowUp,
  editExisting,
  createPast,
}

class LogDetailSheetResult {
  const LogDetailSheetResult({this.savedLog, this.deleted = false});

  final BathroomLog? savedLog;
  final bool deleted;
}

Future<LogDetailSheetResult?> showLogDetailSheet(
  BuildContext context, {
  required LogSheetMode mode,
  BathroomLog? initialLog,
  DateTime? initialDate,
  ShareLevel defaultShareLevel = ShareLevel.summaryOnly,
  List<FavoritePlace> favoritePlaces = const [],
}) {
  return showModalBottomSheet<LogDetailSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    backgroundColor: TronoColors.surface(context),
    barrierColor: Colors.black.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _LogDetailSheetBody(
      mode: mode,
      initialLog: initialLog,
      initialDate: initialDate,
      defaultShareLevel: defaultShareLevel,
      favoritePlaces: favoritePlaces,
    ),
  );
}

class _LogDetailSheetBody extends StatefulWidget {
  const _LogDetailSheetBody({
    required this.mode,
    this.initialLog,
    this.initialDate,
    required this.defaultShareLevel,
    this.favoritePlaces = const [],
  });

  final LogSheetMode mode;
  final BathroomLog? initialLog;
  final DateTime? initialDate;
  final ShareLevel defaultShareLevel;
  final List<FavoritePlace> favoritePlaces;

  @override
  State<_LogDetailSheetBody> createState() => _LogDetailSheetBodyState();
}

class _LogDetailSheetBodyState extends State<_LogDetailSheetBody> {
  late BathroomType _type;
  late DateTime _timestamp;
  int? _bristolType;
  PoopSize? _size;
  EffortLevel? _effort;
  int? _durationSeconds;
  StoolColor? _color;
  late Set<String> _tags;
  late TextEditingController _noteController;
  late TextEditingController _placeController;
  LocationKind? _locationKind;
  bool _isWfh = false;
  double? _latitude;
  double? _longitude;
  int? _rating;
  bool _capturingGps = false;
  late ShareLevel _shareLevel;

  static const _quickDurationSeconds = [60, 120, 300, 600, 900, 1200];

  @override
  void initState() {
    super.initState();
    final log = widget.initialLog;
    final now = DateTime.now();
    _type = log?.type ?? BathroomType.poop;
    if (log != null) {
      _timestamp = log.timestamp;
    } else if (widget.initialDate != null) {
      _timestamp = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
        now.hour,
        now.minute,
      );
    } else {
      _timestamp = now;
    }
    _bristolType = log?.bristolType;
    _size = log?.size;
    _effort = log?.effort;
    _durationSeconds = log?.durationSeconds;
    _color = log?.color;
    _tags = {...?log?.tags};
    _noteController = TextEditingController(text: log?.note ?? '');
    _placeController = TextEditingController(text: log?.placeLabel ?? '');
    _isWfh = log?.isWfh ?? false;
    _locationKind = log?.locationKind ?? (_isWfh ? LocationKind.home : null);
    _latitude = log?.latitude;
    _longitude = log?.longitude;
    _rating = log?.rating;
    _shareLevel = log?.shareLevel ?? widget.defaultShareLevel;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() => _capturingGps = true);
    final pos = await LocationService.requestAndGetPosition();
    if (!mounted) return;
    setState(() {
      _capturingGps = false;
      if (pos != null) {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        final matched = FavoritePlacesEngine.matchPlace(
          pos.latitude,
          pos.longitude,
          widget.favoritePlaces,
        );
        if (matched != null) {
          if (_placeController.text.trim().isEmpty) {
            _placeController.text = matched.name;
          }
          _locationKind ??= matched.locationKind;
        }
      }
    });
    if (pos == null) {
      showTronoToast(context, AppStrings.of(context).gpsUnavailableToast);
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _timestamp = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _saveAndClose() {
    final now = DateTime.now();
    final base = widget.initialLog;
    final finalTags = Set<String>.from(_tags);
    if (_isWfh) {
      finalTags.add(BathroomLog.wfhTag);
    } else {
      finalTags.remove(BathroomLog.wfhTag);
    }
    final finalLocationKind = _isWfh ? LocationKind.home : _locationKind;
    final result = BathroomLog(
      id: base?.id ?? const Uuid().v4(),
      type: _type,
      timestamp: _timestamp,
      bristolType: _type.includesPoop ? _bristolType : null,
      size: _type.includesPoop ? _size : null,
      effort: _effort,
      durationSeconds: _durationSeconds,
      color: _type.includesPoop ? _color : null,
      tags: finalTags.toList(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      locationKind: finalLocationKind,
      latitude: _latitude,
      longitude: _longitude,
      placeLabel: _placeController.text.trim().isEmpty
          ? null
          : _placeController.text.trim(),
      rating: _rating,
      shareLevel: _shareLevel,
      syncStatus: base?.syncStatus ?? SyncStatus.localOnly,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(LogDetailSheetResult(savedLog: result));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final title = switch (widget.mode) {
      LogSheetMode.quickFollowUp => s.quickDetailsTitle,
      LogSheetMode.editExisting => s.editLogTitle,
      LogSheetMode.createPast => s.pastLogTitle,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (widget.mode == LogSheetMode.quickFollowUp)
                            Text(
                              s.quickDetailsSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    if (widget.mode == LogSheetMode.quickFollowUp) ...[
                      IconButton(
                        tooltip: s.undoAction,
                        onPressed: () => Navigator.of(context).pop(
                          const LogDetailSheetResult(deleted: true),
                        ),
                        icon: Icon(
                          Icons.undo_rounded,
                          color: scheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.skipButton),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Type selector (always visible when creating past or editing)
                    if (widget.mode != LogSheetMode.quickFollowUp) ...[
                      _SectionLabel(s.typeField),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BathroomType.values.map((t) {
                          final selected = _type == t;
                          return ChoiceChip(
                            label: Text('${t.emoji} ${s.typeName(t)}'),
                            selected: selected,
                            onSelected: (_) => setState(() => _type = t),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(s.dateTimeField),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text(
                          DateFormat(
                            'EEE, d MMM yyyy · HH:mm',
                            s.locale.languageCode,
                          ).format(_timestamp),
                        ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // 1. Bristol Scale (first & fastest when logging poop)
                    if (_type.includesPoop) ...[
                      _SectionLabel(s.bristolField),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 7,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final b = index + 1;
                            final selected = _bristolType == b;
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() {
                                _bristolType = selected ? null : b;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 92,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? scheme.primary
                                        : Colors.transparent,
                                    width: 1.8,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.bristolEmoji(b),
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.bristolShort(b),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_bristolType != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          s.bristolHint(_bristolType!),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ],

                    // 2. Food & digestive triggers (moved right near the top!)
                    _SectionLabel(s.tagsField),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kDefaultQuickTags.map((tag) {
                        final selected = _tags.contains(tag);
                        return FilterChip(
                          label: Text(s.tagLabel(tag)),
                          selected: selected,
                          onSelected: (val) => setState(() {
                            if (val) {
                              _tags.add(tag);
                            } else {
                              _tags.remove(tag);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 3. Location: Home / WFH / Work / Away + GPS Pin + Place Label
                    _SectionLabel(s.locationField),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('🏠 ${s.quickHomeButton}'),
                          selected:
                              _locationKind == LocationKind.home && !_isWfh,
                          onSelected: (_) => setState(() {
                            final wasHome =
                                _locationKind == LocationKind.home && !_isWfh;
                            _isWfh = false;
                            _tags.remove(BathroomLog.wfhTag);
                            _locationKind = wasHome ? null : LocationKind.home;
                          }),
                        ),
                        ChoiceChip(
                          key: const ValueKey('location_chip_wfh'),
                          label: Text('💻 ${s.wfhLocationName}'),
                          selected: _isWfh,
                          onSelected: (_) => setState(() {
                            if (_isWfh) {
                              _isWfh = false;
                              _locationKind = null;
                              _tags.remove(BathroomLog.wfhTag);
                            } else {
                              _isWfh = true;
                              _locationKind = LocationKind.home;
                              _tags.add(BathroomLog.wfhTag);
                            }
                          }),
                        ),
                        ChoiceChip(
                          label: Text('💼 ${s.quickWorkButton}'),
                          selected:
                              _locationKind == LocationKind.work && !_isWfh,
                          onSelected: (_) => setState(() {
                            final wasWork =
                                _locationKind == LocationKind.work && !_isWfh;
                            _isWfh = false;
                            _tags.remove(BathroomLog.wfhTag);
                            _locationKind = wasWork ? null : LocationKind.work;
                          }),
                        ),
                        ChoiceChip(
                          label: Text('🌍 ${s.quickAwayButton}'),
                          selected:
                              _locationKind == LocationKind.away && !_isWfh,
                          onSelected: (_) => setState(() {
                            final wasAway =
                                _locationKind == LocationKind.away && !_isWfh;
                            _isWfh = false;
                            _tags.remove(BathroomLog.wfhTag);
                            _locationKind = wasAway ? null : LocationKind.away;
                          }),
                        ),
                        if (_latitude != null && _longitude != null)
                          InputChip(
                            avatar: const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: TronoColors.terracotta,
                            ),
                            label: Text(s.gpsPinnedLabel),
                            onDeleted: () => setState(() {
                              _latitude = null;
                              _longitude = null;
                            }),
                          )
                        else
                          ActionChip(
                            avatar: _capturingGps
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 16),
                            label: Text(s.captureGpsButton),
                            onPressed: _capturingGps ? null : _captureGps,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.favoritePlaces.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.favoritePlaces.map((place) {
                          final selected = _placeController.text
                                  .trim()
                                  .toLowerCase() ==
                              place.name.trim().toLowerCase();
                          return ChoiceChip(
                            label: Text('${place.emoji} ${place.name}'),
                            selected: selected,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _placeController.text = place.name;
                                _locationKind = place.locationKind;
                                if (place.locationKind != LocationKind.home) {
                                  _isWfh = false;
                                  _tags.remove(BathroomLog.wfhTag);
                                }
                                _latitude = place.latitude;
                                _longitude = place.longitude;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: _placeController,
                      onChanged: (_) {
                        if (widget.favoritePlaces.isNotEmpty) {
                          setState(() {});
                        }
                      },
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: s.placeNamePlaceholder,
                        prefixIcon: const Icon(Icons.place_outlined, size: 18),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3.5 Bathroom Rating (1–5 ⭐)
                    _SectionLabel(
                      _rating != null
                          ? '${s.bathroomRatingField} · ${s.ratingLabel(_rating!)}'
                          : s.bathroomRatingField,
                    ),
                    const SizedBox(height: 8),
                    _StarRatingPicker(
                      rating: _rating,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = value);
                      },
                    ),
                    const SizedBox(height: 18),

                    // 4. Size
                    if (_type.includesPoop) ...[
                      _SectionLabel(s.sizeField),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PoopSize.values.map((sz) {
                          final selected = _size == sz;
                          return ChoiceChip(
                            label: Text('${sz.emoji} ${s.sizeName(sz)}'),
                            selected: selected,
                            onSelected: (_) => setState(() {
                              _size = selected ? null : sz;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Effort / Feeling
                    _SectionLabel(s.effortField),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: EffortLevel.values.map((ef) {
                        final selected = _effort == ef;
                        return ChoiceChip(
                          label: Text('${ef.emoji} ${s.effortName(ef)}'),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _effort = selected ? null : ef;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Duration
                    _SectionLabel(
                      _durationSeconds != null
                          ? '${s.durationField} · ${s.formatDuration(_durationSeconds!)}'
                          : s.durationField,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickDurationSeconds.map((secs) {
                        final selected = _durationSeconds == secs;
                        return ChoiceChip(
                          label: Text(s.formatDuration(secs)),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _durationSeconds = selected ? null : secs;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Color (when poop or both)
                    if (_type.includesPoop) ...[
                      _SectionLabel(s.colorField),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: StoolColor.values.map((c) {
                          final selected = _color == c;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() {
                              _color = selected ? null : c;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: c.swatch,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    s.colorName(c),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Free note
                    _SectionLabel(s.noteField),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: s.notePlaceholder,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // V2 Privacy toggle
                    _SectionLabel(s.privacyField),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ShareLevel.values.map((lvl) {
                        return ChoiceChip(
                          label: Text(s.shareLevelName(lvl)),
                          selected: _shareLevel == lvl,
                          onSelected: (_) => setState(() => _shareLevel = lvl),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Bottom action bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.mode == LogSheetMode.editExisting) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(
                          const LogDetailSheetResult(deleted: true),
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: scheme.error,
                          size: 18,
                        ),
                        label: Text(
                          s.deleteButton,
                          style: TextStyle(color: scheme.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ChunkyButton(
                        color: TronoColors.terracotta,
                        lipColor: TronoColors.terracottaLip,
                        lipHeight: 4,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: _saveAndClose,
                        child: Center(
                          child: Text(
                            (widget.mode == LogSheetMode.quickFollowUp
                                    ? s.doneButton
                                    : s.saveButton)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StarRatingPicker extends StatelessWidget {
  const _StarRatingPicker({
    required this.rating,
    required this.onChanged,
  });

  final int? rating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: List.generate(5, (index) {
        final star = index + 1;
        final filled = rating != null && star <= rating!;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(rating == star ? null : star),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 46,
                decoration: BoxDecoration(
                  color: filled
                      ? (isDark
                          ? const Color(0xFF3A3014)
                          : const Color(0xFFFEF3D2))
                      : TronoColors.bg(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: filled
                        ? TronoColors.gold
                        : TronoColors.border(context),
                    width: filled ? 2 : 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled
                      ? TronoColors.gold
                      : TronoColors.muted(context),
                  size: 26,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
