import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/data/airspace_store.dart';

void main() {
  test('unchanged proximity is not emitted again', () async {
    final store = AirspaceStore.instance;
    store.loadOpenAirString('''
AC C
AN Test airspace
AL SFC
AH 3000 M
DP 47:00:00 N 008:00:00 E
DP 47:01:00 N 008:00:00 E
DP 47:01:00 N 008:01:00 E
DP 47:00:00 N 008:01:00 E
''');

    final emissions = <List<AirspaceProximity>>[];
    final subscription = store.proximityStream.listen(emissions.add);
    store.updatePosition(47.005, 8.005, 100);
    store.updatePosition(47.005, 8.005, 100);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    store.updatePosition(47.005, 8.005, 4000);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(2));
    expect(emissions.last.single.verticalM, greaterThan(0));

    await subscription.cancel();
    store.loadOpenAirString('');
    store.updatePosition(47.005, 8.005, 100);
  });

  test('nearest(N) returns the closest airspaces, size is detected', () {
    final store = AirspaceStore.instance;
    // Three 0.01°-wide square airspaces at increasing longitudes, so their
    // distance from a western observer is strictly ordered far..near.
    store.loadOpenAirString('''
AC C
AN Far
DP 47:00:00 N 010:00:00 E
DP 47:00:36 N 010:00:00 E
DP 47:00:36 N 010:00:36 E
DP 47:00:00 N 010:00:36 E
AC C
AN Mid
DP 47:00:00 N 009:00:00 E
DP 47:00:36 N 009:00:00 E
DP 47:00:36 N 009:00:36 E
DP 47:00:00 N 009:00:36 E
AC C
AN Near
DP 47:00:00 N 008:00:00 E
DP 47:00:36 N 008:00:00 E
DP 47:00:36 N 008:00:36 E
DP 47:00:00 N 008:00:36 E
''');
    expect(store.all, hasLength(3));

    // Bounding-box size is derived from the polygon (0.01° ≈ 1113 m N-S).
    final near = store.all.firstWhere((a) => a.name == 'Near');
    expect(near.heightM, closeTo(1113.2, 5));
    expect(near.widthM, greaterThan(0));
    expect(near.diagonalM, greaterThan(near.heightM));

    // West of all three: nearest-first ordering must be Near, Mid, Far.
    store.updatePosition(47.003, 7.5, 100);
    final nearestTwo = store.nearest(2);
    expect(nearestTwo.map((a) => a.name).toList(), ['Near', 'Mid']);

    // N larger than the dataset is clamped; 0 draws nothing.
    expect(store.nearest(99), hasLength(3));
    expect(store.nearest(0), isEmpty);

    store.loadOpenAirString('');
  });
}
