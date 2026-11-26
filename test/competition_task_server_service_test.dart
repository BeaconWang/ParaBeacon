import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/competition_task_server_service.dart';

void main() {
  final task = CompetitionTask(
    name: 'Valley route',
    turnpoints: const [
      Turnpoint(
        waypoint: TaskWaypoint(name: 'Start', latitude: 47.1, longitude: 8.5),
        radiusMeters: 400,
      ),
    ],
  );

  test(
    'uploads with account authorization and reads all server tasks',
    () async {
      final requests = <http.Request>[];
      final timestamp = DateTime.utc(2026, 11, 26, 12);
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          expect(request.headers['Authorization'], 'Bearer account-token');
          expect(request.url.path, '/api/v1/user/competition-task');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['task'], task.toXctsk());
          return http.Response(
            jsonEncode({'updated_at': timestamp.toIso8601String()}),
            200,
          );
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/competition-tasks');
        expect(request.headers['Authorization'], 'Bearer account-token');
        return http.Response(
          jsonEncode({
            'tasks': [
              {
                'task': task.toXctsk(),
                'updated_at': timestamp.toIso8601String(),
                'owner_id': '11111111-1111-4111-8111-111111111111',
                'username': 'pilot-one',
                'display_name': 'Pilot One',
              },
              {
                'task': task.copyWith(name: 'Mountain route').toXctsk(),
                'updated_at': timestamp.toIso8601String(),
                'owner_id': '22222222-2222-4222-8222-222222222222',
                'username': 'pilot-two',
                'display_name': '',
              },
            ],
          }),
          200,
        );
      });
      final service = CompetitionTaskServerService(
        client: client,
        authorizationHeaders: () async => {
          'Authorization': 'Bearer account-token',
        },
        listEndpoint: Uri.https('test.example', '/api/v1/competition-tasks'),
        uploadEndpoint: Uri.https(
          'test.example',
          '/api/v1/user/competition-task',
        ),
      );

      await service.uploadTask(task);
      final entries = await service.listTasks();

      expect(requests.map((request) => request.method), ['PUT', 'GET']);
      expect(entries.map((entry) => entry.task.name), [
        'Valley route',
        'Mountain route',
      ]);
      expect(entries.map((entry) => entry.username), [
        'pilot-one',
        'pilot-two',
      ]);
      expect(entries.map((entry) => entry.displayName), ['Pilot One', '']);
      expect(entries.map((entry) => entry.ownerId), [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ]);
    },
  );

  test('rejects malformed task-list responses and empty uploads', () async {
    final service = CompetitionTaskServerService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tasks': [{}],
          }),
          200,
        ),
      ),
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer account-token',
      },
      listEndpoint: Uri.https('test.example', '/api/v1/competition-tasks'),
      uploadEndpoint: Uri.https(
        'test.example',
        '/api/v1/user/competition-task',
      ),
    );

    await expectLater(service.listTasks(), throwsFormatException);
    await expectLater(
      service.uploadTask(const CompetitionTask()),
      throwsFormatException,
    );
  });
}
