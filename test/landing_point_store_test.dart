import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/landing_point_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LandingPoint', () {
    test('rejects invalid coordinates and blank names', () {
      expect(
        LandingPoint.create(name: 'x', latitude: 91, longitude: 0),
        isNull,
      );
      expect(
        LandingPoint.create(name: 'x', latitude: 0, longitude: double.nan),
        isNull,
      );
      expect(
        LandingPoint.create(name: '  \u0007 ', latitude: 1, longitude: 2),
        isNull,
      );
    });

    test('sanitizes name and preserves location metadata through JSON', () {
      final point = LandingPoint.create(
        name: ' Ridge\u0000 Launch ',
        latitude: 46.5197,
        longitude: 6.6323,
        altitudeM: 1420.5,
        gpsAccuracyM: 4.2,
        notes: 'Road access',
        createdAt: DateTime.utc(2026, 10, 22),
      )!;
      final restored = LandingPoint.tryParse(
        jsonDecode(jsonEncode(point.toJson())),
      );

      expect(restored?.id, point.id);
      expect(restored?.name, 'Ridge Launch');
      expect(restored?.latitude, 46.5197);
      expect(restored?.longitude, 6.6323);
      expect(restored?.altitudeM, 1420.5);
      expect(restored?.gpsAccuracyM, 4.2);
      expect(restored?.notes, 'Road access');
      expect(restored?.createdAt, point.createdAt);
    });

    test('ignores malformed persisted records', () {
      expect(LandingPoint.tryParse({'id': 'a', 'name': 5}), isNull);
      expect(LandingPoint.tryParse('not a record'), isNull);
    });
  });

  group('LandingPointStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'automatically finds the nearest point and persists only the default',
      () async {
        final store = LandingPointStore.instance;
        await store.load();
        final defaultPoint = LandingPoint.create(
          name: 'Home LZ',
          latitude: 10,
          longitude: 20,
          altitudeM: 300,
        )!;
        final nearbyPoint = LandingPoint.create(
          name: 'Valley LZ',
          latitude: 11,
          longitude: 21,
          altitudeM: 120,
        )!;

        await store.add(defaultPoint);
        await store.setDefault(defaultPoint.id);
        await store.add(nearbyPoint);
        expect(store.defaultPoint?.id, defaultPoint.id);
        expect(store.nearestPointTo(10.9, 20.9)?.id, nearbyPoint.id);
        expect(store.nearestPointTo(10, 20)?.id, defaultPoint.id);
        expect(store.nearestPointTo(double.nan, 0), isNull);

        await store.remove(nearbyPoint.id);
        expect(store.defaultPoint?.id, defaultPoint.id);
        expect(store.nearestPointTo(10.9, 20.9)?.id, defaultPoint.id);

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('pb.landingPoints.v1');
        expect(raw, contains('Home LZ'));
        expect(raw, isNot(contains('Valley LZ')));
        final persisted = jsonDecode(raw!) as Map;
        expect(persisted['defaultId'], defaultPoint.id);
        expect(persisted.containsKey('lastId'), isFalse);
      },
    );
  });
}
