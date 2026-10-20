import 'dart:math' as math;

/// How wind is factored into the thermal-assistant computation. Mirrors
/// XCTrack's "How to include wind into computation" setting.
enum WindAlgorithm {
  /// Ignore wind entirely: thermal cores are drawn where they were measured.
  none,

  /// Classic: shift the detected core upwind so the *ground-referenced* core
  /// tracks the air mass the pilot is actually working (the thermal drifts
  /// with the wind, so the useful lift is slightly upwind of the raw centroid).
  classic,

  /// Particle drift: like classic but the shift grows with how long ago each
  /// sample was taken, modelling the air parcel drifting over time.
  particleDrift,
}

/// A wind estimate: the direction the wind is coming *from* and its speed.
class WindEstimate {
  const WindEstimate({
    required this.fromDirectionDeg,
    required this.speedMps,
    required this.confident,
  });

  /// Compass bearing the wind blows *from*, degrees clockwise from north.
  final double fromDirectionDeg;

  /// Wind speed in metres per second.
  final double speedMps;

  /// Whether XCTrack's turn-rate and airspeed checks accepted this estimate.
  final bool confident;

  double get speedKmh => speedMps * 3.6;
}

/// XCTrack-compatible wind estimator based on GPS ground-velocity vectors.
///
/// For each fix, ground speed and course are converted to east/north velocity
/// components. In a steady turn those points lie on a circle whose center is
/// the wind vector. XCTrack fits the center through the middle three of its
/// rolling five-fix buffer, checks turn rate and circle radius against the
/// configured trim speed, then applies its 90-second Gaussian smoothing.
class WindEstimator {
  WindEstimator({this.trimSpeedKmh = 38.0});

  /// XCTrack's Glider.TrimSpeed, used for the circle-radius check.
  double trimSpeedKmh;

  static const int _sampleCapacity = 5;
  static const Duration _maximumSampleGap = Duration(seconds: 10);
  static const Duration _minimumFullBufferInterval = Duration(
    milliseconds: 2900,
  );
  static const double _minimumTurnRateDegPerSec = 8.0;
  static const double _smoothingTimeMs = 90000.0;
  static const double _radiusTolerance = 0.3;
  static const double _xcTrackRadiusFactor = 0.85;

  final List<_VelocityFix> _fixes = <_VelocityFix>[];
  double _windEastMps = 0.0;
  double _windNorthMps = 0.0;
  double _weight = 0.0;
  DateTime? _lastAcceptedTime;
  WindEstimate? _latestEstimate;

  /// Most recent accepted estimate, retained while new candidates are rejected.
  WindEstimate? get latestEstimate => _latestEstimate;

  /// Feeds one ground-velocity fix and returns the latest accepted estimate.
  ///
  /// The buffer and candidate checks follow XCTrack: a 10-second gap clears
  /// only the five-fix window, and once full, a new sample is admitted at most
  /// once every 2.9 seconds relative to the oldest buffered fix.
  WindEstimate? add({
    required double groundSpeedMps,
    required double headingDeg,
    DateTime? time,
  }) {
    final now = time ?? DateTime.now();
    if (!groundSpeedMps.isFinite ||
        groundSpeedMps < 0 ||
        !headingDeg.isFinite) {
      return _latestEstimate;
    }

    final oldest = _fixes.isEmpty ? null : _fixes.first.time;
    if (oldest != null &&
        (now.isBefore(oldest) || now.difference(oldest) > _maximumSampleGap)) {
      _fixes.clear();
    }

    if (_fixes.isNotEmpty && now.isAtSameMomentAs(_fixes.last.time)) {
      return _latestEstimate;
    }
    if (_fixes.length == _sampleCapacity &&
        now.difference(_fixes.first.time) < _minimumFullBufferInterval) {
      return _latestEstimate;
    }

    final radians = headingDeg * math.pi / 180.0;
    _fixes.add(
      _VelocityFix(
        time: now,
        eastMps: groundSpeedMps * math.sin(radians),
        northMps: -groundSpeedMps * math.cos(radians),
      ),
    );
    if (_fixes.length > _sampleCapacity) _fixes.removeAt(0);

    if (_fixes.length == _sampleCapacity) _updateEstimate();
    return _latestEstimate;
  }

  /// Drops both the buffered fixes and the smoothed wind state.
  void reset() {
    _fixes.clear();
    _windEastMps = 0.0;
    _windNorthMps = 0.0;
    _weight = 0.0;
    _lastAcceptedTime = null;
    _latestEstimate = null;
  }

