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
    this.faiTriangleLegsM = const [],
    this.faiClosingM = 0,
    this.flatTriangleM = 0,
    this.flatTriangleLegsM = const [],
    this.flatClosingM = 0,
    this.flatClosed = false,
    this.threeTurnpointM = 0,
    this.threeTurnpointLegsM = const [],
    this.maxAltGainM = 0,
    this.elevationDropM = 0,
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

  /// The three side lengths (meters) of the best FAI triangle, or empty when
  /// none was found. Order is around the triangle (leg1, leg2, leg3).
  final List<double> faiTriangleLegsM;

  /// Closing-gap distance (meters) of the best FAI triangle — how far apart the
  /// circuit's entry and exit points are. Smaller is a "rounder" triangle.
  final double faiClosingM;

  /// Best "flat" (free) triangle scored distance (perimeter − closing gap),
  /// meters. Unlike the FAI triangle this has no shortest-leg constraint, only
  /// the 20% closing rule. 0 when no qualifying triangle exists.
  final double flatTriangleM;

  /// The three side lengths (meters) of the best flat triangle, or empty.
  final List<double> flatTriangleLegsM;

  /// Closing-gap distance (meters) of the best flat triangle.
  final double flatClosingM;

  /// Whether the best flat triangle closes within 5% of its perimeter.
  final bool flatClosed;

  /// Best free distance over three turnpoints (five chronological points,
  /// four legs), meters — the classic XC "open distance" metric. 0 when the
  /// track is too short.
  final double threeTurnpointM;

  /// The four leg lengths (meters) of the best 3-turnpoint route, or empty.
  final List<double> threeTurnpointLegsM;

  /// Height of the single biggest climb (meters): the largest gain from a
  /// local low to a later high over the flight.
  final double maxAltGainM;

  /// Elevation drop (meters): launch altitude minus the lowest altitude seen.
  final double elevationDropM;

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

    // Biggest single climb (trough→peak) and the global altitude extremes for
    // the elevation-drop metric. Seeded with the launch altitude.
    final launchAlt = first.data.altitude;
    double minSoFar = launchAlt;
    double maxAltGain = 0;
    double globalMin = launchAlt;

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

      // Max single-climb height and running altitude extremes.
      final alt = b.data.altitude;
      final gain = alt - minSoFar;
      if (gain > maxAltGain) maxAltGain = gain;
      if (alt < minSoFar) minSoFar = alt;
      if (alt < globalMin) globalMin = alt;

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

    final routes = _bestRoutes(s);

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
      faiTriangleM: routes.faiTotalM,
      faiClosed: routes.faiClosed,
      faiTriangleLegsM: routes.faiLegsM,
      faiClosingM: routes.faiClosingM,
      flatTriangleM: routes.flatTotalM,
      flatTriangleLegsM: routes.flatLegsM,
      flatClosingM: routes.flatClosingM,
      flatClosed: routes.flatClosed,
      threeTurnpointM: routes.threeTurnpointM,
      threeTurnpointLegsM: routes.threeTurnpointLegsM,
      maxAltGainM: maxAltGain,
      elevationDropM: (launchAlt - globalMin).clamp(0.0, double.infinity),
    );
  }

  /// Searches the track for the standard cross-country routes XC scorers show:
  /// the best free distance over three turnpoints, and the best flat and FAI
  /// triangles.
  ///
  /// A full search is infeasible on long tracks, so the track is first reduced
  /// to at most [_routeMaxPoints] evenly-spaced points; the (O(n³) triangle /
  /// O(n²) distance) searches then run on that reduced set. This is a solid
  /// approximation — it converges on the official XContest optimizer as the
  /// resolution rises — but is not a certified scoring engine.
  ///
  /// Triangle scoring mirrors XContest: the three turnpoints are chosen to
  /// maximize the triangle perimeter subject to the circuit "closing" within
  /// 20% of that perimeter (an FAI triangle additionally requires the shortest
  /// leg to be ≥ 28% of the perimeter). The reported triangle distance is the
  /// perimeter minus the closing gap.
  static _RouteStats _bestRoutes(List<FlightSample> s) {
    if (s.length < 3) return _RouteStats.empty;

    // Downsample to a manageable point count.
    final pts = <FlightSample>[];
    if (s.length <= _routeMaxPoints) {
      pts.addAll(s);
    } else {
      final stride = s.length / _routeMaxPoints;
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

    // ── Free distance over three turnpoints (five ordered points, four legs).
    // dp[p][j] = best total path using p points and ending at index j.
    const p = 5;
    const neg = -1e18;
    final dp = List.generate(p, (_) => List<double>.filled(n, neg));
    final par = List.generate(p, (_) => List<int>.filled(n, -1));
    for (var j = 0; j < n; j++) {
      dp[0][j] = 0;
    }
    for (var step = 1; step < p; step++) {
      for (var j = 0; j < n; j++) {
        var best = neg, bi = -1;
        for (var i = 0; i < j; i++) {
          final c = dp[step - 1][i] + dist[i][j];
          if (c > best) {
            best = c;
            bi = i;
          }
        }
        dp[step][j] = best;
        par[step][j] = bi;
      }
    }
    var tpTotal = 0.0;
    var tpEnd = -1;
    for (var j = 0; j < n; j++) {
      if (dp[p - 1][j] > tpTotal) {
        tpTotal = dp[p - 1][j];
        tpEnd = j;
      }
    }
    final tpLegs = <double>[];
    if (tpEnd >= 0) {
      var cj = tpEnd, cp = p - 1;
      while (cp >= 1) {
        final ci = par[cp][cj];
        if (ci < 0) break;
        tpLegs.insert(0, dist[ci][cj]);
        cj = ci;
        cp--;
      }
    }

    // ── Triangles.
    // closingMin[i][k] = min distance between any point ≤ i and any point ≥ k,
    // i.e. the smallest gap to close a circuit entered at/after i and exited
    // at/before k. Built in two O(n²) passes.
    final h = List.generate(n, (_) => List<double>.filled(n, 1e18));
    for (var i = 0; i < n; i++) {
      for (var k = n - 1; k >= 0; k--) {
        final next = k + 1 < n ? h[i][k + 1] : 1e18;
        h[i][k] = math.min(next, dist[i][k]);
      }
    }
    final closingMin = List.generate(n, (_) => List<double>.filled(n, 1e18));
    for (var i = 0; i < n; i++) {
      for (var k = 0; k < n; k++) {
        final up = i > 0 ? closingMin[i - 1][k] : 1e18;
        closingMin[i][k] = math.min(up, h[i][k]);
      }
    }

    var flatPerim = 0.0, flatClosing = 0.0;
    List<double> flatLegs = const [];
    var faiPerim = 0.0, faiClosing = 0.0;
    List<double> faiLegs = const [];
    for (var i = 0; i < n - 2; i++) {
      for (var j = i + 1; j < n - 1; j++) {
        final dij = dist[i][j];
        for (var k = j + 1; k < n; k++) {
          final perim = dij + dist[j][k] + dist[k][i];
          if (perim <= 0) continue;
          final closing = closingMin[i][k];
          if (closing > 0.20 * perim) continue; // must close within 20%
          if (perim > flatPerim) {
            flatPerim = perim;
            flatClosing = closing;
            flatLegs = [dij, dist[j][k], dist[k][i]];
          }
          final shortest = math.min(dij, math.min(dist[j][k], dist[k][i]));
          if (shortest >= 0.28 * perim && perim > faiPerim) {
            faiPerim = perim;
            faiClosing = closing;
            faiLegs = [dij, dist[j][k], dist[k][i]];
          }
        }
      }
    }

    return _RouteStats(
      threeTurnpointM: tpTotal,
      threeTurnpointLegsM: tpLegs,
      flatTotalM: flatPerim > 0 ? (flatPerim - flatClosing) : 0.0,
      flatLegsM: flatLegs,
      flatClosingM: flatClosing,
      flatClosed: flatPerim > 0 && flatClosing <= 0.05 * flatPerim,
      faiTotalM: faiPerim > 0 ? (faiPerim - faiClosing) : 0.0,
      faiLegsM: faiLegs,
      faiClosingM: faiClosing,
      faiClosed: faiPerim > 0 && faiClosing <= 0.05 * faiPerim,
    );
  }

  /// Max points fed to the route search. Higher converges on the official
  /// optimizer at the cost of an O(n³) triangle scan; 240 keeps the on-demand
  /// detail-screen computation well under a frame budget while staying close
  /// to XContest's figures.
  static const int _routeMaxPoints = 240;

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

/// Internal result of [FlightDerivedStats._bestRoutes]: the best 3-turnpoint
/// free distance plus the best flat and FAI triangles.
class _RouteStats {
  const _RouteStats({
    required this.threeTurnpointM,
    required this.threeTurnpointLegsM,
    required this.flatTotalM,
    required this.flatLegsM,
    required this.flatClosingM,
    required this.flatClosed,
    required this.faiTotalM,
    required this.faiLegsM,
    required this.faiClosingM,
    required this.faiClosed,
  });

  final double threeTurnpointM;
  final List<double> threeTurnpointLegsM;
  final double flatTotalM;
  final List<double> flatLegsM;
  final double flatClosingM;
  final bool flatClosed;
  final double faiTotalM;
  final List<double> faiLegsM;
  final double faiClosingM;
  final bool faiClosed;

  static const _RouteStats empty = _RouteStats(
    threeTurnpointM: 0,
    threeTurnpointLegsM: [],
    flatTotalM: 0,
    flatLegsM: [],
    flatClosingM: 0,
    flatClosed: false,
    faiTotalM: 0,
    faiLegsM: [],
    faiClosingM: 0,
    faiClosed: false,
  );
}
