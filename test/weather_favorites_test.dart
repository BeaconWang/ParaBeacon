import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/weather_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FavoritePlace', () {
    test('rejects out-of-range and NaN coordinates', () {
      expect(FavoritePlace.create(name: 'x', lat: 91, lon: 0), isNull);
      expect(FavoritePlace.create(name: 'x', lat: 0, lon: 181), isNull);
      expect(FavoritePlace.create(name: 'x', lat: double.nan, lon: 0), isNull);
    });

    test('rejects a name that is blank after sanitizing', () {
      expect(FavoritePlace.create(name: '  \u0007 ', lat: 1, lon: 2), isNull);
    });

    test('strips control characters and caps the name length', () {
      final place = FavoritePlace.create(
        name: 'A\u0000B${'c' * 200}',
        lat: 1,
        lon: 2,
      );
      expect(place, isNotNull);
      expect(place!.name.startsWith('AB'), isTrue);
      expect(place.name.length, lessThanOrEqualTo(FavoritePlace.maxNameLength));
    });

    test('tryParse refuses entries with wrong types', () {
      expect(FavoritePlace.tryParse({'name': 1, 'lat': 0, 'lon': 0}), isNull);
      expect(
          FavoritePlace.tryParse({'name': 'x', 'lat': 'y', 'lon': 0}), isNull);
      expect(FavoritePlace.tryParse('not a map'), isNull);
      final ok = FavoritePlace.tryParse({'name': 'x', 'lat': 1, 'lon': 2});
      expect(ok?.name, 'x');
      expect(ok?.lat, 1);
    });
  });

  group('WeatherFavoritesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('re-saving the same spot replaces the entry instead of duplicating',
        () async {
      final store = WeatherFavoritesStore.instance;
      await store.load();

      await store.add(FavoritePlace(name: 'Old', lat: 30.5, lon: 114.3));
      // Well within the ~50 m "same spot" epsilon.
      await store.add(FavoritePlace(name: 'New', lat: 30.50002, lon: 114.30002));

      final matching =
          store.places.where((p) => (p.lat - 30.5).abs() < 0.001).toList();
      expect(matching.length, 1);
      expect(matching.single.name, 'New');

      await store.removeSpot(30.5, 114.3);
      expect(store.contains(30.5, 114.3), isFalse);
    });

    test('contains tolerates a small offset but not a different city',
        () async {
      final store = WeatherFavoritesStore.instance;
      await store.load();
      await store.add(FavoritePlace(name: 'Spot', lat: 46.5197, lon: 6.6323));

      expect(store.contains(46.51971, 6.63231), isTrue);
      expect(store.contains(46.6, 6.6323), isFalse);

      await store.removeSpot(46.5197, 6.6323);
    });
  });
}
