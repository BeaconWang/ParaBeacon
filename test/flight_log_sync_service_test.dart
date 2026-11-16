import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/flight_log_sync_service.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final track = FlightTrack(startTime: DateTime.utc(2026, 1, 1))
    ..endTime = DateTime.utc(2026, 1, 1, 1);

  test(
    'replaces the server library with the complete local snapshot',
    () async {
      final requests = <http.Request>[];
      final service = FlightLogSyncService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/v1/flight-logs/sync');
          expect(request.headers['Authorization'], 'Bearer test-token');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['flights'], [track.toJson()]);
          return http.Response(jsonEncode({'synced': 1}), 200);
        }),
        authorizationHeaders: () async => {
          'Authorization': 'Bearer test-token',
        },
        endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
      );

      final result = await service.syncTracks([track]);

      expect(result.synced, 1);
      expect(requests, hasLength(1));
    },
  );

  test(
    'sends an explicit empty snapshot so the server clears its records',
    () async {
      final requests = <http.Request>[];
      final service = FlightLogSyncService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'PUT');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['flights'], isEmpty);
          return http.Response(jsonEncode({'synced': 0}), 200);
        }),
        authorizationHeaders: () async => const {
          'Authorization': 'Bearer test-token',
        },
        endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
      );

      final result = await service.syncTracks(const []);

      expect(result.synced, 0);
      expect(requests, hasLength(1));
    },
  );
}
