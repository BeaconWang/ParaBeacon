import 'dart:math' as math;

import 'flight_recorder.dart';

/// A stable, human-facing identifier for a flight, derived purely from its
/// start time. Used by the exporters and the library bundle so the same flight
/// maps to the same filename across export/import round-trips.
String flightId(FlightTrack track) =>
    'flight_${track.startTime.toUtc().millisecondsSinceEpoch}';

/// A short, filename-safe label like `2026-09-09_1435`.
String flightSlug(FlightTrack track) {
  final t = track.startTime;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}_'
      '${two(t.hour)}${two(t.minute)}';
}

/// Derived performance metrics computed from a completed [FlightTrack]'s
/// per-sample data.
///
/// This is a self-contained port of the reference project's
/// `FlightDerivedStats`, adapted to this project's [FlightTrack]/[FlightSample]
/// model (ground speed in km/h, vertical speed in m/s). All values are computed
/// in one pass over the samples; when a track carries no per-sample data (a
/// summary-only flight restored from disk) the derived fields fall back to the
/// summary statistics where possible and to zero otherwise.
class FlightDerivedStats {
  const FlightDerivedStats({
    required this.straightDistanceM,
    required this.trackDistanceM,
    required this.maxDistanceFromStartM,
    required this.avgGroundSpeedKph,
    required this.avgCruiseSpeedKph,
    required this.maxSpeedKph,
    required this.avgClimbMs,
    required this.avgSinkMs,
    required this.avgGlideRatio,
    required this.trackEfficiency,
    required this.thermalCount,
    required this.altitudeGainedM,
    required this.altitudeLostM,
    required this.climbTime,
    required this.sinkTime,
    required this.glideTime,
    required this.movingTime,
    this.xcDistanceM = 0,
    this.faiTriangleM = 0,
    this.faiClosed = false,
  });

  /// Straight-line (start → end) distance, meters.
  final double straightDistanceM;

  /// Total along-track distance, meters.
  final double trackDistanceM;

  /// Farthest any point strays from the launch point, meters.
  final double maxDistanceFromStartM;

  final double avgGroundSpeedKph;

  /// Average speed while gliding (not climbing in a thermal), km/h.
  final double avgCruiseSpeedKph;
  final double maxSpeedKph;

  /// Average climb rate over climbing samples, m/s (>= 0).
  final double avgClimbMs;

  /// Average sink rate over sinking samples, m/s (<= 0).
  final double avgSinkMs;

  /// Average glide ratio over gliding segments (horizontal / vertical).
  final double avgGlideRatio;

  /// straightDistance / trackDistance, in 0..1.
  final double trackEfficiency;

  /// Number of distinct climbs (thermals) detected.
  final int thermalCount;

  final double altitudeGainedM;
  final double altitudeLostM;

  final Duration climbTime;
  final Duration sinkTime;
  final Duration glideTime;
  final Duration movingTime;

  /// Cross-country "free / open" distance — here the straight start→end
  /// distance, which is the simplest widely-used XC proxy, meters.
  final double xcDistanceM;

  /// Best FAI-triangle perimeter found over the (downsampled) track, meters.
  /// 0 when no qualifying triangle exists.
  final double faiTriangleM;

  /// Whether the best FAI triangle is "closed" (start and end within the FAI
  /// closing tolerance of 5% of the triangle perimeter).
  final bool faiClosed;

  static const FlightDerivedStats zero = FlightDerivedStats(
    straightDistanceM: 0,
    trackDistanceM: 0,
    maxDistanceFromStartM: 0,
    avgGroundSpeedKph: 0,
    avgCruiseSpeedKph: 0,
    maxSpeedKph: 0,
    avgClimbMs: 0,
    avgSinkMs: 0,
    avgGlideRatio: 0,
    trackEfficiency: 0,
    thermalCount: 0,
    altitudeGainedM: 0,
    altitudeLostM: 0,
    climbTime: Duration.zero,
    sinkTime: Duration.zero,
    glideTime: Duration.zero,
    movingTime: Duration.zero,
    xcDistanceM: 0,
    faiTriangleM: 0,
    faiClosed: false,
  );

