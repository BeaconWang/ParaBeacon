import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/live_tracking_protocol.dart';

void main() {
  group('LiveTrackpointCodec', () {
    final points = [
      const LiveTrackpoint(
        latitudeE6: 47123456,
        longitudeE6: 8123456,
        timestampSeconds: 1735000000,
        gpsAltitudeM: 1400,
        baroAltitudeM: 1320,
        elevationM: 800,
      ),
      const LiveTrackpoint(
        latitudeE6: 47123478,
        longitudeE6: 8123490,
        timestampSeconds: 1735000005,
        gpsAltitudeM: 1408,
        baroAltitudeM: 1327,
        elevationM: 800,
      ),
    ];

    test('round-trips absolute first point and subsequent deltas', () {
      final encoded = LiveTrackpointCodec.encode(points);
      final decoded = LiveTrackpointCodec.decode(encoded);

      expect(encoded.codeUnits, everyElement(inInclusiveRange(63, 126)));
      expect(decoded, points.map((point) => point.toVector()).toList());
    });

    test('rejects out-of-order points', () {
      expect(
        () => LiveTrackpointCodec.encode(points.reversed.toList()),
        throwsFormatException,
      );
    });

    test('serializes compressed points as a tagged text frame', () {
      final frame = liveChunkFrame(points);

      expect(frame['tag'], 'xcSendChunkHP');
      expect(frame['pointsHP'], isA<String>());
      expect(frame.containsKey('addInfo'), isFalse);
    });
  });

  group('LiveTrackingSessionRequest', () {
    test('uses the observed server JSON field names', () {
      final request = LiveTrackingSessionRequest(
        position: const {'lat': 47.0, 'lon': 8.0},
        device: const LiveTrackingDeviceInfo(
          device: 'Test device',
          os: 'Test OS',
          app: 'ParaBeacon',
          deviceId: 'device-id',
        ),
        glider: 'glider-model',
        gliderCat: 'C',
        tandem: false,
        simulation: false,
        isPublic: true,
        faiCompliant: true,
        flarmRadioId: 'radio-id',
      );

      final json = request.toJson();
      expect(json['public'], isTrue);
      expect(json.containsKey('flpublic'), isFalse);
      expect(json['protoVersion'], 4);
      expect(json['device'], {
        'device': 'Test device',
        'os': 'Test OS',
        'app': 'ParaBeacon',
        'deviceId': 'device-id',
      });
    });
  });

  group('LiveTrackingConfig', () {
    test('resolves the relative flight endpoint below the configured base', () {
      final config = LiveTrackingConfig(
        apiBaseUri: Uri.https('tracking.example', '/api/v1'),
      );

      expect(config.flightUri, Uri.https('tracking.example', '/api/v1/flight'));
    });

    test('rejects insecure or internal API endpoints', () {
      expect(
        () => LiveTrackingConfig(apiBaseUri: Uri.http('tracking.example', '')),
        throwsArgumentError,
      );
      expect(
        () => LiveTrackingConfig(apiBaseUri: Uri.https('10.2.3.4', 'api')),
        throwsArgumentError,
      );
    });

    test(
      'restricts session-provided socket hosts to the configured allowlist',
      () {
        final config = LiveTrackingConfig(
          apiBaseUri: Uri.https('tracking.example', '/api'),
        );

        expect(
          () => config.validateWebSocketUri(
            Uri.parse('wss://elsewhere.example/'),
          ),
          throwsFormatException,
        );
        expect(
          () =>
              config.validateWebSocketUri(Uri.parse('ws://tracking.example/')),
          throwsFormatException,
        );
      },
    );
  });

  test('converts only real, valid GPS fixes into telemetry points', () {
    final point = LiveTrackpoint.fromFlightData(
      FlightData(
        hasFix: true,
        latitude: 47.0,
        longitude: 8.0,
        gpsAltitude: 1400.4,
        baroAltitude: 1320.6,
        terrainElevationM: 800.2,
        gpsTimestamp: DateTime.utc(2025, 1, 1, 12),
      ),
    );

    expect(point.latitudeE6, 47000000);
    expect(point.longitudeE6, 8000000);
    expect(point.timestampSeconds, 1735732800);
    expect(point.gpsAltitudeM, 1400);
    expect(point.baroAltitudeM, 1321);
    expect(point.elevationM, 800);

    expect(
      () => LiveTrackpoint.fromFlightData(
        const FlightData(hasFix: true, isMockLocation: true),
        at: DateTime.utc(2025),
      ),
      throwsFormatException,
    );
  });
}
