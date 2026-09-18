import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/geo_name_settings.dart';
import 'package:parabeacon/data/geocoding_service.dart';
import 'package:parabeacon/data/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Host predicates — the chain is provider-based, so tests assert on which
  // host actually got contacted.
  bool isNominatim(http.Request r) =>
      r.url.host == 'nominatim.openstreetmap.org';
  bool isOpenMeteo(http.Request r) =>
      r.url.host == 'geocoding-api.open-meteo.com';
  bool isAmap(http.Request r) => r.url.host == 'restapi.amap.com';

  http.Response json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  setUp(() {
    // GeoNameSettings reads the AMap key from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  group('GeocodingService.search provider chain', () {
    test('Nominatim success answers and no fallback is contacted', () async {
      var openMeteoCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            expect(request.url.path, '/search');
            expect(request.url.queryParameters['q'], '香港');
            expect(request.headers['User-Agent'], contains('ParaBeacon'));
            return json([
              {
                'place_id': 1,
                'lat': '22.2783',
                'lon': '114.1747',
                'name': '香港',
                'display_name': '香港, China',
              },
            ]);
          }
          if (isOpenMeteo(request)) openMeteoCalls++;
          return json(<Object?>[]);
        }),
      );
      final places = await service.search('香港');
      expect(openMeteoCalls, 0);
      expect(places, hasLength(1));
      expect(places.first.name, '香港');
      expect(places.first.lat, 22.2783);
      expect(places.first.lon, 114.1747);
    });

    test('Nominatim 429 (rate-limited exit IP) falls back to Open-Meteo',
        () async {
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) return http.Response('Too many', 429);
          expect(isOpenMeteo(request), isTrue);
          expect(request.url.queryParameters['name'], '香港');
          return json({
            'results': [
              {
                'id': 1819729,
                'name': '香港',
                'latitude': 22.27832,
                'longitude': 114.17469,
                'country': '中国',
                'admin1': '香港特别行政区',
              },
            ],
          });
        }),
      );
      final places = await service.search('香港', language: 'zh');
      expect(places, hasLength(1));
      expect(places.first.name, '香港');
      expect(places.first.lat, closeTo(22.27832, 1e-9));
      expect(places.first.displayName, contains('中国'));
    });

    test('Open-Meteo fallback without matches yields an empty list, not '
        'an error (小径湾 is absent from GeoNames)', () async {
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) return http.Response('blocked', 403);
          return json({'generationtime_ms': 0.1});
        }),
      );
      expect(await service.search('小径湾'), isEmpty);
    });

    test('Transport failure on every provider throws WeatherException',
        () async {
      final service = GeocodingService.withClient(
        MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );
      await expectLater(
          service.search('香港'), throwsA(isA<WeatherException>()));
    });

    test('CJK query without an AMap key never contacts restapi.amap.com',
        () async {
      var amapCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isAmap(request)) amapCalls++;
          if (isNominatim(request)) {
            return json([
              {
                'lat': '1',
                'lon': '1',
                'name': 'x',
                'display_name': 'x',
              },
            ]);
          }
          return json(<Object?>[]);
        }),
      );
      await service.search('小径湾');
      expect(amapCalls, 0);
    });

    test('a partial failure still answers: Nominatim down + Open-Meteo '
        'reporting no match yields an empty list, not an error', () async {
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            throw http.ClientException('connection reset');
          }
          // Open-Meteo omits `results` entirely when nothing matches.
          return json({'generationtime_ms': 0.2});
        }),
      );
      expect(await service.search('nowhere-at-all'), isEmpty);
    });
  });

  group('GeocodingService.search AMap provider', () {
    setUp(() async {
      final settings = GeoNameSettings.instance;
      await settings.load();
      await settings.setAmapKey('test-key');
    });

    tearDown(() async {
      await GeoNameSettings.instance.setAmapKey(null);
    });

    test('CJK query with a configured key asks AMap first and converts '
        'GCJ-02 to WGS-84', () async {
      var nominatimCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isAmap(request)) {
            expect(request.url.path, '/v3/geocode/geo');
            expect(request.url.queryParameters['address'], '小径湾');
            expect(request.url.queryParameters['key'], 'test-key');
            // location is "lon,lat" in GCJ-02 (roughly 惠东 小径湾).
            return json({
              'status': '1',
              'count': '1',
              'geocodes': [
                {
                  'formatted_address': '广东省惠州市惠东县小径湾',
                  'province': '广东省',
                  'city': '惠州市',
                  'district': '惠东县',
                  'location': '114.719000,22.647000',
                },
              ],
            });
          }
          if (isNominatim(request)) nominatimCalls++;
          return json(<Object?>[]);
        }),
      );
      final places = await service.search('小径湾');
      expect(nominatimCalls, 0);
      expect(places, hasLength(1));
      final place = places.first;
      expect(place.name, '惠东县小径湾'); // province/city prefixes stripped
      expect(place.displayName, '广东省惠州市惠东县小径湾');
      // GCJ-02 → WGS-84 must shift the point, by a bounded amount (a few
      // hundred meters ≈ well under 0.01°).
      expect(place.lat, isNot(moreOrLessEquals(22.647, epsilon: 1e-9)));
      expect(place.lon, isNot(moreOrLessEquals(114.719, epsilon: 1e-9)));
      expect((place.lat - 22.647).abs(), lessThan(0.01));
      expect((place.lon - 114.719).abs(), lessThan(0.01));
    });

    test('AMap status != 1 (bad key / quota) continues the chain',
        () async {
      var nominatimCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isAmap(request)) return json({'status': '0', 'info': 'INVALID'});
          if (isNominatim(request)) {
            nominatimCalls++;
            return json([
              {
                'lat': '22.6',
                'lon': '114.7',
                'name': '小径湾',
                'display_name': '小径湾, China',
              },
            ]);
          }
          return json(<Object?>[]);
        }),
      );
      final places = await service.search('小径湾');
      expect(nominatimCalls, 1);
      expect(places, hasLength(1));
    });
  });

  group('GeocodingService Nominatim circuit breaker', () {
    test('an unreachable Nominatim is skipped after repeated failures',
        () async {
      // The real Android condition: the host does not refuse the connection,
      // it never answers. Paying that timeout on every keystroke makes the
      // search feel broken even though Open-Meteo is answering fine.
      var nominatimCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            nominatimCalls++;
            throw http.ClientException('connection timed out');
          }
          return json({
            'results': [
              {
                'name': 'Bern',
                'latitude': 46.948,
                'longitude': 7.4474,
                'country': 'Switzerland',
              },
            ],
          });
        }),
        minInterval: Duration.zero,
      );

      for (var i = 0; i < 5; i++) {
        final places = await service.search('Bern');
        expect(places, hasLength(1),
            reason: 'the fallback must keep answering throughout');
      }

      // Two failures open the breaker; the remaining searches skip Nominatim.
      expect(nominatimCalls, 2);
    });

    test('a recovered Nominatim is used again after the cooldown', () async {
      // Failures must not disable the better provider permanently — moving to
      // a network where it works has to recover.
      var failNominatim = true;
      var nominatimCalls = 0;
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            nominatimCalls++;
            if (failNominatim) {
              throw http.ClientException('connection timed out');
            }
            return json([
              {
                'lat': '46.9480',
                'lon': '7.4474',
                'name': 'Bern',
                'display_name': 'Bern, Switzerland',
              },
            ]);
          }
          return json({'generationtime_ms': 0.1});
        }),
        minInterval: Duration.zero,
        breakerCooldown: const Duration(milliseconds: 60),
      );

      await service.search('Bern');
      await service.search('Bern');
      expect(nominatimCalls, 2, reason: 'the breaker should now be open');

      await service.search('Bern');
      expect(nominatimCalls, 2, reason: 'still within the cooldown');

      failNominatim = false;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final places = await service.search('Bern');
      expect(nominatimCalls, 3, reason: 'the cooldown elapsed, so re-test');
      expect(places.single.name, 'Bern');
    });
  });

  group('GeocodingService Nominatim rate limiting', () {
    test('consecutive Nominatim requests are spaced by [minInterval]',
        () async {
      final stamps = <DateTime>[];
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) stamps.add(DateTime.now());
          if (isOpenMeteo(request)) return json({'generationtime_ms': 0});
          return json(<Object?>[]);
        }),
        minInterval: const Duration(milliseconds: 50),
      );
      await service.search('a');
      await service.search('b');
      expect(stamps, hasLength(2));
      final gap = stamps.last.difference(stamps.first).inMilliseconds;
      expect(gap, greaterThanOrEqualTo(45));
    });

    test('a concurrent burst is serialized and spaced, so no request can '
        'trip the 1 req/s policy', () async {
      final stamps = <DateTime>[];
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            stamps.add(DateTime.now());
            return json([
              {
                'lat': '1',
                'lon': '1',
                'name': 'hit',
                'display_name': 'hit',
              },
            ]);
          }
          return json(<Object?>[]);
        }),
        minInterval: const Duration(milliseconds: 40),
      );

      // Fire everything at once, the way a fast typist plus a submit would.
      await Future.wait(<Future<List<GeocodedPlace>>>[
        service.search('a'),
        service.search('b'),
        service.search('c'),
        service.search('d'),
      ]);

      expect(stamps, hasLength(4));
      for (var i = 1; i < stamps.length; i++) {
        final gap = stamps[i].difference(stamps[i - 1]).inMilliseconds;
        expect(gap, greaterThanOrEqualTo(35),
            reason: 'request $i followed the previous one too closely');
      }
    });
  });
}
