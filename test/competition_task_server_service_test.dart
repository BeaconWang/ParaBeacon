import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/competition_task_server_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final selectedOwners = <Object?>[];
      final timestamp = DateTime.utc(2026, 11, 26, 12);
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/user/competition-task') {
          expect(request.headers['Authorization'], 'Bearer account-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['task'], task.toXctsk());
          return http.Response(
            jsonEncode({'updated_at': timestamp.toIso8601String()}),
            200,
          );
        }
        if (request.method == 'PUT') {
          expect(request.headers['Authorization'], 'Bearer account-token');
          expect(request.url.path, '/api/v1/user/current-competition-task');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          selectedOwners.add(body['task_owner_id']);
          return http.Response(
            jsonEncode({'current_task_owner_id': body['task_owner_id']}),
            200,
          );
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/competition-tasks');
        expect(request.headers['Authorization'], 'Bearer account-token');
        return http.Response(
          jsonEncode({
            'current_task_owner_id': '11111111-1111-4111-8111-111111111111',
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
        selectionEndpoint: Uri.https(
          'test.example',
          '/api/v1/user/current-competition-task',
        ),
      );

      await service.uploadTask(task);
      final taskList = await service.listTasksWithSelection();
      await service.setCurrentTask('22222222-2222-4222-8222-222222222222');
      await service.setCurrentTask(null);
      final entries = taskList.tasks;

      expect(requests.map((request) => request.method), [
        'PUT',
        'GET',
        'PUT',
        'PUT',
      ]);
      expect(selectedOwners, ['22222222-2222-4222-8222-222222222222', null]);
      expect(
        taskList.currentTaskOwnerId,
        '11111111-1111-4111-8111-111111111111',
      );
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

  test('deletes the authenticated account task', () async {
    final client = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/v1/user/competition-task');
      expect(request.headers['Authorization'], 'Bearer account-token');
      expect(request.body, isEmpty);
      return http.Response('', 204);
    });
    final service = CompetitionTaskServerService(
      client: client,
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer account-token',
      },
      uploadEndpoint: Uri.https(
        'test.example',
        '/api/v1/user/competition-task',
      ),
    );

    await service.deleteOwnTask();
  });

  test('refreshes the authenticated account current task pin', () async {
    String? ownerId;
    final service = CompetitionTaskServerService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/user/current-competition-task');
        return http.Response(
          jsonEncode({'current_task_owner_id': ownerId}),
          200,
        );
      }),
      authorizationHeaders: () async => const {
        'Authorization': 'Bearer account-token',
      },
      selectionEndpoint: Uri.https(
        'test.example',
        '/api/v1/user/current-competition-task',
      ),
    );

    expect(await service.refreshCurrentTaskOwner(), isNull);
    expect(CompetitionTaskServerService.currentTaskOwnerId.value, isNull);

    ownerId = '11111111-1111-4111-8111-111111111111';
    expect(await service.refreshCurrentTaskOwner(), ownerId);
    expect(CompetitionTaskServerService.currentTaskOwnerId.value, ownerId);
  });

  test('suppresses auto-sync of a task deleted from the server', () async {
    SharedPreferences.setMockInitialValues({});
    const accountId = '11111111-1111-4111-8111-111111111111';
    final service = CompetitionTaskServerService(
      authorizationHeaders: () async => const {},
    );

    await service.suppressAutoSyncForTask(accountId, task);
    expect(await service.isAutoSyncSuppressed(accountId, task), isTrue);

    final editedTask = task.copyWith(name: 'Edited local task');
    expect(await service.isAutoSyncSuppressed(accountId, editedTask), isFalse);
    expect(await service.isAutoSyncSuppressed(accountId, task), isFalse);
    await service.clearAutoSyncSuppression(accountId);
  });

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
    await expectLater(
      service.setCurrentTask('not-a-uuid'),
      throwsFormatException,
    );
  });
}
