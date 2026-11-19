import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/live_pilot_map_marker.dart';
import 'package:parabeacon/controls/pilot_direction_arrow.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:parabeacon/data/live_tracking_service.dart';
import 'package:parabeacon/data/pilot_course.dart';
import 'package:parabeacon/data/xcontest_live_tracking_service.dart';

void main() {
  testWidgets('draws a direction arrow over a public pilot marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 100,
            child: PilotDirectionArrow(
              headingDegrees: 90,
              mapRotationDegrees: 0,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('derives a stable bearing from consecutive pilot positions', () {
    expect(GeoMath.bearingDegrees(0, 0, 0, 0.001), closeTo(90, 0.1));
    expect(GeoMath.bearingDegrees(0, 179.999, 0, -179.999), closeTo(90, 0.1));
    expect(GeoMath.bearingDegrees(0, 0, 0.001, 0), closeTo(0, 0.1));
  });

  test('rejects stationary, noisy, stale, and out-of-order course samples', () {
    final now = DateTime.utc(2026, 11, 18, 12);
    final origin = DateTime.utc(2026, 11, 18, 11, 59, 59);
    expect(
      PilotCourse.fromPositions(
        previousLatitude: 0,
        previousLongitude: 0,
        previousTimestamp: origin,
        latitude: 0,
        longitude: 0,
        timestamp: now,
        now: now,
      ),
      isNull,
    );
    expect(
      PilotCourse.fromPositions(
        previousLatitude: 0,
        previousLongitude: 0,
        previousTimestamp: origin,
        latitude: 0,
        longitude: 0.00001,
        timestamp: now,
        now: now,
      ),
      isNull,
    );
    expect(
      PilotCourse.fromPositions(
        previousLatitude: 0,
        previousLongitude: 0,
        previousTimestamp: now,
        latitude: 0,
        longitude: 0.001,
        timestamp: origin,
        now: now,
      ),
      isNull,
    );
    expect(
      PilotCourse.fromPositions(
        previousLatitude: 0,
        previousLongitude: 0,
        previousTimestamp: origin.subtract(const Duration(minutes: 2)),
        latitude: 0,
        longitude: 0.001,
        timestamp: now,
        now: now,
      ),
      isNull,
    );
  });

  test('uses a fresh moving heading and compensates for map rotation', () {
    expect(
      PilotCourse.fromHeading(headingDegrees: 270, speedMetersPerSecond: 12),
      270,
    );
    expect(
      PilotCourse.fromHeading(headingDegrees: 270, speedMetersPerSecond: 0.5),
      isNull,
    );
    expect(
      PilotCourse.screenDegrees(courseDegrees: 90, mapRotationDegrees: 0),
      90,
    );
    expect(
      PilotCourse.screenDegrees(courseDegrees: 90, mapRotationDegrees: -90),
      0,
    );
    expect(
      PilotCourse.screenDegrees(courseDegrees: 0, mapRotationDegrees: -450),
      270,
    );
  });

  test('anchors the shared pilot avatar center to its map coordinate', () {
    final marker = LivePilotMapMarker.markerAlignment;
    expect(
      (marker.y + 1) * LivePilotMapMarker.markerHeight / 2,
      closeTo(LivePilotMapMarker.glyphCenterFromTop, 1e-10),
    );
  });

  test('tracker derives course only from fresh increasing moving fixes', () {
    final tracker = PilotCourseTracker();
    final start = DateTime.utc(2026, 11, 18, 12);
    expect(
      tracker.update(
        pilotId: 'flight-1',
        latitude: 0,
        longitude: 179.999,
        timestamp: start,
        now: start,
      ),
      isNull,
    );
    expect(
      tracker.update(
        pilotId: 'flight-1',
        latitude: 0,
        longitude: -179.999,
        timestamp: start.add(const Duration(seconds: 1)),
        now: start.add(const Duration(seconds: 1)),
      ),
      closeTo(90, 0.1),
    );
    expect(
      tracker.update(
        pilotId: 'flight-1',
        latitude: 0.001,
        longitude: -179.999,
        timestamp: start.add(const Duration(seconds: 1)),
        now: start.add(const Duration(seconds: 2)),
      ),
      closeTo(90, 0.1),
      reason:
          'duplicate/out-of-order frames do not replace the last accepted course',
    );
    expect(
      tracker.update(
        pilotId: 'flight-1',
        latitude: 0,
        longitude: -179.999,
        timestamp: start.add(const Duration(seconds: 2)),
        now: start.add(const Duration(seconds: 2)),
        landed: true,
      ),
      isNull,
    );
    tracker.retainPilots(const {});
    expect(
      tracker.update(
        pilotId: 'flight-1',
        latitude: 0,
        longitude: -179.998,
        timestamp: start.add(const Duration(seconds: 3)),
        now: start.add(const Duration(seconds: 3)),
      ),
      isNull,
      reason:
          'newly seen pilots wait for a second fresh fix before showing an arrow',
    );
  });

  test(
    'public pilot models accept optional course without changing defaults',
    () {
      const pilot = LiveOtherPilot(
        flightId: 'flight-1',
        lat: 0,
        lon: 0,
        name: 'Pilot',
        glider: '',
        altitude: 1000,
        landed: false,
        colorArgb: 0xff0000ff,
      );
      expect(pilot.headingDegrees, isNull);

      final publicPilot = PublicPilotLocation(
        pilotName: 'Pilot',
        latitude: 0,
        longitude: 0,
        observedAt: DateTime.utc(2026),
        headingDegrees: 270,
      );
      expect(publicPilot.headingDegrees, 270);
    },
  );
}
