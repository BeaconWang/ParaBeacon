import 'dart:math' as math;

import 'flight_data.dart';

enum LandingDetectionMode { automatic, manual, noDetection }

enum AutoFlightAction { takeoff, automaticLanding, requestLandingConfirmation }

/// Stateful GPS-driven take-off and landing detector.
///
/// Inputs must be fresh GPS snapshots. Candidate windows only advance on
/// distinct samples, preventing repeated notifications from one stale fix from
/// satisfying the debounce interval.
class AutoFlightDetector {
  static const Duration confirmationWindow = Duration(seconds: 8);
  static const Duration minimumFlightBeforeLanding = Duration(seconds: 30);
  static const Duration manualLandingCooldown = Duration(seconds: 30);
  static const Duration maximumFixAge = Duration(seconds: 10);
  static const Duration maximumSampleGap = Duration(seconds: 3);
  static const Duration quickRelaunchWindow = Duration(seconds: 65);

  static const double landingBaseSpeedKph = 5.0;
  static const double maximumGpsAccuracyM = 50.0;

  final List<_PositionSample> _positions = <_PositionSample>[];
  final List<double> _recentSpeedsKph = <double>[];

  DateTime? _lastSampleTime;
  DateTime? _takeoffCandidateSince;
  DateTime? _landingCandidateSince;
  DateTime? _landingCooldownUntil;
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
  }) {
    if (!autoDetectEnabled) {
      _resetCandidates(clearHistory: true);
      return null;
    }

    final sampleTime = data.gpsTimestamp ?? data.timestamp ?? observedAt;
    if (!_isUsableFix(data, sampleTime, observedAt)) {
      _resetCandidates(clearHistory: true);
      return null;
    }

    final lastSample = _lastSampleTime;
    if (lastSample != null) {
      if (!sampleTime.isAfter(lastSample)) return null;
      if (sampleTime.difference(lastSample) > maximumSampleGap) {
        _resetCandidates(clearHistory: true);
      }
    }
    _lastSampleTime = sampleTime;

    _positions.add(_PositionSample(sampleTime, data.latitude, data.longitude));
    if (_positions.length > 5) _positions.removeAt(0);

    var effectiveSpeedKph = data.groundSpeed;
    final derivedSpeedKph = _positionDerivedSpeedKph();
    if (derivedSpeedKph != null) {
      if ((effectiveSpeedKph - derivedSpeedKph).abs() > 25.0) {
        _resetCandidates(clearHistory: true);
        return null;
      }
      effectiveSpeedKph = math.min(effectiveSpeedKph, derivedSpeedKph);
    }

    _recentSpeedsKph.add(effectiveSpeedKph);
    if (_recentSpeedsKph.length > 5) _recentSpeedsKph.removeAt(0);

    if (!isFlying) {
      _landingCandidateSince = null;
      _landingConfirmationPending = false;
      if (effectiveSpeedKph > takeoffSpeedKph) {
        _takeoffCandidateSince ??= sampleTime;
        if (sampleTime.difference(_takeoffCandidateSince!) >=
            confirmationWindow) {
          _takeoffCandidateSince = null;
          return AutoFlightAction.takeoff;
        }
      } else {
        _takeoffCandidateSince = null;
      }
      return null;
    }

    _takeoffCandidateSince = null;
    if (landingMode == LandingDetectionMode.noDetection ||
        _landingConfirmationPending) {
      _landingCandidateSince = null;
      return null;
    }

    if (flightStartedAt == null ||
        sampleTime.difference(flightStartedAt) < minimumFlightBeforeLanding) {
      _landingCandidateSince = null;
      return null;
    }

    if (_landingCooldownUntil case final cooldown?
        when sampleTime.isBefore(cooldown)) {
      _landingCandidateSince = null;
      return null;
    }
    _landingCooldownUntil = null;

    final sinkMps = math.max(0.0, -data.verticalSpeed);
    final dynamicLandingLimitKph = (landingBaseSpeedKph + sinkMps * 1.5).clamp(
      5.0,
      8.0,
    );
    final recentMinimumSpeed = _recentSpeedsKph.reduce(math.min);
    final lowSpeed =
        effectiveSpeedKph < dynamicLandingLimitKph &&
        recentMinimumSpeed < dynamicLandingLimitKph;
    if (!lowSpeed || data.verticalSpeed < -4.0) {
      _landingCandidateSince = null;
      return null;
    }

    _landingCandidateSince ??= sampleTime;
    if (sampleTime.difference(_landingCandidateSince!) < confirmationWindow) {
      return null;
    }

    _landingCandidateSince = null;
    if (landingMode == LandingDetectionMode.manual) {
      _landingConfirmationPending = true;
      _landingCooldownUntil = sampleTime.add(manualLandingCooldown);
      return AutoFlightAction.requestLandingConfirmation;
    }
    return AutoFlightAction.automaticLanding;
  }

  /// Clears an outstanding manual prompt. Dismissal starts the cooldown so a
  /// persistent low-speed condition does not immediately reopen the dialog.
  void resolveLandingConfirmation({
    required bool landed,
    required DateTime resolvedAt,
  }) {
    if (!_landingConfirmationPending) return;
    _landingConfirmationPending = false;
    _landingCandidateSince = null;
    _landingCooldownUntil = landed
        ? null
        : resolvedAt.add(manualLandingCooldown);
  }

  void reset() {
    _resetCandidates(clearHistory: true);
    _landingCooldownUntil = null;
    _landingConfirmationPending = false;
  }

  bool _isUsableFix(FlightData data, DateTime sampleTime, DateTime observedAt) {
    if (!data.hasFix ||
        !data.groundSpeed.isFinite ||
        data.groundSpeed < 0.0 ||
        data.groundSpeed > 200.0 ||
        !data.latitude.isFinite ||
        !data.longitude.isFinite ||
        data.latitude < -90.0 ||
        data.latitude > 90.0 ||
        data.longitude < -180.0 ||
        data.longitude > 180.0 ||
        !data.verticalSpeed.isFinite) {
      return false;
    }
    final accuracy = data.gpsAccuracy;
    if (accuracy != null &&
        (!accuracy.isFinite ||
            accuracy < 0.0 ||
            accuracy > maximumGpsAccuracyM)) {
      return false;
    }
    final age = observedAt.difference(sampleTime);
    return age <= maximumFixAge && age >= const Duration(seconds: -2);
  }

  double? _positionDerivedSpeedKph() {
    if (_positions.length < 3) return null;
    final first = _positions.first;
    final last = _positions.last;
    final elapsed = last.time.difference(first.time);
    if (elapsed < const Duration(seconds: 1) ||
        elapsed > const Duration(seconds: 10)) {
      return null;
    }
    final distanceM = _distanceM(
      first.latitude,
      first.longitude,
      last.latitude,
      last.longitude,
    );
    return distanceM / elapsed.inMilliseconds * 3600.0;
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

  void _resetCandidates({bool clearHistory = false}) {
    _takeoffCandidateSince = null;
    _landingCandidateSince = null;
    if (clearHistory) {
      _positions.clear();
      _recentSpeedsKph.clear();
      _lastSampleTime = null;
    }
  }
}

class _PositionSample {
  const _PositionSample(this.time, this.latitude, this.longitude);

  final DateTime time;
  final double latitude;
  final double longitude;
}
