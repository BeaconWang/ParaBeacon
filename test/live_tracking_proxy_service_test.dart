import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:parabeacon/data/live_tracking_proxy_auth_service.dart';
import 'package:parabeacon/data/live_tracking_proxy_service.dart';

void main() {
  setUp(() {
    FlightState.instance.stop();
  });

  tearDown(() {
    FlightState.instance.stop();
  });

  test('proxy config resolves the session and batch routes over HTTPS', () {
    final config = LiveTrackingProxyConfig(
      apiBaseUri: Uri.https('api.myparabeacon-proxy.com', ''),
    );

    expect(
      config.sessionStartUri,
      Uri.https('api.myparabeacon-proxy.com', '/v1/flight/start'),
    );
    expect(
      config.pointsUri('flight-123'),
      Uri.https('api.myparabeacon-proxy.com', '/v1/flight/flight-123/points'),
    );
  });

  test('proxy config rejects insecure and internal origins', () {
    expect(
      () => LiveTrackingProxyConfig(apiBaseUri: Uri.http('proxy.example', '')),
      throwsArgumentError,
    );
    expect(
      () => LiveTrackingProxyConfig(apiBaseUri: Uri.https('10.1.2.3', '')),
      throwsArgumentError,
    );
  });

  test('maps a real GPS fix to proxy units and wire fields', () {
    final point = ProxyLiveTrackpoint.fromFlightData(
      FlightData(
        hasFix: true,
        latitude: 47.123,
        longitude: 8.456,
        gpsAltitude: 1234.5,
        groundSpeed: 36,
        gpsTimestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
    );

    expect(point, isNotNull);
    expect(point!.altitudeMeters, 1234.5);
    expect(point.speedMetersPerSecond, 10);
    expect(point.toJson(), {
      'lat': 47.123,
      'lon': 8.456,
      'altitude': 1234.5,
      'speed': 10.0,
      'timestamp': '2026-01-02T03:04:05.000Z',
    });
    expect(
      ProxyLiveTrackpoint.fromFlightData(
        const FlightData(hasFix: true, isMockLocation: true),
      ),
      isNull,
    );
  });

  test(
    'starts a session on active flight and uploads authenticated batches',
    () async {
      final startTime = DateTime.utc(2026, 3, 4, 5, 6, 7);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer proxy-test-token');
        if (request.url.path == '/v1/flight/start') {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'pilot_id': 'pilot-42',
            'start_time': startTime.toIso8601String(),
          });
          return http.Response(
            jsonEncode({
              'session_id': 'session-123',
              'socket_url':
                  'wss://api.myparabeacon-proxy.com/v1/live/session-123',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, '/v1/flight/session-123/points');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['session_id'], 'session-123');
        final points = body['trackpoints'] as List<dynamic>;
        expect(points, hasLength(1));
        expect(points.single, {
          'lat': 47.1,
          'lon': 8.5,
          'altitude': 1200,
          'speed': 5.0,
          'timestamp': '2026-03-04T05:06:09.000Z',
        });
        return http.Response('', 204);
      });

      final data = _MutableFlightDataView(
        FlightData(
          hasFix: true,
          latitude: 47.1,
          longitude: 8.5,
          gpsAltitude: 1200,
          groundSpeed: 18,
          gpsTimestamp: startTime.add(const Duration(seconds: 2)),
        ),
      );
      final service = LiveTrackingService(
        config: LiveTrackingProxyConfig(
          apiBaseUri: Uri.https('api.myparabeacon-proxy.com', ''),
        ),
        authProvider: _TestProxyAuthProvider(),
        pointStore: _MemoryProxyPointStore(),
        httpClient: client,
      );
      service.bind(
        data: data,
        flightState: FlightState.instance,
        isEnabled: () => true,
        pilotId: () => 'pilot-42',
      );

      FlightState.instance.start(at: startTime);
      await pumpEventQueue(times: 20);

      expect(service.state, LiveTrackingProxyState.active);
      expect(service.sessionId, 'session-123');
      expect(service.pendingPointCount, 0);
      expect(requests.map((request) => request.url.path), [
        '/v1/flight/start',
        '/v1/flight/session-123/points',
      ]);

      FlightState.instance.stop();
      await pumpEventQueue(times: 10);
      expect(service.state, LiveTrackingProxyState.idle);
      await service.shutdown();
      client.close();
      data.dispose();
    },
  );
}

class _TestProxyAuthProvider implements LiveTrackingProxyAuthProvider {
  @override
  Future<Map<String, String>> authorizationHeaders() async => {
    'Authorization': 'Bearer proxy-test-token',
  };
}

class _MemoryProxyPointStore implements LiveTrackingProxyPointStore {
  List<QueuedProxyPoint> stored = [];

  @override
  Future<List<QueuedProxyPoint>> load() async => List.of(stored);

  @override
  Future<void> save(List<QueuedProxyPoint> points) async {
    stored = List.of(points);
  }
}

class _MutableFlightDataView extends ChangeNotifier implements FlightDataView {
  _MutableFlightDataView(this._data);

  FlightData _data;

  @override
  FlightData get data => _data;

  void update(FlightData data) {
    _data = data;
    notifyListeners();
  }
}
