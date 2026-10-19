import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/auto_flight_detector.dart';
import 'package:parabeacon/data/flight_data.dart';

void main() {
  group('AutoFlightDetector XCTrack parity', () {
    late AutoFlightDetector detector;
    final epoch = DateTime.utc(2026, 1, 1);

    setUp(() {
      detector = AutoFlightDetector();
    });

    AutoFlightAction? update({
      required int second,
      required double speedKph,
      bool isFlying = false,
      DateTime? startedAt,
      LandingDetectionMode mode = LandingDetectionMode.automatic,
      double? gpsAltitude,
      double? terrainElevationM,
      double windSpeedKph = 0,
      bool isMockLocation = false,
    }) {
      final time = epoch.add(Duration(seconds: second));
      return detector.update(
        data: _data(
          time: time,
          speedKph: speedKph,
          secondsFromStart: second,
          gpsAltitude: gpsAltitude,
          terrainElevationM: terrainElevationM,
          windSpeedKph: windSpeedKph,
          isMockLocation: isMockLocation,
        ),
        observedAt: time,
        isFlying: isFlying,
        flightStartedAt: startedAt,
        autoDetectEnabled: true,
        landingMode: mode,
        takeoffSpeedKph: 6,
        trimSpeedKph: 38,
        monotonicTime: Duration(seconds: second),
      );
    }

    test('take-off uses current, previous-point, and three-back speeds', () {
      for (var second = 0; second < 3; second++) {
        expect(update(second: second, speedKph: 10), isNull);
      }
      expect(update(second: 3, speedKph: 10), AutoFlightAction.takeoff);
    });

    test('take-off speed threshold comparison is strict', () {
      for (var second = 0; second < 8; second++) {
        expect(update(second: second, speedKph: 6), isNull);
      }
    });

    test('a low position-derived speed vetoes take-off', () {
      for (var second = 0; second < 12; second++) {
        final time = epoch.add(Duration(seconds: second));
        expect(
          detector.update(
            data: FlightData(
              groundSpeed: 10,
              latitude: 30,
              longitude: 104,
              hasFix: true,
              timestamp: time,
              gpsTimestamp: time,
            ),
            observedAt: time,
            isFlying: false,
            flightStartedAt: null,
            autoDetectEnabled: true,
            landingMode: LandingDetectionMode.automatic,
            takeoffSpeedKph: 6,
            trimSpeedKph: 38,
            monotonicTime: Duration(seconds: second),
          ),
          isNull,
        );
      }
    });

    test('uses position-derived speed when GPS reports no speed', () {
      for (var second = 0; second < 3; second++) {
        final time = epoch.add(Duration(seconds: second));
        expect(
          detector.update(
            data: _data(
              time: time,
              speedKph: 10,
              secondsFromStart: second,
            ).copyWith(groundSpeed: 0, hasGroundSpeed: false),
            observedAt: time,
            isFlying: false,
            flightStartedAt: null,
            autoDetectEnabled: true,
            landingMode: LandingDetectionMode.automatic,
            takeoffSpeedKph: 6,
            trimSpeedKph: 38,
            monotonicTime: Duration(seconds: second),
          ),
          isNull,
        );
      }
      final time = epoch.add(const Duration(seconds: 3));
      expect(
        detector.update(
          data: _data(
            time: time,
            speedKph: 10,
            secondsFromStart: 3,
          ).copyWith(groundSpeed: 0, hasGroundSpeed: false),
          observedAt: time,
          isFlying: false,
          flightStartedAt: null,
          autoDetectEnabled: true,
          landingMode: LandingDetectionMode.automatic,
          takeoffSpeedKph: 6,
          trimSpeedKph: 38,
          monotonicTime: const Duration(seconds: 3),
        ),
        AutoFlightAction.takeoff,
      );
    });

    test('invalid Null Island GPS fix is ignored', () {
      final time = epoch.add(const Duration(seconds: 1));
      expect(
        detector.update(
          data: FlightData(
            hasFix: true,
            timestamp: time,
            gpsTimestamp: time,
            groundSpeed: 30,
          ),
          observedAt: time,
          isFlying: false,
          flightStartedAt: null,
          autoDetectEnabled: true,
          landingMode: LandingDetectionMode.automatic,
          takeoffSpeedKph: 6,
          trimSpeedKph: 38,
        ),
        isNull,
      );
    });

    test('No detection suppresses landing but speed slots keep updating', () {
      for (var second = 0; second <= 35; second++) {
        expect(
          update(
            second: second,
            speedKph: 0,
            isFlying: true,
            startedAt: epoch,
            mode: LandingDetectionMode.noDetection,
          ),
          isNull,
        );
      }
    });

    test(
      'landing requires strictly more than 30 seconds, then stops directly',
      () {
        expect(
          update(second: 30, speedKph: 0, isFlying: true, startedAt: epoch),
          isNull,
        );
        expect(
          update(second: 31, speedKph: 0, isFlying: true, startedAt: epoch),
          AutoFlightAction.automaticLanding,
        );
      },
    );

    test('landing limit uses terrain altitude and wind/trim ratio', () {
      expect(
        update(
          second: 31,
          speedKph: 3,
          isFlying: true,
          startedAt: epoch,
          gpsAltitude: 0,
          terrainElevationM: 0,
        ),
        AutoFlightAction.automaticLanding,
      );

      detector.reset();
      for (var second = 0; second <= 30; second++) {
        update(
          second: second,
          speedKph: 0,
          isFlying: true,
          startedAt: epoch,
          gpsAltitude: 0,
          terrainElevationM: 0,
          windSpeedKph: 38,
        );
      }
      expect(
        update(
          second: 31,
          speedKph: 3,
          isFlying: true,
          startedAt: epoch,
          gpsAltitude: 0,
          terrainElevationM: 0,
          windSpeedKph: 38,
        ),
        isNull,
      );
    });

    test(
      'manual cooldown starts when confirmation is requested, not dismissed',
      () {
        expect(
          update(
            second: 31,
            speedKph: 0,
            isFlying: true,
            startedAt: epoch,
            mode: LandingDetectionMode.manual,
          ),
          AutoFlightAction.requestLandingConfirmation,
        );
        detector.resolveLandingConfirmation();

        for (var second = 32; second < 61; second++) {
          expect(
            update(
              second: second,
              speedKph: 0,
              isFlying: true,
              startedAt: epoch,
              mode: LandingDetectionMode.manual,
            ),
            isNull,
          );
        }
        expect(
          update(
            second: 61,
            speedKph: 0,
            isFlying: true,
            startedAt: epoch,
            mode: LandingDetectionMode.manual,
          ),
          AutoFlightAction.requestLandingConfirmation,
        );
      },
    );

    test('manual mode directly lands for mock GPS locations', () {
      expect(
        update(
          second: 31,
          speedKph: 0,
          isFlying: true,
          startedAt: epoch,
          mode: LandingDetectionMode.manual,
          isMockLocation: true,
        ),
        AutoFlightAction.automaticLanding,
      );
    });

    test(
      'GPS and terrain timestamps and values survive track serialization',
      () {
        final time = epoch.add(const Duration(seconds: 2));
        final data = _data(
          time: time,
          speedKph: 12,
          gpsAltitude: 1250,
          terrainElevationM: 850,
          isMockLocation: true,
        ).copyWith(timestamp: time.add(const Duration(seconds: 1)));

        for (final compact in [false, true]) {
          final restored = FlightData.fromJson(data.toJson(compact: compact));
          expect(restored.gpsTimestamp, time);
          expect(restored.terrainElevationM, 850);
          expect(restored.isMockLocation, isTrue);
        }
      },
    );
  });
}

FlightData _data({
  required DateTime time,
  required double speedKph,
  int secondsFromStart = 0,
  double? gpsAltitude,
  double? terrainElevationM,
  double windSpeedKph = 0,
  bool isMockLocation = false,
}) {
  final distanceM = (speedKph / 3.6) * secondsFromStart;
  return FlightData(
    groundSpeed: speedKph,
    latitude: 30 + distanceM / 111320,
    longitude: 104,
    gpsAltitude: gpsAltitude,
    terrainElevationM: terrainElevationM,
    windSpeed: windSpeedKph,
    hasFix: true,
    isMockLocation: isMockLocation,
    timestamp: time,
    gpsTimestamp: time,
  );
}
