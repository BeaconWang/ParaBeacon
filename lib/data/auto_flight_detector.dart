import 'dart:math' as math;

import 'flight_data.dart';

/// Landing handling configured to mirror XCTrack's detection modes.
enum LandingDetectionMode { automatic, manual, noDetection }

enum AutoFlightAction { takeoff, automaticLanding, requestLandingConfirmation }

/// GPS-driven take-off and landing detector following XCTrack's thresholds.
///
/// Speeds in the detector use m/s, matching the source algorithm. Input
/// [FlightData] stores ground and wind speed in km/h, so those values are
/// converted at the boundary. A null terrain elevation follows XCTrack's
/// terrain-query-NaN fallback (height delta = 1000 m).
class AutoFlightDetector {
  static const Duration minimumFlightBeforeLanding = Duration(seconds: 30);
  static const Duration manualLandingCooldown = Duration(seconds: 30);
  static const Duration quickRelaunchWindow = Duration(seconds: 65);
  static const Duration speedBucketWidth = Duration(seconds: 3);
  static const Duration maximumTimestampOffset = Duration(minutes: 30);
  static const int speedBucketCount = 5;

  static const double _terrainUnavailableHeightDeltaM = 1000.0;
  static const double _windSpeedFactor = 1.1111111405455043;

  final Stopwatch _monotonicClock = Stopwatch()..start();
  final List<_PositionSample> _takeoffHistory = <_PositionSample>[];
  final List<double> _landingSpeedBuckets = List<double>.filled(
    speedBucketCount,
    double.nan,
  );

  DateTime? _lastSampleTime;
  Duration? _lastArrivalMonotonic;
  _PositionSample? _lastPosition;
  int _nextSpeedBucket = 0;
  Duration? _landingCooldownUntil;
  bool _landingConfirmationPending = false;

  bool get hasPendingLandingConfirmation => _landingConfirmationPending;

  AutoFlightAction? update({
    required FlightData data,
    required DateTime observedAt,
    required bool isFlying,
    required DateTime? flightStartedAt,
    required bool autoDetectEnabled,
    required LandingDetectionMode landingMode,
    required double takeoffSpeedKph,
    required double trimSpeedKph,
    Duration minimumFlightBeforeLanding =
        AutoFlightDetector.minimumFlightBeforeLanding,
    double landingSpeedFactor = 1.0,
    Duration? monotonicTime,
  }) {
    final sampleTime = data.gpsTimestamp ?? data.timestamp ?? observedAt;
    final nowMonotonic = monotonicTime ?? _monotonicClock.elapsed;
    if (!_isUsableFix(data, sampleTime)) return null;

    final lastSampleTime = _lastSampleTime;
    final lastArrivalMonotonic = _lastArrivalMonotonic;
    if (lastSampleTime != null) {
      if (sampleTime == lastSampleTime) return null;
      if (lastArrivalMonotonic != null) {
        final expectedTime = lastSampleTime.add(
          nowMonotonic - lastArrivalMonotonic,
        );
        if (sampleTime.difference(expectedTime).abs() >
            maximumTimestampOffset) {
          return null;
        }
      }
    }
    _lastSampleTime = sampleTime;
    _lastArrivalMonotonic = nowMonotonic;

    final previous = _lastPosition;
    final derivedSpeedMps = previous == null
        ? 0.0
        : _derivedSpeed(previous, sampleTime, data.latitude, data.longitude);
    final currentSpeedMps = data.hasGroundSpeed
        ? data.groundSpeed / 3.6
        : derivedSpeedMps;
    final current = _PositionSample(
      time: sampleTime,
      latitude: data.latitude,
      longitude: data.longitude,
      derivedSpeedMps: derivedSpeedMps,
    );
    _lastPosition = current;

    _updateLandingSpeedBuckets(sampleTime, currentSpeedMps);

    if (!isFlying) {
      _landingConfirmationPending = false;
      if (autoDetectEnabled &&
          _isTakeoff(
            currentSpeedMps,
            derivedSpeedMps,
            current,
            takeoffSpeedKph / 3.6,
          )) {
        _landingCooldownUntil = null;
        return AutoFlightAction.takeoff;
      }
      _takeoffHistory.add(current);
      if (_takeoffHistory.length > speedBucketCount) {
        _takeoffHistory.removeAt(0);
      }
      return null;
    }

    if (!autoDetectEnabled ||
        landingMode == LandingDetectionMode.noDetection ||
        _landingConfirmationPending) {
      return null;
    }

    if (flightStartedAt == null ||
        !sampleTime.isAfter(flightStartedAt.add(minimumFlightBeforeLanding))) {
      return null;
    }

    final cooldownUntil = _landingCooldownUntil;
    if (cooldownUntil != null && nowMonotonic < cooldownUntil) return null;
    _landingCooldownUntil = null;

    final terrainElevationM = data.terrainElevationM;
    final heightDeltaM =
        data.gpsAltitude == null ||
            terrainElevationM == null ||
            !terrainElevationM.isFinite
        ? _terrainUnavailableHeightDeltaM
        : data.gpsAltitude! - terrainElevationM;
    final altitudeFactor = _altitudeFactor(heightDeltaM);
    final trimMps = trimSpeedKph / 3.6;
    final windRatio = trimMps > 0 ? (data.windSpeed / 3.6) / trimMps : 0.0;
    final windFactor = _windFactor(windRatio);
    final speedLimitMps =
        _windSpeedFactor * altitudeFactor * windFactor * landingSpeedFactor;

    final recentMinimumSpeed = _landingSpeedBuckets
        .where((speed) => !speed.isNaN)
        .fold<double>(double.infinity, math.min);
    if (!(currentSpeedMps < speedLimitMps &&
        recentMinimumSpeed < speedLimitMps)) {
      return null;
    }

    if (landingMode == LandingDetectionMode.manual && !data.isMockLocation) {
      _landingConfirmationPending = true;
      _landingCooldownUntil = nowMonotonic + manualLandingCooldown;
      return AutoFlightAction.requestLandingConfirmation;
    }
    return AutoFlightAction.automaticLanding;
  }

