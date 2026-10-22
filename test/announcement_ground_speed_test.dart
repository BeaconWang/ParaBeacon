import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';

void main() {
  test('ground-speed override marks the value as available', () {
    const base = FlightData(groundSpeed: 0, hasGroundSpeed: false);
    final effective = const FlightDataOverride(groundSpeed: 42.5).applyTo(base);

    expect(effective.groundSpeed, 42.5);
    expect(effective.hasGroundSpeed, isTrue);
  });

  test('no ground-speed override preserves availability', () {
    const base = FlightData(groundSpeed: 18, hasGroundSpeed: false);
    final effective = const FlightDataOverride(verticalSpeed: 1).applyTo(base);

    expect(effective.groundSpeed, 18);
    expect(effective.hasGroundSpeed, isFalse);
  });
}
