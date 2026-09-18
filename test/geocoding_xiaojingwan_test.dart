import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/geocoding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guard for the reported bug: searching 小径湾 / xiaojingwan
/// returned nothing on Android while working on Windows.
///
/// Both spellings exist in OpenStreetMap (a motorway junction near 惠州大亚湾),
/// so the data was never the problem. The requests were being rate-limited:
/// Nominatim allows 1 req/s per IP, and a phone shares its carrier's NAT exit
/// IP with many other users, so it answers 429/403 far more often than a
/// desktop on a home connection does. These tests pin the two behaviours that
/// make the search survive that.
void main() {
  bool isNominatim(http.Request r) =>
      r.url.host == 'nominatim.openstreetmap.org';
  bool isOpenMeteo(http.Request r) =>
      r.url.host == 'geocoding-api.open-meteo.com';

  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
        // Serve raw UTF-8 bytes with no charset in the content type, the way
        // these providers actually do — the decoder must not assume latin-1.
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// The OSM node that both spellings resolve to, in Nominatim's shape.
  List<Map<String, Object>> osmXiaojingwan(String name, String display) => [
        {
          'place_id': 237545582,
          'osm_type': 'node',
          'lat': '22.8077537',
          'lon': '114.6746473',
          'name': name,
          'display_name': display,
        },
      ];

  group('小径湾 / xiaojingwan', () {
    test('both spellings resolve when Nominatim answers', () async {
      final asked = <String>[];
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            final q = request.url.queryParameters['q']!;
            asked.add(q);
            return json(
              q == '小径湾'
                  ? osmXiaojingwan('小径湾', '小径湾, 惠阳区, 惠州市, 广东省, 中国')
                  : osmXiaojingwan(
                      'Xiaojingwan',
                      'Xiaojingwan, Huiyang District, Huizhou, Guangdong, China',
                    ),
            );
          }
          return json(<Object?>[]);
        }),
        minInterval: Duration.zero,
      );

      final cjk = await service.search('小径湾', language: 'zh');
      expect(cjk, hasLength(1));
      expect(cjk.first.name, '小径湾');
      expect(cjk.first.lat, closeTo(22.8077537, 1e-7));
      expect(cjk.first.lon, closeTo(114.6746473, 1e-7));

      final latin = await service.search('xiaojingwan');
      expect(latin, hasLength(1));
      expect(latin.first.name, 'Xiaojingwan');

      expect(asked, ['小径湾', 'xiaojingwan']);
    });

    test('a rate-limited phone still gets an answer via Open-Meteo', () async {
      // Exactly the Android failure: the shared carrier IP is over budget.
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) return http.Response('Too Many', 429);
          expect(isOpenMeteo(request), isTrue);
          expect(request.url.queryParameters['name'], '小径湾');
          return json({
            'results': [
              {
                'name': '小径湾',
                'latitude': 22.80775,
                'longitude': 114.67465,
                'admin1': '广东省',
                'country': '中国',
              },
            ],
          });
        }),
        minInterval: Duration.zero,
      );

      final places = await service.search('小径湾', language: 'zh');
      expect(places, hasLength(1));
      expect(places.first.name, '小径湾');
      expect(places.first.displayName, '小径湾, 广东省, 中国');
    });

    test('Chinese names survive a response with no charset declared',
        () async {
      // Decoding `resp.body` instead of `bodyBytes` turns 小径湾 into mojibake,
      // which silently produced unusable dropdown entries.
      final service = GeocodingService.withClient(
        MockClient((request) async {
          if (isNominatim(request)) {
            return json(osmXiaojingwan('小径湾', '小径湾, 广东省, 中国'));
          }
          return json(<Object?>[]);
        }),
        minInterval: Duration.zero,
      );

      final places = await service.search('小径湾', language: 'zh');
      expect(places.first.name, '小径湾');
      expect(places.first.displayName, contains('广东省'));
    });
  });
}