  void _updateEstimate() {
    final p1 = _fixes[1];
    final p2 = _fixes[2];
    final p3 = _fixes[3];
    final center = _circumcenter(p1, p2, p3);
    if (center == null) return;

    // XCTrack rejects candidates unless every segment is turning in the same
    // direction at a minimum rate of 8 degrees per second.
    var minimumRate = double.infinity;
    var maximumRate = double.negativeInfinity;
    for (var i = 1; i < _fixes.length; i++) {
      final previous = _fixes[i - 1];
      final current = _fixes[i];
      final elapsedMs = current.time.difference(previous.time).inMilliseconds;
      if (elapsedMs <= 0) return;

      final previousAngle = math.atan2(
        previous.northMps - center.northMps,
        previous.eastMps - center.eastMps,
      );
      final currentAngle = math.atan2(
        current.northMps - center.northMps,
        current.eastMps - center.eastMps,
      );
      var delta = (currentAngle - previousAngle) * 180.0 / math.pi;
      if (delta > 180.0) delta -= 360.0;
      if (delta < -180.0) delta += 360.0;
      final rate = delta * 1000.0 / elapsedMs;
      minimumRate = math.min(minimumRate, rate);
      maximumRate = math.max(maximumRate, rate);
    }
    if (minimumRate < 0.0) {
      final oldMinimum = minimumRate;
      minimumRate = -maximumRate;
      maximumRate = -oldMinimum;
    }
    if (minimumRate < _minimumTurnRateDegPerSec) return;

    final expectedRadius = trimSpeedKmh / 3.6 * _xcTrackRadiusFactor;
    if (!expectedRadius.isFinite || expectedRadius <= 0.0) return;
    final radius = _distance(p2, center);
    final candidateWeight =
        1.0 - ((radius / expectedRadius - 1.0).abs() / _radiusTolerance);
    if (candidateWeight <= 0.0) return;

    final now = _fixes.last.time;
    final previousWeight = _lastAcceptedTime == null
        ? 0.0
        : _weight *
              _decayFor(now.difference(_lastAcceptedTime!).inMilliseconds);
    final totalWeight = previousWeight + candidateWeight;
    if (!totalWeight.isFinite || totalWeight <= 0.0) return;

    _windEastMps =
        (center.eastMps * candidateWeight + _windEastMps * previousWeight) /
        totalWeight;
    _windNorthMps =
        (center.northMps * candidateWeight + _windNorthMps * previousWeight) /
        totalWeight;
    _weight = totalWeight;
    _lastAcceptedTime = now;

    final speed = math.sqrt(
      _windEastMps * _windEastMps + _windNorthMps * _windNorthMps,
    );
    final fromDirection =
        math.atan2(_windEastMps, -_windNorthMps) * 180.0 / math.pi + 180.0;
    if (!speed.isFinite || !fromDirection.isFinite) return;
    _latestEstimate = WindEstimate(
      fromDirectionDeg: fromDirection,
      speedMps: speed,
      confident: true,
    );
  }

  double _decayFor(int elapsedMs) {
    final normalizedElapsed = elapsedMs / _smoothingTimeMs;
    return math.exp(-normalizedElapsed * normalizedElapsed);
  }

  static _VelocityFix? _circumcenter(
    _VelocityFix p1,
    _VelocityFix p2,
    _VelocityFix p3,
  ) {
    final determinant =
        2.0 *
        (p1.eastMps * (p2.northMps - p3.northMps) +
            p2.eastMps * (p3.northMps - p1.northMps) +
            p3.eastMps * (p1.northMps - p2.northMps));
    if (!determinant.isFinite || determinant.abs() < 1e-4) return null;

    final p1Norm = p1.eastMps * p1.eastMps + p1.northMps * p1.northMps;
    final p2Norm = p2.eastMps * p2.eastMps + p2.northMps * p2.northMps;
    final p3Norm = p3.eastMps * p3.eastMps + p3.northMps * p3.northMps;
    final east =
        (p1Norm * (p2.northMps - p3.northMps) +
            p2Norm * (p3.northMps - p1.northMps) +
            p3Norm * (p1.northMps - p2.northMps)) /
        determinant;
    final north =
        (p1Norm * (p3.eastMps - p2.eastMps) +
            p2Norm * (p1.eastMps - p3.eastMps) +
            p3Norm * (p2.eastMps - p1.eastMps)) /
        determinant;
    if (!east.isFinite || !north.isFinite) return null;
    return _VelocityFix(time: p2.time, eastMps: east, northMps: north);
  }

  static double _distance(_VelocityFix point, _VelocityFix center) {
    final east = point.eastMps - center.eastMps;
    final north = point.northMps - center.northMps;
    return math.sqrt(east * east + north * north);
  }
}

class _VelocityFix {
  const _VelocityFix({
    required this.time,
    required this.eastMps,
    required this.northMps,
  });

  final DateTime time;
  final double eastMps;
  final double northMps;
}
