import '../services/location_service.dart';
import 'bathroom_log.dart';

const List<String> kFavoritePlaceEmojis = [
  '🏢',
  '🏋️',
  '🏠',
  '☕',
  '🍻',
  '🛍️',
  '✈️',
  '🎓',
  '🏥',
  '🌳',
];

/// A locally-stored favorite bathroom spot used for silent GPS auto-labeling
/// and 1-tap quick picks. Coordinates NEVER leave the device.
class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.name,
    required this.emoji,
    required this.locationKind,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final LocationKind locationKind;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;

  FavoritePlace copyWith({
    String? id,
    String? name,
    String? emoji,
    LocationKind? locationKind,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    DateTime? createdAt,
  }) {
    return FavoritePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      locationKind: locationKind ?? this.locationKind,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'locationKind': locationKind.dbValue,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: (json['emoji'] as String?)?.trim().isNotEmpty == true
          ? json['emoji'] as String
          : '📍',
      locationKind:
          LocationKind.fromDb(json['locationKind']?.toString()) ??
          LocationKind.away,
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : (double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0),
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : (double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0),
      radiusMeters: (json['radiusMeters'] is num)
          ? (json['radiusMeters'] as num).toDouble()
          : (double.tryParse(json['radiusMeters']?.toString() ?? '') ?? 150.0),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Aggregated statistics for a named bathroom spot across local logs.
class TopPlaceStat {
  const TopPlaceStat({
    required this.name,
    required this.emoji,
    required this.visitCount,
    required this.ratedCount,
    required this.averageRating,
    required this.locationKind,
  });

  final String name;
  final String emoji;
  final int visitCount;
  final int ratedCount;
  final double? averageRating;
  final LocationKind? locationKind;
}

class _PlaceAccumulator {
  _PlaceAccumulator({required this.displayName});

  String displayName;
  int visitCount = 0;
  int ratedCount = 0;
  int ratingSum = 0;
  final Map<LocationKind, int> kindCounts = {};
}

/// Pure helpers for geofence matching and Top Bathrooms ranking.
class FavoritePlacesEngine {
  /// Returns the closest [FavoritePlace] whose [FavoritePlace.radiusMeters]
  /// contains `(lat, lng)`, or `null` if none match.
  static FavoritePlace? matchPlace(
    double lat,
    double lng,
    List<FavoritePlace> places,
  ) {
    FavoritePlace? closest;
    double closestDistance = double.infinity;

    for (final place in places) {
      final dist = LocationService.distanceMeters(
        lat,
        lng,
        place.latitude,
        place.longitude,
      );
      if (dist <= place.radiusMeters && dist < closestDistance) {
        closest = place;
        closestDistance = dist;
      }
    }

    return closest;
  }

  /// Groups all logs that have a non-empty `placeLabel` (case-insensitive,
  /// trimmed), enriches with matching [FavoritePlace] metadata when available,
  /// and sorts by `visitCount DESC, averageRating DESC`.
  static List<TopPlaceStat> computeTopPlaces(
    List<BathroomLog> logs,
    List<FavoritePlace> places,
  ) {
    final favoriteByKey = <String, FavoritePlace>{};
    for (final place in places) {
      final key = place.name.trim().toLowerCase();
      if (key.isNotEmpty) {
        favoriteByKey.putIfAbsent(key, () => place);
      }
    }

    final grouped = <String, _PlaceAccumulator>{};

    for (final log in logs) {
      final rawLabel = log.placeLabel?.trim() ?? '';
      if (rawLabel.isEmpty) continue;
      final key = rawLabel.toLowerCase();

      final acc = grouped.putIfAbsent(
        key,
        () => _PlaceAccumulator(
          displayName: favoriteByKey[key]?.name.trim() ?? rawLabel,
        ),
      );
      acc.visitCount += 1;

      final rating = log.rating;
      if (rating != null && rating >= 1 && rating <= 5) {
        acc.ratedCount += 1;
        acc.ratingSum += rating;
      }

      final kind = log.effectiveLocationKind;
      if (kind != null) {
        acc.kindCounts[kind] = (acc.kindCounts[kind] ?? 0) + 1;
      }
    }

    final stats = grouped.entries.map((entry) {
      final key = entry.key;
      final acc = entry.value;
      final fav = favoriteByKey[key];

      LocationKind? inferredKind = fav?.locationKind;
      if (inferredKind == null && acc.kindCounts.isNotEmpty) {
        inferredKind = acc.kindCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }

      final emoji = fav?.emoji ?? inferredKind?.emoji ?? '📍';
      final avgRating =
          acc.ratedCount > 0 ? acc.ratingSum / acc.ratedCount : null;

      return TopPlaceStat(
        name: acc.displayName,
        emoji: emoji,
        visitCount: acc.visitCount,
        ratedCount: acc.ratedCount,
        averageRating: avgRating,
        locationKind: inferredKind,
      );
    }).toList();

    stats.sort((a, b) {
      final visitCmp = b.visitCount.compareTo(a.visitCount);
      if (visitCmp != 0) return visitCmp;

      final aRating = a.averageRating ?? -1.0;
      final bRating = b.averageRating ?? -1.0;
      final ratingCmp = bRating.compareTo(aRating);
      if (ratingCmp != 0) return ratingCmp;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return stats;
  }
}
