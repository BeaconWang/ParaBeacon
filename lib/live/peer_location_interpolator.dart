import 'dart:math' as math;

class InterpolatedPeerPosition {
  const InterpolatedPeerPosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class PeerLocationInterpolator {
  PeerLocationInterpolator({
    this.interpolationDuration = const Duration(milliseconds: 300),
  });

  static const _maxPrediction = Duration(seconds: 3);
  static const _earthMetersPerDegree = 111111.0;

  final Duration interpolationDuration;
  double? _fromLatitude;
  double? _fromLongitude;
  double? _targetLatitude;
  double? _targetLongitude;
  DateTime? _targetTimestamp;
  DateTime? _animationStartedAt;
  double? _speedMetersPerSecond;
  double? _headingDegrees;
  double? _animationEndLatitude;
  double? _animationEndLongitude;

  void update({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? speedMetersPerSecond,
    double? headingDegrees,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (speedMetersPerSecond != null &&
            (!speedMetersPerSecond.isFinite || speedMetersPerSecond < 0)) ||
        (headingDegrees != null && !headingDegrees.isFinite)) {
      return;
    }
    final currentTimestamp = _targetTimestamp;
    if (currentTimestamp != null && !timestamp.isAfter(currentTimestamp)) {
      return;
    }

    final now = DateTime.now();
    final current = positionAt(now);
    _fromLatitude = current?.latitude ?? latitude;
    _fromLongitude = current?.longitude ?? longitude;
    _targetLatitude = latitude;
    _targetLongitude = longitude;
    _targetTimestamp = timestamp.toUtc();
    _speedMetersPerSecond = speedMetersPerSecond?.clamp(0, 100).toDouble();
    _headingDegrees = headingDegrees == null
        ? null
        : ((headingDegrees % 360) + 360) % 360;
    _animationStartedAt = now;
    final animationEnd = now.add(interpolationDuration);
    final predictedEnd = _predict(animationEnd);
    _animationEndLatitude = predictedEnd.latitude;
    _animationEndLongitude = predictedEnd.longitude;
  }

  InterpolatedPeerPosition? positionAt(DateTime now) {
    final latitude = _targetLatitude;
    final longitude = _targetLongitude;
    final timestamp = _targetTimestamp;
    if (latitude == null || longitude == null || timestamp == null) return null;

    final startedAt = _animationStartedAt;
    final duration = interpolationDuration;
    if (startedAt != null && duration > Duration.zero) {
      final progress =
          now.difference(startedAt).inMicroseconds / duration.inMicroseconds;
      if (progress < 1) {
        final t = progress.clamp(0, 1).toDouble();
        return InterpolatedPeerPosition(
          latitude: _lerp(
            _fromLatitude ?? latitude,
            _animationEndLatitude ?? latitude,
            t,
          ),
          longitude: _lerpLongitude(
            _fromLongitude ?? longitude,
            _animationEndLongitude ?? longitude,
            t,
          ),
        );
      }
    }
    return _predict(now);
  }

  bool needsAnimationAt(DateTime now) {
    final timestamp = _targetTimestamp;
    if (timestamp == null) return false;
    final startedAt = _animationStartedAt;
    if (startedAt != null &&
        interpolationDuration > Duration.zero &&
        now.difference(startedAt) < interpolationDuration) {
      return true;
    }
    final speed = _speedMetersPerSecond;
    return _headingDegrees != null &&
        speed != null &&
        speed > 0 &&
        !now.isBefore(timestamp) &&
        now.difference(timestamp) < _maxPrediction;
  }

  InterpolatedPeerPosition _predict(DateTime now) {
    final latitude = _targetLatitude!;
    final longitude = _targetLongitude!;
    final heading = _headingDegrees;
    final speed = _speedMetersPerSecond;
    final timestamp = _targetTimestamp!;
    if (heading == null ||
        speed == null ||
        speed == 0 ||
        now.isBefore(timestamp)) {
      return InterpolatedPeerPosition(latitude: latitude, longitude: longitude);
    }
    final elapsed = now.difference(timestamp);
    final seconds = math.min(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      _maxPrediction.inSeconds.toDouble(),
    );
    final distance = speed * seconds;
    final radians = heading * math.pi / 180;
    final nextLatitude =
        (latitude + distance * math.cos(radians) / _earthMetersPerDegree)
            .clamp(-90, 90)
            .toDouble();
    final cosine = math.cos(latitude * math.pi / 180).abs().clamp(0.01, 1.0);
    final nextLongitude = _normalizeLongitude(
      longitude +
          distance * math.sin(radians) / (_earthMetersPerDegree * cosine),
    );
    return InterpolatedPeerPosition(
      latitude: nextLatitude,
      longitude: nextLongitude,
    );
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;

  double _lerpLongitude(double start, double end, double t) {
    final delta = ((end - start + 540) % 360) - 180;
    return _normalizeLongitude(start + delta * t);
  }

  double _normalizeLongitude(double longitude) =>
      ((longitude + 540) % 360) - 180;
}
