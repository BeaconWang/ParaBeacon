import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/pilot_direction_arrow.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:parabeacon/data/live_tracking_service.dart';
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
