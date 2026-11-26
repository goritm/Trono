import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/bathroom_log.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class LocationService {
  static const double homeRadiusMeters = 150.0;
  static const double distinctSpotRadiusMeters = 100.0;

  /// Pure Haversine distance in meters between two lat/lng coordinates.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);

  /// Classifies a coordinate as Home or Away given saved Home coordinates.
  static LocationKind? classifyAgainstHome(
    double lat,
    double lng, {
    double? homeLat,
    double? homeLng,
  }) {
    if (homeLat == null || homeLng == null) return null;
    final dist = distanceMeters(lat, lng, homeLat, homeLng);
    return dist <= homeRadiusMeters ? LocationKind.home : LocationKind.away;
  }

  /// Counts unique geotagged locations (clustered within [distinctSpotRadiusMeters]).
  static int countDistinctSpots(Iterable<BathroomLog> logs) {
    final centers = <GeoPoint>[];
    for (final log in logs) {
      if (!log.hasCoordinates) continue;
      final lat = log.latitude!;
      final lng = log.longitude!;
      final alreadyCounted = centers.any(
        (c) => distanceMeters(c.latitude, c.longitude, lat, lng) <=
            distinctSpotRadiusMeters,
      );
      if (!alreadyCounted) {
        centers.add(GeoPoint(lat, lng));
      }
    }
    return centers.length;
  }

  /// Checks if permission is already granted and fetches position WITHOUT prompting.
  static Future<GeoPoint?> tryGetPositionSilently() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return null;
      }
      return await _fetchFastPosition();
    } catch (_) {
      return null;
    }
  }

  /// Requests permission if needed (used when user explicitly taps "Set Home" or "Use GPS").
  static Future<GeoPoint?> requestAndGetPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return null;
      }
      return await _fetchFastPosition();
    } catch (_) {
      return null;
    }
  }

  static Future<GeoPoint?> _fetchFastPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return GeoPoint(last.latitude, last.longitude);
    }
  }
}