  /// A climb of at least this sustained rate is treated as a thermal core.
  static const double _thermalThresholdMs = 0.5;

  /// Below this vertical rate (either sign) the segment counts as a glide.
  static const double _glideBandMs = 0.5;

  /// Below this ground speed (km/h) a sample is treated as stationary.
  static const double _movingSpeedKph = 2.0;

  /// Computes the derived stats for [track]. Cheap enough to call on demand.
  factory FlightDerivedStats.compute(FlightTrack track) {
    final s = track.samples;
    if (s.length < 2) {
      // Summary-only or trivial track: surface what the summary already knows.
      return FlightDerivedStats(
        straightDistanceM: 0,
        trackDistanceM: track.distanceM,
        maxDistanceFromStartM: 0,
        avgGroundSpeedKph: 0,
        avgCruiseSpeedKph: 0,
        maxSpeedKph: 0,
        avgClimbMs: 0,
        avgSinkMs: 0,
        avgGlideRatio: 0,
        trackEfficiency: 0,
        thermalCount: 0,
        altitudeGainedM: 0,
        altitudeLostM: 0,
        climbTime: Duration.zero,
        sinkTime: Duration.zero,
        glideTime: Duration.zero,
        movingTime: Duration.zero,
      );
    }

    final first = s.first;
    final last = s.last;

    double trackDist = 0;
    double maxFromStart = 0;
    double maxSpeed = 0;

    double climbSum = 0;
    int climbCount = 0;
    double sinkSum = 0;
    int sinkCount = 0;

    double gained = 0;
    double lost = 0;

    // Cruise (glide) speed accumulation.
    double cruiseSpeedSum = 0;
    int cruiseSpeedCount = 0;

    // Glide-ratio accumulation over gliding steps.
    double glideHoriz = 0;
    double glideVert = 0;

    int climbMs = 0;
    int sinkMs = 0;
    int glideMs = 0;
    int movingMs = 0;

    int thermalCount = 0;
    bool inThermal = false;

    for (var i = 1; i < s.length; i++) {
      final a = s[i - 1];
      final b = s[i];
      final dtMs = b.time.difference(a.time).inMilliseconds;
      final dt = dtMs / 1000.0;

      final stepM = _haversineM(
        a.data.latitude,
        a.data.longitude,
        b.data.latitude,
        b.data.longitude,
      );
      trackDist += stepM;

      final fromStart = _haversineM(
        first.data.latitude,
        first.data.longitude,
        b.data.latitude,
        b.data.longitude,
      );
      if (fromStart > maxFromStart) maxFromStart = fromStart;

      if (b.data.groundSpeed > maxSpeed) maxSpeed = b.data.groundSpeed;

      final dAlt = b.data.altitude - a.data.altitude;
      if (dAlt > 0) {
        gained += dAlt;
      } else {
        lost += -dAlt;
      }

      final v = b.data.verticalSpeed;
      if (v > 0) {
        climbSum += v;
        climbCount++;
      } else if (v < 0) {
        sinkSum += v;
        sinkCount++;
      }

      if (dtMs > 0) {
        if (b.data.groundSpeed > _movingSpeedKph) movingMs += dtMs;

        if (v >= _thermalThresholdMs) {
          climbMs += dtMs;
          if (!inThermal) {
            inThermal = true;
            thermalCount++;
          }
        } else {
          if (v <= -_thermalThresholdMs) {
            sinkMs += dtMs;
          }
          inThermal = false;
        }

        // Glide: near-level vertical rate while still moving forward.
        if (v.abs() < _glideBandMs && b.data.groundSpeed > _movingSpeedKph) {
          glideMs += dtMs;
          cruiseSpeedSum += b.data.groundSpeed;
          cruiseSpeedCount++;
        }

        // Glide ratio: accumulate horizontal vs. vertical while descending in
        // a glide (not thermalling).
        if (v < 0 && v > -3.0 && stepM > 0) {
          glideHoriz += stepM;
          glideVert += -v * dt; // meters lost over this step
        }
      }
    }

    final straight = _haversineM(
      first.data.latitude,
      first.data.longitude,
      last.data.latitude,
      last.data.longitude,
    );

    final totalSec =
        last.time.difference(first.time).inMilliseconds / 1000.0;
    final avgGs = totalSec > 0 ? (trackDist / totalSec) * 3.6 : 0.0;

    final fai = _bestFaiTriangle(s);

    return FlightDerivedStats(
      straightDistanceM: straight,
      trackDistanceM: trackDist,
      maxDistanceFromStartM: maxFromStart,
      avgGroundSpeedKph: avgGs,
      avgCruiseSpeedKph:
          cruiseSpeedCount > 0 ? cruiseSpeedSum / cruiseSpeedCount : 0.0,
      maxSpeedKph: maxSpeed,
      avgClimbMs: climbCount > 0 ? climbSum / climbCount : 0.0,
      avgSinkMs: sinkCount > 0 ? sinkSum / sinkCount : 0.0,
      avgGlideRatio: glideVert > 0.5 ? glideHoriz / glideVert : 0.0,
      trackEfficiency: trackDist > 0 ? (straight / trackDist).clamp(0.0, 1.0) : 0.0,
      thermalCount: thermalCount,
      altitudeGainedM: gained,
      altitudeLostM: lost,
      climbTime: Duration(milliseconds: climbMs),
      sinkTime: Duration(milliseconds: sinkMs),
      glideTime: Duration(milliseconds: glideMs),
      movingTime: Duration(milliseconds: movingMs),
      xcDistanceM: straight,
      faiTriangleM: fai.$1,
      faiClosed: fai.$2,
    );
  }

