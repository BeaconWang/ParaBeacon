import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/wind_estimator.dart';

void main() {
  group('WindEstimator', () {
    test('recovers wind from the XCTrack velocity-circle model', () {
      final estimator = WindEstimator();
      final start = DateTime.utc(2026, 10, 20);
      final trimSpeedMps = 38.0 / 3.6;
      const windEastMps = 3.0;
      const windNorthMps = 4.0;

      WindEstimate? estimate;
      for (var i = 0; i < 5; i++) {
        final airHeading = i * 72.0 * math.pi / 180.0;
        final groundEast = windEastMps + trimSpeedMps * math.sin(airHeading);
        final groundNorth = windNorthMps + trimSpeedMps * math.cos(airHeading);
        final groundSpeed = math.sqrt(
          groundEast * groundEast + groundNorth * groundNorth,
        );
        final course = math.atan2(groundEast, groundNorth) * 180.0 / math.pi;

        estimate = estimator.add(
          groundSpeedMps: groundSpeed,
          headingDeg: course,
          time: start.add(Duration(seconds: i)),
        );
        if (i < 4) expect(estimate, isNull);
      }

      expect(estimate, isNotNull);
      expect(estimate!.confident, isTrue);
      expect(estimate.speedMps, closeTo(5.0, 1e-9));
      expect(
        estimate.fromDirectionDeg,
        closeTo(
          math.atan2(windEastMps, windNorthMps) * 180.0 / math.pi + 180.0,
          1e-9,
        ),
      );
    });

    test('does not count a repeated GPS timestamp as another fix', () {
      final estimator = WindEstimator();
      final start = DateTime.utc(2026, 10, 20);
      const airspeed = 38.0 / 3.6;
      WindEstimate? estimate;

      for (var i = 0; i < 5; i++) {
        final heading = i * 72.0;
        final radians = heading * math.pi / 180.0;
        final east = 3.0 + airspeed * math.sin(radians);
        final north = 4.0 + airspeed * math.cos(radians);
        estimate = estimator.add(
          groundSpeedMps: math.sqrt(east * east + north * north),
          headingDeg: math.atan2(east, north) * 180.0 / math.pi,
          time: start.add(Duration(seconds: i)),
        );
      }

      final repeated = estimator.add(
        groundSpeedMps: 1.0,
        headingDeg: 180.0,
        time: start.add(const Duration(seconds: 4)),
      );

      expect(repeated?.speedMps, closeTo(estimate!.speedMps, 1e-12));
      expect(
        repeated?.fromDirectionDeg,
        closeTo(estimate.fromDirectionDeg, 1e-12),
      );
    });
  });
}
