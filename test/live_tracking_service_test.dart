import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:parabeacon/data/live_tracking_config.dart';
import 'package:parabeacon/data/live_tracking_proxy_auth_service.dart';
import 'package:parabeacon/data/live_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlightState.instance.stop();
  });

  tearDown(() {
    FlightState.instance.stop();
  });

  test('loads endpoints and settings from the bundled JSON asset', () async {
    final config = await LiveTrackingConfigLoader().load();

    expect(config.apiBaseUri, Uri.https('api.myparabeacon-proxy.com', ''));
    expect(
      config.sessionStartUri,
      Uri.https('api.myparabeacon-proxy.com', '/v1/flight/start'),
    );
    expect(
      config.sessionStopUri('flight-123'),
      Uri.https('api.myparabeacon-proxy.com', '/v1/flight/flight-123/stop'),
    );
    expect(
      config.pointsUri('flight-123'),
      Uri.https('api.myparabeacon-proxy.com', '/v1/flight/flight-123/points'),
    );
    expect(config.authEndpointUri, isNull);
    expect(config.webSocketUri, isNull);
    expect(config.channelIds, isEmpty);
  });

  test('parses optional auth, WebSocket, and channel configuration', () {
    final config = LiveTrackingConfig.fromJson(
      _configJson(
        authEndpoint: '/v1/auth/token',
        webSocketUrl: 'wss://api.myparabeacon-proxy.com/v1/live',
        channelIds: ['thermal', 7],
      ),
    );

    expect(
      config.authEndpointUri,
      Uri.https('api.myparabeacon-proxy.com', '/v1/auth/token'),
    );
    expect(
      config.webSocketUri,
      Uri.parse('wss://api.myparabeacon-proxy.com/v1/live'),
    );
    expect(config.channelIds, ['thermal', '7']);
  });

  test('rejects insecure origins and cross-origin auth/socket endpoints', () {
    expect(
      () => LiveTrackingConfig.fromJson(
        _configJson(apiBaseUrl: 'http://proxy.example'),
      ),
      throwsFormatException,
    );
    expect(
      () => LiveTrackingConfig.fromJson(
        _configJson(apiBaseUrl: 'https://10.1.2.3'),
      ),
      throwsFormatException,
    );
    expect(
      () => LiveTrackingConfig.fromJson(
        _configJson(authEndpoint: 'https://other.example/auth'),
      ),
      throwsFormatException,
    );
    expect(
      () => LiveTrackingConfig.fromJson(
        _configJson(webSocketUrl: 'ws://api.myparabeacon-proxy.com/live'),
      ),
      throwsFormatException,
    );
  });

  test('maps a real GPS fix to proxy units and wire fields', () {
    final point = LiveTrackpoint.fromFlightData(
      FlightData(
        hasFix: true,
        latitude: 47.123,
        longitude: 8.456,
        gpsAltitude: 1234.5,
        groundSpeed: 36,
        heading: 193.5,
        hasHeading: true,
        gpsTimestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
    );

    expect(point, isNotNull);
    expect(point!.altitudeMeters, 1234.5);
    expect(point.groundSpeedMetersPerSecond, 10);
    expect(point.bearingDegrees, 193.5);
    expect(point.toJson(), {
      'lat': 47.123,
      'lon': 8.456,
      'altitude': 1234.5,
      'speed': 10.0,
      'timestamp': '2026-01-02T03:04:05.000Z',
      'bearing': 193.5,
    });
    final restoredPoint = LiveTrackpoint.fromJson(point.toJson());
    expect(restoredPoint?.groundSpeedMetersPerSecond, 10);
    expect(restoredPoint?.bearingDegrees, 193.5);
    expect(
      LiveTrackpoint.fromFlightData(
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
            'channel_ids': ['live-main'],
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
        if (request.url.path == '/v1/flight/session-123/stop') {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session_id'], 'session-123');
          expect(DateTime.tryParse(body['end_time'] as String), isNotNull);
          return http.Response('', 204);
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
          'bearing': 123.4,
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
          heading: 123.4,
          hasHeading: true,
          gpsTimestamp: startTime.add(const Duration(seconds: 2)),
        ),
      );
      final service = LiveTrackingService(
        config: _config(channelIds: ['live-main']),
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

      expect(service.state, LiveTrackingConnectionState.active);
      expect(service.sessionId, 'session-123');
      expect(service.pendingPointCount, 0);
      expect(requests.map((request) => request.url.path), [
        '/v1/flight/start',
        '/v1/flight/session-123/points',
      ]);

      FlightState.instance.stop();
      await pumpEventQueue(times: 10);
      expect(service.state, LiveTrackingConnectionState.disconnected);
      expect(requests.last.url.path, '/v1/flight/session-123/stop');
      await service.shutdown();
      client.close();
      data.dispose();
    },
  );

  test('uses reconnecting backoff after transient session failures', () async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      return http.Response('unavailable', 503);
    });
    final data = _MutableFlightDataView(FlightData.empty);
    final service = LiveTrackingService(
      config: _config(),
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

    FlightState.instance.start(at: DateTime.utc(2026, 3, 4));
    await pumpEventQueue(times: 20);

    expect(attempts, greaterThanOrEqualTo(1));
    expect(service.state, LiveTrackingConnectionState.reconnecting);
    expect(service.lastErrorCode, 'session_http_503');

    FlightState.instance.stop();
    await pumpEventQueue(times: 10);
    expect(service.state, LiveTrackingConnectionState.disconnected);
    await service.shutdown();
    client.close();
    data.dispose();
  });
}

Map<String, Object?> _configJson({
  String apiBaseUrl = 'https://api.myparabeacon-proxy.com',
  String? authEndpoint,
  String? webSocketUrl,
  List<Object> channelIds = const [],
}) => {
  'api_base_url': apiBaseUrl,
  'session_start_endpoint': '/v1/flight/start',
  'session_stop_endpoint': '/v1/flight/{session_id}/stop',
  'points_endpoint': '/v1/flight/{session_id}/points',
  'auth_endpoint': authEndpoint,
  'websocket_url': webSocketUrl,
  'channel_ids': channelIds,
  'request_timeout_seconds': 15,
  'upload_interval_seconds': 5,
  'maximum_batch_points': 50,
  'maximum_buffered_points': 5000,
};

LiveTrackingConfig _config({List<Object> channelIds = const []}) =>
    LiveTrackingConfig.fromJson(_configJson(channelIds: channelIds));

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
