import 'dart:math' as math;

/// A detected thermal (lift core) the pilot is currently working.
class ThermalHint {
  const ThermalHint({
    required this.centerLat,
    required this.centerLon,
    required this.radiusM,
    required this.avgClimbMps,
  });

  final double centerLat;
  final double centerLon;

  /// Approximate radius of the circling pattern, meters.
  final double radiusM;

  /// Mean climb rate over the detection window, m/s (> 0).
  final double avgClimbMps;
}

/// A tiny, self-contained "thermal / climb assistant" detector.
///
/// It keeps a short trailing window of GPS+vario fixes and, when the pilot is
/// sustaining a climb (mean vertical speed above [minClimbMps] over the window
/// with enough samples), reports the centroid of the recent track as the
/// thermal core plus an estimated circling radius. When the climb stops it
/// returns null so the Map control hides the overlay.
///
/// This mirrors the *intent* of the reference project's thermal overlay without
/// its heavy service dependencies — everything is derived from the flight-data
/// feed the Map control already consumes.
class ThermalDetector {
  ThermalDetector({
    this.window = const Duration(seconds: 20),
    this.minClimbMps = 0.5,
    this.minSamples = 8,
  });

  /// Trailing window over which climb is averaged.
  final Duration window;

  /// Minimum mean climb (m/s) to consider the pilot "thermalling".
  final double minClimbMps;

  /// Minimum number of buffered fixes before a hint is produced.
  final int minSamples;

  final List<_Fix> _fixes = [];

  /// Feeds one fix. Returns the current [ThermalHint], or null when the pilot
  /// is not climbing / not enough data.
  ThermalHint? add({
    required double lat,
    required double lon,
    required double climbMps,
    DateTime? time,
  }) {
    final now = time ?? DateTime.now();
    _fixes.add(_Fix(now, lat, lon, climbMps));

    final cutoff = now.subtract(window);
    while (_fixes.length > 1 && _fixes.first.time.isBefore(cutoff)) {
      _fixes.removeAt(0);
    }
    return _evaluate();
  }

  /// Clears the buffer (e.g. on GPS loss).
  void reset() => _fixes.clear();

  ThermalHint? _evaluate() {
    if (_fixes.length < minSamples) return null;

    double sumClimb = 0;
    double sumLat = 0;
    double sumLon = 0;
    for (final f in _fixes) {
      sumClimb += f.climbMps;
      sumLat += f.lat;
      sumLon += f.lon;
    }
    final avgClimb = sumClimb / _fixes.length;
    if (avgClimb < minClimbMps) return null;

    final cLat = sumLat / _fixes.length;
    final cLon = sumLon / _fixes.length;

    // Estimate the circling radius as the mean distance from the centroid.
    const mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(cLat * math.pi / 180.0);
    double sumR = 0;
    for (final f in _fixes) {
      final dx = (f.lon - cLon) * mPerDegLon;
      final dy = (f.lat - cLat) * mPerDegLat;
      sumR += math.sqrt(dx * dx + dy * dy);
    }
    final radius = (sumR / _fixes.length).clamp(15.0, 400.0);

    return ThermalHint(
      centerLat: cLat,
      centerLon: cLon,
      radiusM: radius.toDouble(),
      avgClimbMps: avgClimb,
    );
  }
}

class _Fix {
  const _Fix(this.time, this.lat, this.lon, this.climbMps);
  final DateTime time;
  final double lat;
  final double lon;
  final double climbMps;
}
