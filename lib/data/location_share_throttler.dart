import 'dart:math' as math;

class LocationShareThrottler {
  LocationShareThrottler({
    this.minimumDisplacementMeters = 5,
    this.minimumInterval = const Duration(milliseconds: 1000),
    this.maximumPlausibleSpeedMetersPerSecond = 100,
  }) : assert(minimumDisplacementMeters >= 0),
       assert(minimumInterval >= Duration.zero),
       assert(maximumPlausibleSpeedMetersPerSecond > 0);

  final double minimumDisplacementMeters;
  final Duration minimumInterval;
  final double maximumPlausibleSpeedMetersPerSecond;
  double? _lastLatitude;
  double? _lastLongitude;
  DateTime? _lastSentAt;

  bool shouldTransmit({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }
    final previousAt = _lastSentAt;
    if (previousAt == null) {
      _remember(latitude, longitude, timestamp);
      return true;
    }
    if (!timestamp.isAfter(previousAt)) return false;
    final elapsed = timestamp.difference(previousAt);
    final displacement = _distanceMeters(
      _lastLatitude!,
      _lastLongitude!,
      latitude,
      longitude,
    );
    final maximumPlausibleDistance = math.max(
      30,
      elapsed.inMicroseconds /
          Duration.microsecondsPerSecond *
          maximumPlausibleSpeedMetersPerSecond,
    );
    if (displacement > maximumPlausibleDistance) return false;
    if (elapsed < minimumInterval && displacement < minimumDisplacementMeters) {
      return false;
    }
    _remember(latitude, longitude, timestamp);
    return true;
  }

  void reset() {
    _lastLatitude = null;
    _lastLongitude = null;
    _lastSentAt = null;
  }

  void _remember(double latitude, double longitude, DateTime timestamp) {
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastSentAt = timestamp;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371008.8;
    final firstLat = lat1 * math.pi / 180;
    final secondLat = lat2 * math.pi / 180;
    final deltaLat = (lat2 - lat1) * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(firstLat) *
            math.cos(secondLat) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
