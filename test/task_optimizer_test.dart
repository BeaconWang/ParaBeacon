import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/task_optimizer.dart';
import 'package:parabeacon/data/geo_math.dart';

void main() {
  group('TaskOptimizer.optimizeFromStart', () {
    test('returns empty points when there are no remaining turnpoints', () {
      expect(TaskOptimizer.optimizeFromStart(46.0, 7.0, const []), [[], []]);
    });

    test('places a single touch point on the boundary toward the start', () {
      const turnpoint = Turnpoint(
        waypoint: TaskWaypoint(name: 'Goal', latitude: 0, longitude: 0),
        radiusMeters: 100,
      );

      final points = TaskOptimizer.optimizeFromStart(-0.1, 0, const [turnpoint]);

      expect(points[0], hasLength(1));
      expect(points[1], hasLength(1));
      expect(points[0][0], closeTo(-100 / 111320, 1e-9));
      expect(points[1][0], closeTo(0, 1e-9));
    });

    test('keeps multi-turnpoint touch points on their cylinders', () {
      final turnpoints = _turnpoints();
      final points = TaskOptimizer.optimizeFromStart(-0.01, -0.01, turnpoints);

      for (var i = 0; i < turnpoints.length; i++) {
        expect(
          GeoMath.distanceMeters(
            turnpoints[i].latitude,
            turnpoints[i].longitude,
            points[0][i],
            points[1][i],
          ),
          closeTo(turnpoints[i].radiusMeters, 0.5),
        );
      }
    });
  });

  test('optimize keeps multi-turnpoint touch points on their cylinders', () {
    final turnpoints = _turnpoints();
    final result = TaskOptimizer.optimize(CompetitionTask(turnpoints: turnpoints));

    for (var i = 0; i < turnpoints.length; i++) {
      expect(
        GeoMath.distanceMeters(
          turnpoints[i].latitude,
          turnpoints[i].longitude,
          result.optimizedLat[i],
          result.optimizedLon[i],
        ),
        closeTo(turnpoints[i].radiusMeters, 0.5),
      );
    }
  });
}

List<Turnpoint> _turnpoints() => const [
  Turnpoint(
    waypoint: TaskWaypoint(name: 'A', latitude: 0, longitude: 0),
    radiusMeters: 100,
  ),
  Turnpoint(
    waypoint: TaskWaypoint(name: 'B', latitude: 0.01, longitude: 0.01),
    radiusMeters: 100,
  ),
  Turnpoint(
    waypoint: TaskWaypoint(name: 'C', latitude: 0.02, longitude: 0),
    radiusMeters: 100,
  ),
];
