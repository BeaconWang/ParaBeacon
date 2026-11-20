import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/session_metrics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sends a startup payload with stable installation identity', () async {
    final requests = <http.Request>[];
    final service = SessionMetricsService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 202);
      }),
      heartbeatInterval: const Duration(hours: 1),
      appVersionLoader: () async => '1.2.3+45',
      accessTokenProvider: () => 'access-token',
    );

    await service.start(userIdProvider: () => 'user-7');

    expect(requests, hasLength(1));
    expect(requests.single.headers['authorization'], 'Bearer access-token');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/metrics/session');
    final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(payload['event_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(payload['session_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(payload['hardware_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(payload['app_version'], '1.2.3+45');
    expect(payload['user_id'], 'user-7');
    expect(payload['run_time_sec'], 0);
    expect(payload['total_runtime_sec'], 0);
    expect(payload['client_timestamp'], isA<String>());
    expect(payload['diagnostics'], isA<Map<String, dynamic>>());

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(SessionMetricsService.installationIdPreferenceKey),
      payload['hardware_id'],
    );
    service.close();
  });

  test(
    'queues failed updates and flushes them after connectivity returns',
    () async {
      var online = false;
      var requestCount = 0;
      final service = SessionMetricsService(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('', online ? 200 : 503);
        }),
        heartbeatInterval: const Duration(hours: 1),
        appVersionLoader: () async => '1.2.3+45',
      );

      await service.start();
      var preferences = await SharedPreferences.getInstance();
      var queued =
          jsonDecode(
                preferences.getString(
                  SessionMetricsService.pendingQueuePreferenceKey,
                )!,
              )
              as List<dynamic>;
      expect(queued, hasLength(1));

      online = true;
      await service.reportNow(reason: 'heartbeat');

      preferences = await SharedPreferences.getInstance();
      queued =
          jsonDecode(
                preferences.getString(
                  SessionMetricsService.pendingQueuePreferenceKey,
                )!,
              )
              as List<dynamic>;
      expect(queued, isEmpty);
      expect(requestCount, 3);
      service.close();
    },
  );
}
