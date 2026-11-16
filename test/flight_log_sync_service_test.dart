import 'dart:convert';

import 'package:archive/archive.dart';
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

  test(
    'uploads a maximally compressed flight ZIP and commits the snapshot',
    () async {
      final requests = <http.Request>[];
      final service = FlightLogSyncService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer test-token');
          if (request.method == 'POST' && request.url.path.endsWith('/syncs')) {
            expect(jsonDecode(request.body), {'expected_count': 1});
            return http.Response(jsonEncode({'sync_id': syncId}), 201);
          }
          if (request.method == 'PUT') {
            expect(
              request.url.path,
              '/api/v1/flight-logs/syncs/$syncId/flights/0',
            );
            expect(request.headers['Content-Type'], 'application/zip');
            final archive = ZipDecoder().decodeBytes(request.bodyBytes);
            expect(archive.files, hasLength(1));
            expect(archive.files.single.name, 'flight.json');
            expect(
              jsonDecode(
                utf8.decode(archive.files.single.content as List<int>),
              ),
              track.toJson(),
            );
            return http.Response(
              jsonEncode({
                'accepted': true,
                'flight_index': 0,
                'archive_id': '00000000-0000-4000-8000-000000000001',
              }),
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/flight-logs/syncs/$syncId/commit');
          return http.Response(jsonEncode({'synced': 1}), 200);
        }),
        authorizationHeaders: () async => {
          'Authorization': 'Bearer test-token',
        },
        endpoint: Uri.https('test.example', '/api/v1/flight-logs'),
      );

      final result = await service.syncTracks([track]);

      expect(result.synced, 1);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/flight-logs/syncs',
        '/api/v1/flight-logs/syncs/$syncId/flights/0',
        '/api/v1/flight-logs/syncs/$syncId/commit',
      ]);
    },
  );

  test('uploads each large flight as its own bounded ZIP package', () async {
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
    var archiveCount = 0;
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/syncs') && request.method == 'POST') {
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        if (request.url.path.endsWith('/commit')) {
          return http.Response(jsonEncode({'synced': 2}), 200);
        }
        expect(request.method, 'PUT');
        expect(request.headers['Content-Type'], 'application/zip');
        expect(request.bodyBytes.length, lessThan(24 * 1024 * 1024));
        final pathIndex = int.parse(request.url.path.split('/').last);
        expect(pathIndex, archiveCount);
        final archive = ZipDecoder().decodeBytes(request.bodyBytes);
        expect(archive.files.single.name, 'flight.json');
        archiveCount++;
        return http.Response(
          jsonEncode({
            'accepted': true,
            'flight_index': pathIndex,
            'archive_id':
                '00000000-0000-4000-8000-${archiveCount.toString().padLeft(12, '0')}',
          }),
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
    expect(archiveCount, 2);
  });

  test('uploads one compressed archive for each flight record', () async {
    final tracks = [
      for (var index = 0; index < 51; index++)
        FlightTrack(
          startTime: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        )..endTime = DateTime.utc(2026, 1, 1, 1).add(Duration(minutes: index)),
    ];
    var archiveCount = 0;
    final service = FlightLogSyncService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/syncs') && request.method == 'POST') {
          expect(jsonDecode(request.body), {'expected_count': 51});
          return http.Response(jsonEncode({'sync_id': syncId}), 201);
        }
        if (request.url.path.endsWith('/commit')) {
          return http.Response(jsonEncode({'synced': 51}), 200);
        }
        expect(request.method, 'PUT');
        final index = int.parse(request.url.path.split('/').last);
        expect(index, archiveCount);
        expect(request.url.path, endsWith('/flights/$index'));
        expect(request.headers['Content-Type'], 'application/zip');
        final archive = ZipDecoder().decodeBytes(request.bodyBytes);
        expect(archive.files, hasLength(1));
        expect(archive.files.single.name, 'flight.json');
        archiveCount++;
        return http.Response(
          jsonEncode({
            'accepted': true,
            'flight_index': index,
            'archive_id':
                '00000000-0000-4000-8000-${archiveCount.toString().padLeft(12, '0')}',
          }),
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
    expect(archiveCount, 51);
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
