import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/auto_flight_detector.dart';
import 'package:parabeacon/data/flight_data.dart';

void main() {
  group('AutoFlightDetector', () {
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
    }) {
      final time = epoch.add(Duration(seconds: second));
      return detector.update(
        data: _data(time: time, speedKph: speedKph, secondsFromStart: second),
        observedAt: time,
        isFlying: isFlying,
        flightStartedAt: startedAt,
        autoDetectEnabled: true,
        landingMode: mode,
        takeoffSpeedKph: 6,
      );
    }

    test('starts after sustained speed above the configured threshold', () {
      for (var second = 0; second < 8; second++) {
        expect(update(second: second, speedKph: 10), isNull);
      }
      expect(update(second: 8, speedKph: 10), AutoFlightAction.takeoff);
    });

    test('does not start from a stale GPS fix', () {
      final staleTime = epoch.subtract(const Duration(seconds: 20));
      expect(
        detector.update(
          data: _data(
            time: epoch,
            speedKph: 18,
          ).copyWith(gpsTimestamp: staleTime),
          observedAt: epoch,
          isFlying: false,
          flightStartedAt: null,
          autoDetectEnabled: true,
          landingMode: LandingDetectionMode.automatic,
          takeoffSpeedKph: 6,
        ),
        isNull,
      );
    });

    test('keeps GPS time separate through snapshots and serialization', () {
      final gpsTime = epoch.subtract(const Duration(seconds: 4));
      final snapshot = _data(time: epoch, speedKph: 12).copyWith(
        gpsTimestamp: gpsTime,
        timestamp: epoch.add(const Duration(seconds: 1)),
      );

      expect(snapshot.gpsTimestamp, gpsTime);
      expect(FlightData.fromJson(snapshot.toJson()).gpsTimestamp, gpsTime);
      expect(
        FlightData.fromJson(snapshot.toJson(compact: true)).gpsTimestamp,
        gpsTime,
      );
    });

    test('restarts the take-off window after a GPS sample gap', () {
      expect(update(second: 0, speedKph: 10), isNull);
      expect(update(second: 1, speedKph: 10), isNull);
      expect(update(second: 5, speedKph: 10), isNull);
      for (var second = 6; second < 13; second++) {
        expect(update(second: second, speedKph: 10), isNull);
      }
      expect(update(second: 13, speedKph: 10), AutoFlightAction.takeoff);
    });

    test('No detection suppresses automatic landing', () {
      for (var second = 30; second <= 40; second++) {
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
      'manual mode requests confirmation once and cools down after cancel',
      () {
        AutoFlightAction? action;
        for (var second = 30; second <= 38; second++) {
          action = update(
            second: second,
            speedKph: 0,
            isFlying: true,
            startedAt: epoch,
            mode: LandingDetectionMode.manual,
          );
        }
        expect(action, AutoFlightAction.requestLandingConfirmation);
        expect(detector.hasPendingLandingConfirmation, isTrue);

        detector.resolveLandingConfirmation(
          landed: false,
          resolvedAt: epoch.add(const Duration(seconds: 38)),
        );
        for (var second = 39; second <= 68; second++) {
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
      },
    );

    test('automatic landing waits at least 30 seconds after take-off', () {
      for (var second = 0; second <= 29; second++) {
        expect(
          update(second: second, speedKph: 0, isFlying: true, startedAt: epoch),
          isNull,
        );
      }
      for (var second = 30; second < 38; second++) {
        expect(
          update(second: second, speedKph: 0, isFlying: true, startedAt: epoch),
          isNull,
        );
      }
      expect(
        update(second: 38, speedKph: 0, isFlying: true, startedAt: epoch),
        AutoFlightAction.automaticLanding,
      );
    });
  });
}

FlightData _data({
  required DateTime time,
  required double speedKph,
  int secondsFromStart = 0,
}) {
  final distanceM = (speedKph / 3.6) * secondsFromStart;
  return FlightData(
    groundSpeed: speedKph,
    latitude: 30 + distanceM / 111320,
    longitude: 104,
    verticalSpeed: 0,
    gpsAccuracy: 5,
    hasFix: true,
    timestamp: time,
    gpsTimestamp: time,
  );
}
