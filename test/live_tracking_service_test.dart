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
import 'package:parabeacon/data/live_tracking_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlightState.instance.stop();
  });

  tearDown(() {
    FlightState.instance.stop();
  });

  test('tracking destinations default off and persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = LiveTrackingSettings.instance;

    await settings.load();
    expect(settings.shareLocationPublicly, isFalse);
    expect(settings.shareLocationWhileNotFlying, isTrue);
    expect(settings.xcontestEnabled, isFalse);
    expect(settings.parabeaconEnabled, isFalse);
    expect(settings.hasExplicitDestinationSelection, isFalse);

    await settings.setXContestEnabled(true);
    expect(settings.xcontestEnabled, isTrue);
    expect(settings.parabeaconEnabled, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('Livetrack.XContestEnabled'), isTrue);
    expect(preferences.getBool('Livetrack.ParaBeaconEnabled'), isFalse);
    expect(preferences.getBool('Livetrack.DestinationSelectionMade'), isTrue);
    await settings.setParaBeaconEnabled(true);
    await settings.setXContestEnabled(false);
    expect(settings.xcontestEnabled, isFalse);
    expect(settings.parabeaconEnabled, isTrue);
    expect(preferences.getBool('Livetrack.XContestEnabled'), isFalse);
    expect(preferences.getBool('Livetrack.ParaBeaconEnabled'), isTrue);

    await settings.setShareLocationPublicly(true);
    expect(preferences.getBool('ParaBeacon.ShareLocationPublicly'), isTrue);
    expect(
      preferences.getBool('ParaBeacon.ShareLocationWhileNotFlying'),
      isNull,
    );
    await settings.setShareLocationWhileNotFlying(false);
    expect(
      preferences.getBool('ParaBeacon.ShareLocationWhileNotFlying'),
      isFalse,
    );
    await settings.setShareLocationPublicly(false);
  });

  test('loads endpoints and settings from the bundled JSON asset', () async {
    final config = await LiveTrackingConfigLoader().load();

    expect(config.apiBaseUri, Uri.https('www.parabeacon.icu', ''));
    expect(
      config.sessionStartUri,
      Uri.https('www.parabeacon.icu', '/api/v1/tracking/sessions'),
    );
    expect(
      config.sessionStopUri('flight-123'),
      Uri.https(
        'www.parabeacon.icu',
        '/api/v1/tracking/sessions/flight-123/stop',
      ),
    );
    expect(
      config.pointsUri('flight-123'),
      Uri.https(
        'www.parabeacon.icu',
        '/api/v1/tracking/sessions/flight-123/points',
      ),
    );
    expect(config.authEndpointUri, isNull);
    expect(
      config.webSocketUri,
      Uri(
        scheme: 'wss',
        host: 'www.parabeacon.icu',
        path: '/api/v1/tracking/live',
      ),
    );
    expect(config.channelIds, isEmpty);
  });

  test('builds all live endpoints from a custom HTTPS origin', () async {
    final config = await LiveTrackingConfigLoader(
      apiBaseUri: Uri.parse('https://tracking.example.org:9443'),
    ).load();

    expect(config.sessionStartUri.host, 'tracking.example.org');
    expect(config.sessionStartUri.port, 9443);
    expect(config.sessionStopUri('flight-123').host, 'tracking.example.org');
    expect(config.pointsUri('flight-123').port, 9443);
    expect(config.webSocketUri?.scheme, 'wss');
    expect(config.webSocketUri?.host, 'tracking.example.org');
    expect(config.webSocketUri?.port, 9443);
  });

  test('parses optional auth, WebSocket, and channel configuration', () {
    final config = LiveTrackingConfig.fromJson(
      _configJson(
        authEndpoint: '/v1/auth/token',
        webSocketUrl: 'wss://www.parabeacon.icu/v1/live',
        channelIds: ['thermal', 7],
      ),
    );

    expect(
      config.authEndpointUri,
      Uri.https('www.parabeacon.icu', '/v1/auth/token'),
    );
    expect(config.webSocketUri, Uri.parse('wss://www.parabeacon.icu/v1/live'));
    expect(config.channelIds, ['thermal', '7']);
  });

  test('accepts an IP server address and builds endpoints on that origin', () {
    final baseUri = Uri.parse('https://8.8.4.4:8443');
    final config = LiveTrackingConfig.fromJson(
      _configJson(),
      apiBaseUri: baseUri,
    );

    expect(config.apiBaseUri, baseUri);
    expect(
      config.sessionStartUri,
      Uri.parse('https://8.8.4.4:8443/api/v1/tracking/sessions'),
    );
  });

  test('accepts HTTP server origins and resolves HTTP WebSockets', () {
    final baseUri = Uri.parse('http://8.8.4.4:8080');
    final config = LiveTrackingConfig.fromJson(
      _configJson(webSocketUrl: '/live'),
      apiBaseUri: baseUri,
    );

    expect(
      config.sessionStartUri,
      Uri.parse('$baseUri/api/v1/tracking/sessions'),
    );
    expect(config.webSocketUri, Uri.parse('ws://8.8.4.4:8080/live'));
  });

  test(
    'rejects unsupported origins and cross-origin auth/socket endpoints',
    () {
      expect(
        () => LiveTrackingConfig.fromJson(
          _configJson(),
          apiBaseUri: Uri.parse('ftp://proxy.example'),
        ),
        throwsFormatException,
      );
      expect(
        () => LiveTrackingConfig.fromJson(
          _configJson(),
          apiBaseUri: Uri.parse('https://10.1.2.3'),
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
          _configJson(webSocketUrl: 'ws://www.parabeacon.icu/live'),
        ),
        throwsFormatException,
      );
    },
  );

  test('maps a real GPS fix to ParaBeacon Server telemetry fields', () {
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
      'vertical_speed': 0.0,
      'gps_altitude': 1234.5,
      'heading': 193.5,
      'bearing': 193.5,
      'wind_speed': 0.0,
      'wind_direction': 0.0,
    });
    final restoredPoint = LiveTrackpoint.fromJson(point.toJson());
    expect(restoredPoint?.groundSpeedMetersPerSecond, 10);
    expect(restoredPoint?.verticalSpeedMetersPerSecond, 0);
    expect(restoredPoint?.gpsAltitudeMeters, 1234.5);
    expect(restoredPoint?.bearingDegrees, 193.5);
    final simulatedFix = FlightData(
      hasFix: true,
      isMockLocation: true,
      latitude: 47.2,
      longitude: 8.6,
      altitude: 1100,
      groundSpeed: 30,
      timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    expect(LiveTrackpoint.fromFlightData(simulatedFix), isNull);
    expect(
      LiveTrackpoint.fromFlightData(simulatedFix, allowMockLocation: true),
      isNotNull,
    );
  });

  test(
    'loads all public pilot location pages for a validated viewport',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer proxy-test-token');
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/map/active-locations');
        expect(request.url.queryParameters['west'], '8.00000000000');
        expect(request.url.queryParameters['south'], '47.0000000000');
        expect(request.url.queryParameters['east'], '9.00000000000');
        expect(request.url.queryParameters['north'], '48.0000000000');
        if (requests.length == 1) {
          expect(request.url.queryParameters.containsKey('cursor'), isFalse);
          return http.Response(
            jsonEncode({
              'locations': [
                {
                  'pilot_name': 'Sky Rider',
                  'live_room_id': 'd2719b5c-6a1f-4a4e-8b67-85139941a201',
                  'pilot_number': 123456,
                  'channel_number': 483920,
                  'lat': 47.1,
                  'lon': 8.5,
                  'heading': 120.0,
                  'altitude': 1234.5,
                  'speed': 12.0,
                  'vertical_speed': -0.4,
                  'path': [
                    {
                      'lat': 47.0,
                      'lon': 8.4,
                      'altitude': 1200.0,
                      'speed': 10.0,
                      'timestamp': '2026-03-04T05:06:06.000Z',
                    },
                    {
                      'lat': 47.1,
                      'lon': 8.5,
                      'altitude': 1234.5,
                      'speed': 12.0,
                      'vertical_speed': -0.4,
                      'timestamp': '2026-03-04T05:06:09.000Z',
                    },
                  ],
                  'observed_at': '2026-03-04T05:06:09.000Z',
                },
              ],
              'next_cursor': 'cursor-page-two',
            }),
            200,
          );
        }
        expect(request.url.queryParameters['cursor'], 'cursor-page-two');
        return http.Response(
          jsonEncode({'locations': [], 'next_cursor': ''}),
          200,
        );
      });
      final service = LiveTrackingService(
        config: _config(),
        authProvider: _TestProxyAuthProvider(),
        pointStore: _MemoryProxyPointStore(),
        httpClient: client,
      );
      addTearDown(service.shutdown);
      addTearDown(client.close);

      final locations = await service.loadPublicPilotLocations(
        west: 8,
        south: 47,
        east: 9,
        north: 48,
      );

      expect(requests, hasLength(2));
      expect(locations, hasLength(1));
      expect(locations.single.pilotName, 'Sky Rider');
      expect(locations.single.pilotNumber, 123456);
      expect(locations.single.channelNumber, 483920);
      expect(locations.single.belongsToChannel(483920), isTrue);
      expect(locations.single.belongsToChannel(483921), isFalse);
      expect(locations.single.belongsToChannel(0), isFalse);
      expect(
        PublicPilotLocation.fromJson({
          'pilot_name': 'bad number',
          'pilot_number': 12345,
          'lat': 47.1,
          'lon': 8.5,
          'observed_at': '2026-03-04T05:06:09.000Z',
        }),
        isNull,
      );
      expect(
        PublicPilotLocation.fromJson({
          'pilot_name': 'bad channel',
          'channel_number': 1000000,
          'lat': 47.1,
          'lon': 8.5,
          'observed_at': '2026-03-04T05:06:09.000Z',
        }),
        isNull,
      );
      expect(
        locations.single.liveRoomId,
        'd2719b5c-6a1f-4a4e-8b67-85139941a201',
      );
      expect(
        locations.single.belongsToLiveRoom(
          'd2719b5c-6a1f-4a4e-8b67-85139941a201',
        ),
        isTrue,
      );
      expect(locations.single.belongsToLiveRoom('another-room'), isFalse);
      expect(locations.single.belongsToLiveRoom(null), isFalse);
      expect(locations.single.latitude, 47.1);
      expect(locations.single.headingDegrees, 120);
      expect(locations.single.altitudeMeters, 1234.5);
      expect(locations.single.groundSpeedMetersPerSecond, 12);
      expect(locations.single.verticalSpeedMetersPerSecond, -0.4);
      expect(locations.single.path, hasLength(2));
      expect(locations.single.path.first.latitude, 47.0);
      expect(
        locations.single.path.last.timestamp,
        DateTime.utc(2026, 3, 4, 5, 6, 9),
      );
      expect(locations.single.observedAt, DateTime.utc(2026, 3, 4, 5, 6, 9));
    },
  );

  test('shares a fresh ground location only with explicit opt-ins', () async {
    final settings = LiveTrackingSettings.instance;
    await settings.load();
    await settings.setParaBeaconEnabled(true);
    await settings.setShareLocationPublicly(true);
    await settings.setTemporaryDontShare(false);
    await settings.setShareLocationWhileNotFlying(true);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/tracking/sessions') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['pilot_name'], 'pilot-ground');
        expect(body['publicly_share'], isTrue);
        expect(DateTime.tryParse(body['start_time'] as String), isNotNull);
        return http.Response(jsonEncode({'session_id': 'ground-session'}), 201);
      }
      if (request.url.path.endsWith('/points')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['session_id'], 'ground-session');
        final points = body['trackpoints'] as List<dynamic>;
        expect(points, hasLength(1));
        expect((points.single as Map<String, dynamic>)['lat'], 47.2);
        return http.Response(jsonEncode({'accepted': 1}), 200);
      }
      expect(request.url.path, '/api/v1/tracking/sessions/ground-session/stop');
      return http.Response('', 204);
    });
    final now = DateTime.now().toUtc();
    final data = _MutableFlightDataView(
      FlightData(
        hasFix: true,
        latitude: 47.2,
        longitude: 8.6,
        gpsAltitude: 1100,
        groundSpeed: 0,
        gpsTimestamp: now,
      ),
    );
    final service = LiveTrackingService(
      config: _config(),
      authProvider: _TestProxyAuthProvider(),
      pointStore: _MemoryProxyPointStore(),
      httpClient: client,
    );
    service.bind(
      data: data,
      flightState: FlightState.instance,
      isEnabled: () =>
          settings.parabeaconEnabled && !settings.temporaryDontShare,
      pilotId: () => 'pilot-ground',
      isPubliclyShared: () => settings.shareLocationPublicly,
      eligibilitySource: settings,
    );
    await pumpEventQueue(times: 20);

    expect(FlightState.instance.isFlying, isFalse);
    expect(service.state, LiveTrackingConnectionState.active);
    expect(service.sessionId, 'ground-session');
    expect(requests.map((request) => request.url.path), [
      '/api/v1/tracking/sessions',
      '/api/v1/tracking/sessions/ground-session/points',
    ]);

    await settings.setShareLocationWhileNotFlying(false);
    await pumpEventQueue(times: 30);
    expect(service.sessionId, isNull);
    expect(
      requests.last.url.path,
      '/api/v1/tracking/sessions/ground-session/stop',
    );

    await service.shutdown();
    client.close();
    data.dispose();
    await settings.setShareLocationPublicly(false);
    await settings.setShareLocationWhileNotFlying(false);
    await settings.setParaBeaconEnabled(false);
  });

  test(
    'starts a session on active flight and uploads authenticated batches',
    () async {
      final startTime = DateTime.utc(2026, 3, 4, 5, 6, 7);
      final requests = <http.Request>[];
      var sharePublicly = true;
      final eligibilitySource = ChangeNotifier();
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer proxy-test-token');
        if (request.url.path == '/api/v1/tracking/sessions') {
          return http.Response(
            jsonEncode({'session_id': 'session-123'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path ==
            '/api/v1/tracking/sessions/session-123/public-sharing') {
          expect(request.method, 'PATCH');
          expect(jsonDecode(request.body), {'publicly_share': false});
          return http.Response('', 204);
        }
        if (request.url.path == '/api/v1/tracking/sessions/session-123/stop') {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session_id'], 'session-123');
          expect(DateTime.tryParse(body['end_time'] as String), isNotNull);
          return http.Response('', 204);
        }
        expect(
          request.url.path,
          '/api/v1/tracking/sessions/session-123/points',
        );
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
          'vertical_speed': 0.0,
          'gps_altitude': 1200.0,
          'heading': 123.4,
          'bearing': 123.4,
          'wind_speed': 0.0,
          'wind_direction': 0.0,
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
        pilotDisplayName: () => 'Sky Rider',
        isPubliclyShared: () => sharePublicly,
        eligibilitySource: eligibilitySource,
      );

      FlightState.instance.start(at: startTime);
      await pumpEventQueue(times: 20);

      expect(service.lastErrorCode, isNull);
      expect(service.state, LiveTrackingConnectionState.active);
      expect(service.sessionId, 'session-123');
      expect(service.pendingPointCount, 0);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/tracking/sessions',
        '/api/v1/tracking/sessions/session-123/points',
      ]);
      expect(jsonDecode(requests.first.body), {
        'pilot_name': 'Sky Rider',
        'start_time': startTime.toIso8601String(),
        'publicly_share': true,
      });

      sharePublicly = false;
      eligibilitySource.notifyListeners();
      await pumpEventQueue(times: 20);
      expect(
        requests.map((request) => request.url.path),
        contains('/api/v1/tracking/sessions/session-123/public-sharing'),
      );

      FlightState.instance.stop();
      await pumpEventQueue(times: 10);
      expect(service.state, LiveTrackingConnectionState.disconnected);
      expect(
        requests.last.url.path,
        '/api/v1/tracking/sessions/session-123/stop',
      );
      await service.shutdown();
      client.close();
      data.dispose();
      eligibilitySource.dispose();
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
  String? authEndpoint,
  String? webSocketUrl,
  List<Object> channelIds = const [],
}) => {
  'session_start_endpoint': '/api/v1/tracking/sessions',
  'session_stop_endpoint': '/api/v1/tracking/sessions/{session_id}/stop',
  'points_endpoint': '/api/v1/tracking/sessions/{session_id}/points',
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
