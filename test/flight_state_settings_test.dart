import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parabeacon/data/flight_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and clamps persisted landing detection settings', () async {
    SharedPreferences.setMockInitialValues({
      'pb.flight.minimumLandingFlightSeconds': 90,
      'pb.flight.landingSpeedSensitivity': 1.25,
    });
    final flight = FlightState.instance;

    await flight.loadSettings();

    expect(flight.minimumLandingFlightSeconds, 90);
    expect(flight.landingSpeedSensitivity, 1.25);

    flight.setMinimumLandingFlightSeconds(200);
    flight.setLandingSpeedSensitivity(2.0);
    expect(flight.minimumLandingFlightSeconds, 120);
    expect(flight.landingSpeedSensitivity, 1.5);
  });
}
