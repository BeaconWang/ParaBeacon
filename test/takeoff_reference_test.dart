import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:parabeacon/data/takeoff_reference.dart';
import 'package:parabeacon/data/unit_settings.dart';

class _MutableFlightDataView extends ChangeNotifier implements FlightDataView {
  FlightData _data;

  _MutableFlightDataView(this._data);

  @override
  FlightData get data => _data;

  void update(FlightData data) {
    _data = data;
    notifyListeners();
  }
}

void main() {
  final state = FlightState.instance;
  final reference = TakeoffReference.instance;
  late _MutableFlightDataView source;

  setUp(() {
    state.stop();
    reference.unbind();
    source = _MutableFlightDataView(const FlightData());
    reference.bind(source);
  });

  tearDown(() {
    state.stop();
    reference.unbind();
  });

  test('captures one takeoff point for distance and altitude controls', () {
    source.update(
      const FlightData(
        latitude: 47.0,
        longitude: 8.0,
        altitude: 1200,
        hasFix: true,
      ),
    );

    state.start();
    final takeoffPoint = reference.point;
    expect(takeoffPoint, isNotNull);
    expect(takeoffPoint!.latitude, 47.0);
    expect(takeoffPoint.longitude, 8.0);
    expect(takeoffPoint.altitude, 1200);

    source.update(
      const FlightData(
        latitude: 47.001,
        longitude: 8.002,
        altitude: 1340,
        hasFix: true,
      ),
    );
    expect(reference.point, same(takeoffPoint));

    final meters = GeoMath.distanceMeters(
      reference.point!.latitude!,
      reference.point!.longitude!,
      source.data.latitude,
      source.data.longitude,
    );
    expect(UnitValues.formatDistance(meters, 'auto'), isNotEmpty);
    expect(
      UnitValues.formatAltitudeDifference(
        source.data.altitude - reference.point!.altitude!,
        'm',
      ),
      '+140',
    );

    state.stop();
    expect(reference.point, isNull);
  });

  test(
    'captures altitude before GPS and fills position when a fix arrives',
    () {
      state.start();
      source.update(const FlightData(altitude: 800, baroAltitude: 800));
      expect(reference.point?.altitude, 800);
      expect(reference.point?.latitude, isNull);

      source.update(
        const FlightData(
          latitude: 47.2,
          longitude: 8.1,
          altitude: 820,
          hasFix: true,
        ),
      );
      expect(reference.point?.altitude, 800);
      expect(reference.point?.latitude, 47.2);
      expect(reference.point?.longitude, 8.1);
    },
  );

  test('waits for a valid GPS fix if the flight starts without one', () {
    state.start();
    expect(reference.point, isNull);

    source.update(
      const FlightData(
        latitude: double.nan,
        longitude: 8.0,
        altitude: 1000,
        hasFix: true,
      ),
    );
    expect(reference.point?.latitude, isNull);

    source.update(
      const FlightData(
        latitude: 47.2,
        longitude: 8.1,
        altitude: 1000,
        hasFix: true,
      ),
    );
    expect(reference.point?.latitude, 47.2);
    expect(reference.point?.longitude, 8.1);
  });

  test('formats distance consistently for automatic and fixed units', () {
    expect(UnitValues.formatDistance(5.44, 'm'), '5.4');
    expect(UnitValues.formatDistance(125.4, 'm'), '125');
    expect(UnitValues.formatDistance(1500, 'auto'), '1.5');
    expect(UnitValues.formatDistance(90, 'ft'), '295');
  });
}