  /// Resolving the dialog does not move XCTrack's cooldown start time: the
  /// 30-second window begins when the confirmation-needed event was emitted.
  void resolveLandingConfirmation() {
    _landingConfirmationPending = false;
  }

  void reset() {
    _takeoffHistory.clear();
    _landingSpeedBuckets.fillRange(0, _landingSpeedBuckets.length, double.nan);
    _lastSampleTime = null;
    _lastArrivalMonotonic = null;
    _lastPosition = null;
    _nextSpeedBucket = 0;
    _landingCooldownUntil = null;
    _landingConfirmationPending = false;
  }

  bool _isTakeoff(
    double gpsSpeedMps,
    double previousPointSpeedMps,
    _PositionSample current,
    double takeoffThresholdMps,
  ) {
    var speedMps = math.min(gpsSpeedMps, previousPointSpeedMps);
    if (_takeoffHistory.length >= 3) {
      final reference = _takeoffHistory[_takeoffHistory.length - 3];
      final elapsedSeconds =
          current.time.difference(reference.time).inMilliseconds / 1000.0;
      final historySpeedMps =
          _distanceM(
            reference.latitude,
            reference.longitude,
            current.latitude,
            current.longitude,
          ) /
          elapsedSeconds;
      speedMps = math.min(speedMps, historySpeedMps);
      return speedMps > takeoffThresholdMps;
    }
    return false;
  }

  static double _altitudeFactor(double heightDeltaM) {
    if (heightDeltaM > 100.0) return 0.5;
    if (heightDeltaM < 0.0) return 1.0;
    return 1.0 - heightDeltaM / 200.0;
  }

  static double _windFactor(double windToTrimRatio) {
    if (windToTrimRatio < 0.5) return 1.0;
    if (windToTrimRatio > 1.0) return 0.5;
    return 1.5 - windToTrimRatio;
  }

  double _derivedSpeed(
    _PositionSample previous,
    DateTime currentTime,
    double currentLatitude,
    double currentLongitude,
  ) {
    if (previous.time.isBefore(currentTime)) {
      final elapsedMs = currentTime.difference(previous.time).inMilliseconds;
      return _distanceM(
            previous.latitude,
            previous.longitude,
            currentLatitude,
            currentLongitude,
          ) *
          1000.0 /
          elapsedMs;
    }
    return previous.derivedSpeedMps;
  }

  void _updateLandingSpeedBuckets(DateTime time, double speedMps) {
    final bucket =
        time.millisecondsSinceEpoch ~/ speedBucketWidth.inMilliseconds;
    if (bucket < 0 || bucket < _nextSpeedBucket - 1) return;

    if (bucket == _nextSpeedBucket - 1) {
      final slot = bucket % speedBucketCount;
      _landingSpeedBuckets[slot] = math.min(
        _landingSpeedBuckets[slot],
        speedMps,
      );
      return;
    }

    final firstBucketToClear = math.max(
      _nextSpeedBucket,
      bucket - speedBucketCount + 1,
    );
    for (var index = firstBucketToClear; index < bucket; index++) {
      _landingSpeedBuckets[index % speedBucketCount] = double.nan;
    }
    _landingSpeedBuckets[bucket % speedBucketCount] = speedMps;
    _nextSpeedBucket = bucket + 1;
  }

  static bool _isUsableFix(FlightData data, DateTime sampleTime) {
    return data.hasFix &&
        sampleTime.millisecondsSinceEpoch >= 0 &&
        data.groundSpeed.isFinite &&
        data.latitude.isFinite &&
        data.longitude.isFinite &&
        data.latitude >= -90.0 &&
        data.latitude <= 90.0 &&
        data.longitude >= -180.0 &&
        data.longitude <= 180.0 &&
        (data.latitude != 0.0 || data.longitude != 0.0);
  }

  static double _distanceM(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final latDelta = _radians(lat2 - lat1);
    final lonDelta = _radians(lon2 - lon1);
    final a =
        math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
}

class _PositionSample {
  const _PositionSample({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.derivedSpeedMps,
  });

  final DateTime time;
  final double latitude;
  final double longitude;
  final double derivedSpeedMps;
}
