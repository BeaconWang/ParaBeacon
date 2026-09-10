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

  /// Whether the estimate is based on enough varied-heading data to be
  /// trustworthy (a full-ish circle). Low-confidence estimates should be shown
  /// dimmed or hidden.
  final bool confident;

  double get speedKmh => speedMps * 3.6;
}

/// A tiny, self-contained wind estimator derived purely from GPS ground
/// velocity while circling.
///
/// Principle: in still air a pilot flying at constant airspeed traces a circle
/// whose ground speed is constant. In wind, ground speed peaks when flying
/// downwind and troughs when flying upwind, varying sinusoidally with heading.
/// Fitting that sinusoid (least-squares over the trailing window) yields the
/// wind vector: the wind blows *towards* the heading of maximum ground speed,
/// with speed equal to half the (max − min) ground-speed swing.
///
/// This mirrors the *intent* of XCTrack's wind estimation without its heavy
/// air-model; when the device/BLE feed already provides a wind reading the map
/// prefers that and this estimator is a fallback.
class WindEstimator {
  WindEstimator({
    this.window = const Duration(seconds: 30),
    this.minSamples = 12,
  });

  /// Trailing window over which the sinusoid is fitted.
  final Duration window;

  /// Minimum buffered fixes before an estimate is produced.
  final int minSamples;

  final List<_V> _fixes = [];

  /// Feeds one ground-velocity fix ([groundSpeedMps] and [headingDeg]) and
  /// returns the current [WindEstimate], or null when there isn't enough
  /// varied-heading data yet.
  WindEstimate? add({
    required double groundSpeedMps,
    required double headingDeg,
    DateTime? time,
  }) {
    final now = time ?? DateTime.now();
    _fixes.add(_V(now, groundSpeedMps, headingDeg));
    final cutoff = now.subtract(window);
    while (_fixes.length > 1 && _fixes.first.time.isBefore(cutoff)) {
      _fixes.removeAt(0);
    }
    return _estimate();
  }

  void reset() => _fixes.clear();

  /// Least-squares fit of ground speed vs heading:
  ///   v(θ) ≈ a + b·cos(θ) + c·sin(θ)
  /// The wind vector is (b, c); its magnitude is the wind speed and its
  /// direction is the heading of maximum ground speed (i.e. the downwind
  /// heading), which we convert to the meteorological "from" direction.
  WindEstimate? _estimate() {
    final n = _fixes.length;
    if (n < minSamples) return null;

    double sA = 0, sB = 0, sC = 0; // sums for the normal equations
    double sAA = 0, sAB = 0, sAC = 0, sBB = 0, sBC = 0, sCC = 0;
    double headingSpread = 0;
    double prevSin = 0, prevCos = 0;
    for (int i = 0; i < n; i++) {
      final f = _fixes[i];
      final r = f.headingDeg * math.pi / 180.0;
      final co = math.cos(r);
      final si = math.sin(r);
      final v = f.groundSpeedMps;
      sA += v;
      sB += v * co;
      sC += v * si;
      sAA += 1;
      sAB += co;
      sAC += si;
      sBB += co * co;
      sBC += co * si;
      sCC += si * si;
      if (i > 0) {
        // Accumulate absolute heading change to gauge how much of a circle we
        // covered (confidence).
        headingSpread +=
            (math.atan2(si - prevSin, co - prevCos)).abs();
      }
      prevSin = si;
      prevCos = co;
    }

    // Solve the 3x3 symmetric system [ [sAA sAB sAC] [sAB sBB sBC] [sAC sBC sCC] ]·x = [sA sB sC].
    final sol = _solve3(
      sAA, sAB, sAC,
      sAB, sBB, sBC,
      sAC, sBC, sCC,
      sA, sB, sC,
    );
    if (sol == null) return null;
    final b = sol[1];
    final c = sol[2];

    final windSpeed = math.sqrt(b * b + c * c);
    // Heading (from north, clockwise) of maximum ground speed = downwind dir.
    final downwind = math.atan2(c, b) * 180.0 / math.pi;
    // Wind "from" direction is opposite the downwind heading.
    final fromDir = (downwind + 180.0) % 360.0;

    // Confidence: need a decent chunk of a full circle and a sane speed.
    // `headingSpread` accumulates absolute heading change (radians); ~pi means
    // roughly half a circle covered, enough to separate up/down-wind legs.
    final confident = _fixes.length >= minSamples &&
        headingSpread > math.pi &&
        windSpeed.isFinite &&
        windSpeed < 30.0;

    return WindEstimate(
      fromDirectionDeg: fromDir < 0 ? fromDir + 360.0 : fromDir,
      speedMps: windSpeed.isFinite ? windSpeed.clamp(0.0, 40.0) : 0.0,
      confident: confident,
    );
  }

  /// Solves a 3x3 linear system by Cramer's rule; returns null if singular.
  static List<double>? _solve3(
    double a11, double a12, double a13,
    double a21, double a22, double a23,
    double a31, double a32, double a33,
    double b1, double b2, double b3,
  ) {
    final det = a11 * (a22 * a33 - a23 * a32) -
        a12 * (a21 * a33 - a23 * a31) +
        a13 * (a21 * a32 - a22 * a31);
    if (det.abs() < 1e-9) return null;
    final dx = b1 * (a22 * a33 - a23 * a32) -
        a12 * (b2 * a33 - a23 * b3) +
        a13 * (b2 * a32 - a22 * b3);
    final dy = a11 * (b2 * a33 - a23 * b3) -
        b1 * (a21 * a33 - a23 * a31) +
        a13 * (a21 * b3 - b2 * a31);
    final dz = a11 * (a22 * b3 - b2 * a32) -
        a12 * (a21 * b3 - b2 * a31) +
        b1 * (a21 * a32 - a22 * a31);
    return [dx / det, dy / det, dz / det];
  }
}

class _V {
  const _V(this.time, this.groundSpeedMps, this.headingDeg);
  final DateTime time;
  final double groundSpeedMps;
  final double headingDeg;
}
