import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_data_transformer.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';

void main() {
  test('vertical-speed averaging window updates at runtime', () {
    final source = _MutableFlightDataSource()
      ..publish(const FlightData(verticalSpeed: 1.7));
    final transformer = FlightDataTransformer(rawSource: source);
    var notifications = 0;
    transformer.addListener(() => notifications++);

    expect(source.data.verticalSpeed, 1.7);
    expect(transformer.data.verticalSpeed, 1.7);

    transformer.setVerticalSpeedWindow(const Duration(milliseconds: 2500));
    expect(transformer.verticalSpeedWindow, const Duration(milliseconds: 2500));
    expect(transformer.data.verticalSpeed, 1.7);
    expect(notifications, 1);

    transformer.setVerticalSpeedWindow(const Duration(seconds: 8));
    expect(transformer.verticalSpeedWindow, const Duration(seconds: 3));

    transformer.dispose();
    source.dispose();
  });
}

class _MutableFlightDataSource extends RawFlightDataSource {
  void publish(FlightData data) => update(data);
}
