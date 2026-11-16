import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/flight_log_sync_service.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const syncId = '7b8752b8-b790-4c49-960f-5d98d44b73ea';
  final track = FlightTrack(startTime: DateTime.utc(2026, 1, 1))
    ..endTime = DateTime.utc(2026, 1, 1, 1);

  test('uploads bounded batches and commits the complete snapshot', () async {
    final requests = <http.Request>[];
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'POST' && request.url.path.endsWith('/syncs')) {
          expect(jsonDecode(request.body), {'expected_count': 1});
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/batches/0')) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['flights'], [track.toJson()]);
          return http.Response(
            jsonEncode({'accepted': 1, 'batch_index': 0}),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/flight-logs/syncs/$syncId/commit');
        return http.Response(jsonEncode({'synced': 1}), 200);
      }),
      authorizationHeaders: () async => {'Authorization': 'Bearer test-token'},
      endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
    );

    final result = await service.syncTracks([track]);

    expect(result.synced, 1);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/flight-logs/syncs',
      '/api/v1/flight-logs/syncs/$syncId/batches/0',
      '/api/v1/flight-logs/syncs/$syncId/commit',
    ]);
  });

  test('splits large records into individually bounded requests', () async {
    final metadataChunk = List<String>.filled(5 * 1024, 'x').join();
    final largeMetadata = List<String>.filled(1024, metadataChunk).join();
    final tracks = [
      FlightTrack(startTime: DateTime.utc(2026, 1, 1))
        ..endTime = DateTime.utc(2026, 1, 1, 1)
        ..pilotName = largeMetadata,
      FlightTrack(startTime: DateTime.utc(2026, 1, 2))
        ..endTime = DateTime.utc(2026, 1, 2, 1)
        ..pilotName = largeMetadata,
    ];
    var batchCount = 0;
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/syncs') && request.method == 'POST') {
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        if (request.url.path.endsWith('/commit')) {
          return http.Response(jsonEncode({'synced': 2}), 200);
        }
        expect(request.method, 'PUT');
        expect(utf8.encode(request.body).length, lessThan(19 * 1024 * 1024));
        final pathIndex = int.parse(request.url.path.split('/').last);
        expect(pathIndex, batchCount);
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect((payload['flights'] as List), hasLength(1));
        batchCount++;
        return http.Response(
          jsonEncode({'accepted': 1, 'batch_index': pathIndex}),
          200,
        );
      }),
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer test-token',
      },
      endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
    );

    final result = await service.syncTracks(tracks);

    expect(result.synced, 2);
    expect(batchCount, 2);
  });

  test('caps each batch at the server record limit', () async {
    final tracks = [
      for (var index = 0; index < 51; index++)
        FlightTrack(
          startTime: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        )..endTime = DateTime.utc(2026, 1, 1, 1).add(Duration(minutes: index)),
    ];
    final batchLengths = <int>[];
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/syncs') && request.method == 'POST') {
          expect(jsonDecode(request.body), {'expected_count': 51});
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        if (request.url.path.endsWith('/commit')) {
          return http.Response(jsonEncode({'synced': 51}), 200);
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final count = (payload['flights'] as List).length;
        final index = int.parse(request.url.path.split('/').last);
        expect(index, batchLengths.length);
        batchLengths.add(count);
        return http.Response(
          jsonEncode({'accepted': count, 'batch_index': index}),
          200,
        );
      }),
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer test-token',
      },
      endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
    );

    final result = await service.syncTracks(tracks);

    expect(result.synced, 51);
    expect(batchLengths, [50, 1]);
  });

  test('sends and commits an explicit empty snapshot', () async {
    final requests = <http.Request>[];
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/syncs')) {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'expected_count': 0});
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/flight-logs/syncs/$syncId/commit');
        return http.Response(jsonEncode({'synced': 0}), 200);
      }),
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer test-token',
      },
      endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
    );

    final result = await service.syncTracks(const []);

    expect(result.synced, 0);
    expect(requests, hasLength(2));
  });
}
