import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/navigation_store.dart';

void main() {
  test('rejects malformed or unsafe waypoint JSON', () {
    expect(
      Waypoint.fromJson({'name': 'x', 'lat': 999, 'lon': 0, 'radiusM': 100}),
      isNull,
    );
    expect(
      Waypoint.fromJson({'name': '', 'lat': 0, 'lon': 0, 'radiusM': 100}),
      isNull,
    );
    expect(
      Waypoint.fromJson({'name': 'x', 'lat': 0, 'lon': 0, 'radiusM': 100}),
      isNotNull,
    );
  });

  test('computes target bearing and advances after arrival', () async {
    final store = NavigationStore.instance;
    await store.setTask(
      const NavigationTask(
        name: 'Test',
        waypoints: [
          Waypoint(name: 'North', latitude: 1, longitude: 0, radiusM: 200),
          Waypoint(name: 'East', latitude: 1, longitude: 1, radiusM: 200),
        ],
      ),
    );

    store.update(const FlightData(latitude: 0, longitude: 0, hasFix: true));
    expect(store.snapshot.activeIndex, 0);
    expect(store.snapshot.bearingDeg, closeTo(0, 0.5));
    expect(store.snapshot.distanceM, closeTo(111195, 500));

    store.update(const FlightData(latitude: 1, longitude: 0, hasFix: true));
    expect(store.snapshot.activeIndex, 1);
    expect(store.snapshot.target?.name, 'East');
    expect(store.snapshot.bearingDeg, closeTo(90, 1));

    await store.setTask(null);
  });
}
