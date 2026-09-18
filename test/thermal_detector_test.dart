import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/thermal_detector.dart';

void _feedThermalCycle(
  ThermalDetector detector, {
  required int offsetSeconds,
  required double latitude,
}) {
  final start = DateTime.utc(2026, 1, 1).add(Duration(seconds: offsetSeconds));
  for (var i = 0; i < 8; i++) {
    detector.add(
      lat: latitude,
      lon: 100.0,
      climbMps: 1.0,
      time: start.add(Duration(seconds: i)),
    );
  }
  for (var i = 8; i < 16; i++) {
    detector.add(
      lat: latitude,
      lon: 100.0,
      climbMps: -1.0,
      time: start.add(Duration(seconds: i)),
    );
  }
}

void main() {
  test('commits a completed thermal and exposes it in newest-last order', () {
    final detector = ThermalDetector();

    _feedThermalCycle(detector, offsetSeconds: 0, latitude: 30.0);

    expect(detector.history, hasLength(1));
    expect(detector.history.single.centerLat, closeTo(30.0, 1e-9));
    expect(detector.history.single.avgClimbMps, greaterThan(0.5));
  });

  test('keeps enough history for the map setting maximum of 12 thermals', () {
    final detector = ThermalDetector();

    for (var i = 0; i < 13; i++) {
      _feedThermalCycle(
        detector,
        offsetSeconds: i * 30,
        latitude: 30.0 + i * 0.01,
      );
    }

    expect(detector.history, hasLength(12));
    expect(detector.history.first.centerLat, closeTo(30.01, 1e-9));
    expect(detector.history.last.centerLat, closeTo(30.12, 1e-9));
  });

  test('merges a repeated core instead of adding a duplicate marker', () {
    final detector = ThermalDetector();

    _feedThermalCycle(detector, offsetSeconds: 0, latitude: 30.0);
    _feedThermalCycle(detector, offsetSeconds: 30, latitude: 30.0001);

    expect(detector.history, hasLength(1));
  });
}
