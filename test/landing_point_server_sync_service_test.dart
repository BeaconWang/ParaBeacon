import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/landing_point_server_sync_service.dart';
import 'package:parabeacon/data/landing_point_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final point = LandingPoint(
    id: 'client-point-1',
    name: 'Main LZ',
    latitude: 47.1,
    longitude: 8.5,
    altitudeM: 1200,
    createdAt: DateTime(2026, 10, 22),
    notes: 'Road access',
  );

  test('exports and imports authenticated server records', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer account-token');
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['default_id'], point.id);
        expect(body['points'], [point.toJson()]);
        expect((body['points'] as List).single['createdAt'], endsWith('Z'));
        return http.Response(jsonEncode({'synced': 1}), 200);
      }
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'points': [point.toJson()],
          'default_id': point.id,
        }),
        200,
      );
    });
    final service = LandingPointServerSyncService(
      client: client,
      authorizationHeaders: () async => {
        'Authorization': 'Bearer account-token',
      },
      endpoint: Uri.https('test.example', '/api/v1/landing-points'),
    );

    expect(await service.exportPoints([point], defaultId: point.id), 1);
    final imported = await service.importPoints();

    expect(requests.map((request) => request.method), ['POST', 'GET']);
    expect(imported.points.single.toJson(), point.toJson());
    expect(imported.defaultId, point.id);
  });

  test(
    'rejects malformed server points and broken default references',
    () async {
      final service = LandingPointServerSyncService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'points': [point.toJson()],
              'default_id': 'missing-point',
            }),
            200,
          ),
        ),
        authorizationHeaders: () async => const {
          'Authorization': 'Bearer account-token',
        },
        endpoint: Uri.https('test.example', '/api/v1/landing-points'),
      );

      await expectLater(service.importPoints(), throwsFormatException);
      await expectLater(
        service.exportPoints([point], defaultId: 'missing-point'),
        throwsFormatException,
      );
    },
  );
}
