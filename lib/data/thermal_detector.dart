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
    this.historyLimit = 8,
  });

  /// Trailing window over which climb is averaged.
  final Duration window;

  /// Minimum mean climb (m/s) to consider the pilot "thermalling".
  final double minClimbMps;

  /// Minimum number of buffered fixes before a hint is produced.
  final int minSamples;

  /// Maximum number of past thermal cores kept in [history] (mirrors XCTrack's
  /// "Show N latest thermals" feature).
  final int historyLimit;

  final List<_Fix> _fixes = [];

  /// Recently completed thermal cores, most-recent last. A core is committed
  /// to history when a sustained climb ends (the pilot glides away), so the
  /// map can mark previously-worked thermals like XCTrack's Thermal Assistant.
  final List<ThermalHint> _history = [];

  /// Whether the previous [add] produced an active climb hint. Used to detect
  /// the climb→glide transition that commits a core to [history].
  ThermalHint? _lastActive;

  /// Read-only view of the recent thermal cores (oldest first).
  List<ThermalHint> get history => List.unmodifiable(_history);

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
    final hint = _evaluate();
    // Detect the climb→glide transition: when a previously-active core stops
    // being reported, commit it to history so it can be marked on the map.
    if (hint == null && _lastActive != null) {
      _commitToHistory(_lastActive!);
    }
    _lastActive = hint;
    return hint;
  }

  /// Adds [core] to [history], de-duplicating cores that sit almost on top of
  /// an existing entry (the pilot re-centering the same thermal) and capping
  /// the list at [historyLimit].
  void _commitToHistory(ThermalHint core) {
    const mergeMeters = 60.0;
    const mPerDegLat = 111320.0;
    final mPerDegLon =
        111320.0 * math.cos(core.centerLat * math.pi / 180.0);
    for (int i = 0; i < _history.length; i++) {
      final h = _history[i];
      final dx = (h.centerLon - core.centerLon) * mPerDegLon;
      final dy = (h.centerLat - core.centerLat) * mPerDegLat;
      if (math.sqrt(dx * dx + dy * dy) < mergeMeters) {
        // Same thermal worked again: keep the stronger estimate, move to the
        // end so it reads as most-recent.
        _history.removeAt(i);
        _history.add(core.avgClimbMps >= h.avgClimbMps ? core : h);
        return;
      }
    }
    _history.add(core);
    while (_history.length > historyLimit) {
      _history.removeAt(0);
    }
  }

  /// Clears the buffer (e.g. on GPS loss).
  void reset() {
    _fixes.clear();
    _lastActive = null;
  }

  /// Clears the buffer and the committed thermal history (e.g. new flight).
  void resetAll() {
    reset();
    _history.clear();
  }

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
