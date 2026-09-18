// On-device verification of the Weather screen's location search.
//
// Unlike the unit tests (which mock the HTTP client), this suite runs on a
// real Android device and talks to the live geocoding providers through the
// phone's own network stack. That is the environment where the original
// "search sometimes fails" bug appeared — a mobile-carrier exit IP getting
// rate-limited (HTTP 429) or blocked (HTTP 403) by Nominatim — so it can only
// be validated here.
//
// Run with:
//   flutter test integration_test/geocoding_device_test.dart -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parabeacon/data/geocoding_service.dart';
import 'package:parabeacon/data/weather_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Queries that exercise the whole provider chain: ASCII and CJK. Every one
  // is a populated place, so GeoNames (the Open-Meteo provider) carries it
  // even when Nominatim cannot be reached.
  //
  // Note what is deliberately *not* here: 小径湾. It is a motorway junction —
  // present in OpenStreetMap, absent from GeoNames — so it only resolves when
  // Nominatim is reachable or an AMap key is configured. Asserting it here
  // would make the suite fail on networks that block Nominatim, which is the
  // very condition this chain exists to survive.
  const queries = <String>[
    'Hong Kong',
    '香港',
    '长沙',
    'Interlaken',
    '岳阳',
  ];

  group('GeocodingService on device', () {
    testWidgets('resolves every representative query against live providers',
        (tester) async {
      final service = GeocodingService.instance;
      final failed = <String>[];
      final empty = <String>[];

      for (final q in queries) {
        try {
          final results = await service.search(q, language: 'zh');
          if (results.isEmpty) {
            empty.add(q);
            debugPrint('DEVICE "$q" -> no match');
            continue;
          }
          final first = results.first;
          // Every candidate must carry usable coordinates and labels.
          for (final p in results) {
            expect(p.lat, inInclusiveRange(-90, 90));
            expect(p.lon, inInclusiveRange(-180, 180));
            expect(p.name, isNotEmpty);
            expect(p.displayName, isNotEmpty);
          }
          debugPrint('DEVICE "$q" -> ${results.length} results | '
              'first=${first.name} '
              '(${first.lat.toStringAsFixed(4)},'
              '${first.lon.toStringAsFixed(4)})');
        } on WeatherException catch (e) {
          failed.add('$q (${e.error.name})');
          debugPrint('DEVICE "$q" -> FAILED ${e.error.name}');
        }
      }

      // The whole point of the failover chain: no query may hard-fail while
      // the device has connectivity.
      expect(failed, isEmpty,
          reason: 'the provider chain should have served these queries');
      expect(empty, isEmpty,
          reason: 'all representative queries are known places');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('a concurrent burst is served without failures',
        (tester) async {
      final service = GeocodingService.instance;
      final stopwatch = Stopwatch()..start();
      var failures = 0;

      // Fire all at once, the way a fast typist plus a keyboard submit did in
      // the original bug report.
      final results = await Future.wait([
        for (final q in ['Bern', 'Berlin', 'Basel', 'Biel', 'Brig', 'Baden'])
          service.search(q).catchError((Object _) {
            failures++;
            return const <GeocodedPlace>[];
          }),
      ]);
      stopwatch.stop();

      debugPrint('DEVICE burst: counts=${results.map((e) => e.length).toList()} '
          'failures=$failures elapsed=${stopwatch.elapsedMilliseconds}ms');

      // The point of the burst is that concurrency never turns into an error:
      // whichever provider answers, every query gets a result set.
      expect(failures, 0,
          reason: 'a concurrent burst must not produce failures');
      for (final r in results) {
        expect(r, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('an unknown place reports no match instead of an error',
        (tester) async {
      final results = await GeocodingService.instance
          .search('zzzzqqq-not-a-real-place-42');
      expect(results, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('reverse geocoding either names a coordinate or degrades to '
        'null', (tester) async {
      // Reverse geocoding is Nominatim-only and purely a cosmetic nicety for
      // the panel header, so on a network that blocks Nominatim the contract
      // is "returns null quickly", not "throws" and not "hangs".
      final sw = Stopwatch()..start();
      final name = await GeocodingService.instance
          .reverseName(lat: 22.2783, lon: 114.1747, language: 'zh');
      sw.stop();
      debugPrint('DEVICE reverseName(22.2783,114.1747) -> $name '
          '(${sw.elapsedMilliseconds}ms)');
      if (name != null) expect(name, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
