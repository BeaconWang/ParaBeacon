import 'dart:math' as math;

import '../geo_math.dart';
import 'competition_task.dart';

/// A geographic point expressed in local planar metres relative to a reference
/// origin (equirectangular projection). Good enough for task-scale optimization
/// (tens to a few hundred kilometres).
class _PlanarPoint {
  _PlanarPoint(this.x, this.y);
  double x;
  double y;

  double distanceTo(_PlanarPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// The result of optimizing a [CompetitionTask]: the touch-point on each
/// turnpoint cylinder that yields the shortest route, plus the derived
/// distances used by the competition widgets.
class OptimizedTask {
  OptimizedTask({
    required this.optimizedLat,
    required this.optimizedLon,
    required this.cumulativeToGoalM,
    required this.totalDistanceM,
    required this.speedSectionDistanceM,
    required this.centerDistanceM,
  });

  /// Latitude of each turnpoint's optimized touch point (one per turnpoint).
  final List<double> optimizedLat;

  /// Longitude of each turnpoint's optimized touch point.
  final List<double> optimizedLon;

  /// Optimized distance (metres) remaining from each turnpoint's touch point
  /// to goal, following the optimized route through the later cylinders.
  final List<double> cumulativeToGoalM;

  /// Total optimized task distance from the first to the last turnpoint.
  final double totalDistanceM;

  /// Optimized distance of the speed section (SSS → ESS). 0 when undefined.
  final double speedSectionDistanceM;

  /// Straight centre-to-centre task distance (unoptimized), for reference.
  final double centerDistanceM;

  bool get isEmpty => optimizedLat.isEmpty;
}

/// Computes the shortest route that stays legal with respect to every cylinder,
/// using the classic iterative "touch-point relaxation" used by XCTrack-style
/// instruments:
///
/// 1. Project each turnpoint centre onto a local planar grid (metres).
/// 2. Seed every touch point at its cylinder centre.
/// 3. Repeatedly move each touch point to the point on its own circle that
///    minimizes `dist(prev → p) + dist(p → next)` — approximated by placing it
///    on the circle along the bisector of the directions to its neighbours.
/// 4. Repeat until the touch points converge.
///
/// Endpoints (first/last turnpoint) are relaxed toward their single neighbour.
/// Final distances are recomputed geodesically for accuracy.
abstract final class TaskOptimizer {
  static OptimizedTask optimize(CompetitionTask task) {
    final tps = task.turnpoints;
    final n = tps.length;
    if (n == 0) {
      return OptimizedTask(
        optimizedLat: const [],
        optimizedLon: const [],
        cumulativeToGoalM: const [],
        totalDistanceM: 0,
        speedSectionDistanceM: 0,
        centerDistanceM: 0,
      );
    }

    // Reference origin = centroid of all centres (keeps the planar distortion
    // symmetric across the task area).
    var refLat = 0.0;
    var refLon = 0.0;
    for (final t in tps) {
      refLat += t.latitude;
      refLon += t.longitude;
    }
    refLat /= n;
    refLon /= n;

    const metresPerDegLat = 111320.0;
    final metresPerDegLon =
        metresPerDegLat * math.cos(refLat * math.pi / 180.0).abs();
    final safeLonScale = metresPerDegLon < 1e-6 ? 1e-6 : metresPerDegLon;

    _PlanarPoint project(double lat, double lon) => _PlanarPoint(
      (lon - refLon) * safeLonScale,
      (lat - refLat) * metresPerDegLat,
    );
    List<double> unproject(_PlanarPoint p) => [
      refLat + p.y / metresPerDegLat,
      refLon + p.x / safeLonScale,
    ];

    final centers = [for (final t in tps) project(t.latitude, t.longitude)];
    final radii = [for (final t in tps) t.radiusMeters];

    // Seed the touch points at the centres.
    final touch = [for (final c in centers) _PlanarPoint(c.x, c.y)];

    if (n == 1) {
      final ll = unproject(touch[0]);
      return OptimizedTask(
        optimizedLat: [ll[0]],
        optimizedLon: [ll[1]],
        cumulativeToGoalM: const [0.0],
        totalDistanceM: 0,
        speedSectionDistanceM: 0,
        centerDistanceM: 0,
      );
    }

    // Relaxation sweeps.
    for (var iteration = 0; iteration < 150; iteration++) {
      var maxShift = 0.0;
      for (var i = 0; i < n; i++) {
        final radius = radii[i];
        if (radius <= 0) continue;
        final center = centers[i];

        // Determine the aim direction from the circle centre.
        double aimX;
        double aimY;
        if (i == 0) {
          final next = touch[i + 1];
          aimX = next.x - center.x;
          aimY = next.y - center.y;
        } else if (i == n - 1) {
          final prev = touch[i - 1];
          aimX = prev.x - center.x;
          aimY = prev.y - center.y;
        } else {
          final prev = touch[i - 1];
          final next = touch[i + 1];
          final toPrev = _normalize(prev.x - center.x, prev.y - center.y);
          final toNext = _normalize(next.x - center.x, next.y - center.y);
          aimX = toPrev[0] + toNext[0];
          aimY = toPrev[1] + toNext[1];
          // Degenerate (opposite directions): keep the previous touch point so
          // the route passes straight through the centre neighbourhood.
          if (aimX.abs() < 1e-9 && aimY.abs() < 1e-9) {
            aimX = touch[i].x - center.x;
            aimY = touch[i].y - center.y;
          }
        }
        final norm = _normalize(aimX, aimY);
        final newX = center.x + norm[0] * radius;
        final newY = center.y + norm[1] * radius;
        final shift = math.sqrt(
          (newX - touch[i].x) * (newX - touch[i].x) +
              (newY - touch[i].y) * (newY - touch[i].y),
        );
        if (shift > maxShift) maxShift = shift;
        touch[i].x = newX;
        touch[i].y = newY;
      }
      if (maxShift < 0.5) break; // converged to within half a metre
    }

    final optimizedLat = <double>[];
    final optimizedLon = <double>[];
    for (final p in touch) {
      final ll = unproject(p);
      optimizedLat.add(ll[0]);
      optimizedLon.add(ll[1]);
    }

    // Geodesic leg distances between consecutive optimized touch points.
    final legs = <double>[];
    for (var i = 0; i < n - 1; i++) {
      legs.add(
        GeoMath.distanceMeters(
          optimizedLat[i],
          optimizedLon[i],
          optimizedLat[i + 1],
          optimizedLon[i + 1],
        ),
      );
    }

    // Cumulative distance from each turnpoint to the goal.
    final cumulative = List<double>.filled(n, 0);
    for (var i = n - 2; i >= 0; i--) {
      cumulative[i] = cumulative[i + 1] + legs[i];
    }
    final total = cumulative.isEmpty ? 0.0 : cumulative[0];

    // Speed-section distance (SSS → ESS).
    var speedSection = 0.0;
    final sss = task.sssIndex;
    final ess = task.essIndex;
    if (sss != null && ess != null && ess > sss) {
      for (var i = sss; i < ess; i++) {
        speedSection += legs[i];
      }
    }

    // Straight centre-to-centre reference distance.
    var centerDistance = 0.0;
    for (var i = 0; i < n - 1; i++) {
      centerDistance += GeoMath.distanceMeters(
        tps[i].latitude,
        tps[i].longitude,
        tps[i + 1].latitude,
        tps[i + 1].longitude,
      );
    }

    return OptimizedTask(
      optimizedLat: optimizedLat,
      optimizedLon: optimizedLon,
      cumulativeToGoalM: cumulative,
      totalDistanceM: total,
      speedSectionDistanceM: speedSection,
      centerDistanceM: centerDistance,
    );
  }

  static List<double> _normalize(double x, double y) {
    final len = math.sqrt(x * x + y * y);
    if (len < 1e-9) return const [0.0, 0.0];
    return [x / len, y / len];
  }
}