  /// Searches for the largest FAI triangle over the track.
  ///
  /// A full O(n³) search is infeasible for long tracks, so the track is first
  /// reduced to at most [_faiMaxPoints] evenly-spaced points; the triangle
  /// search then runs on that reduced set. This mirrors the heuristic used by
  /// the reference project's optimizer — good enough for a post-flight summary,
  /// not a scoring-grade optimizer. Returns `(perimeterMeters, closed)`.
  static (double, bool) _bestFaiTriangle(List<FlightSample> s) {
    if (s.length < 3) return (0.0, false);

    // Downsample to a manageable point count.
    final pts = <FlightSample>[];
    if (s.length <= _faiMaxPoints) {
      pts.addAll(s);
    } else {
      final stride = s.length / _faiMaxPoints;
      for (var i = 0.0; i < s.length; i += stride) {
        pts.add(s[i.floor()]);
      }
      if (pts.last != s.last) pts.add(s.last);
    }

    final n = pts.length;
    // Precompute pairwise distances.
    final dist = List.generate(n, (_) => List<double>.filled(n, 0));
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final d = _haversineM(
          pts[i].data.latitude,
          pts[i].data.longitude,
          pts[j].data.latitude,
          pts[j].data.longitude,
        );
        dist[i][j] = d;
        dist[j][i] = d;
      }
    }

    double best = 0;
    var bestI = 0, bestJ = 0, bestK = 0;
    for (var i = 0; i < n - 2; i++) {
      for (var j = i + 1; j < n - 1; j++) {
        final dij = dist[i][j];
        for (var k = j + 1; k < n; k++) {
          final perim = dij + dist[j][k] + dist[k][i];
          if (perim > best) {
            // FAI rule-of-thumb: the shortest leg must be >= 28% of perimeter.
            final legs = [dij, dist[j][k], dist[k][i]];
            final shortest = legs.reduce(math.min);
            if (shortest >= 0.28 * perim) {
              best = perim;
              bestI = i;
              bestJ = j;
              bestK = k;
            }
          }
        }
      }
    }

    if (best <= 0) return (0.0, false);

    // Closed if the leg from the point before the first vertex back to the
    // point after the last vertex is within 5% of the perimeter. Approximate by
    // checking the start→end closing distance against the tolerance.
    final closingDist = _haversineM(
      pts[bestI].data.latitude,
      pts[bestI].data.longitude,
      pts[bestK].data.latitude,
      pts[bestK].data.longitude,
    );
    final closed = closingDist <= 0.05 * best;
    // bestJ participates via the perimeter; silence unused-in-release hints.
    assert(bestJ >= 0);
    return (best, closed);
  }

  /// Max points fed to the O(n³) FAI search.
  static const int _faiMaxPoints = 120;

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);
}
