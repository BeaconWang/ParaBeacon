import 'package:flutter/foundation.dart';

import 'flight_data.dart';
import 'flight_state.dart';

@immutable
class TakeoffPoint {
  const TakeoffPoint({this.latitude, this.longitude, this.altitude});

  final double? latitude;
  final double? longitude;
  final double? altitude;
}

/// One shared takeoff origin for every control in the active flight.
///
/// Position and altitude are captured from the transformed flight-data feed.
/// When GPS is unavailable at start, the service waits for its first valid fix;
/// altitude can still be captured from a barometric reading in the meantime.
class TakeoffReference extends ChangeNotifier {
  TakeoffReference._();

  static final TakeoffReference instance = TakeoffReference._();

  FlightDataView? _source;
  FlightState? _flightState;
  TakeoffPoint? _point;

  TakeoffPoint? get point => _point;

  void bind(FlightDataView source, {FlightState? flightState}) {
    final state = flightState ?? FlightState.instance;
    if (identical(_source, source) && identical(_flightState, state)) return;

    unbind();
    _source = source;
    _flightState = state;
    source.addListener(_onDataChanged);
    state.addListener(_onFlightStateChanged);
    if (state.isFlying) _captureAvailableFields(source.data);
  }

  void unbind() {
    _source?.removeListener(_onDataChanged);
    _flightState?.removeListener(_onFlightStateChanged);
    _source = null;
    _flightState = null;
    _clearPoint();
  }

  void _onFlightStateChanged() {
    final state = _flightState;
    if (state == null) return;
    if (state.isFlying) {
      final source = _source;
      if (source != null) _captureAvailableFields(source.data);
    } else {
      _clearPoint();
    }
  }

  void _onDataChanged() {
    if (_flightState?.isFlying != true) return;
    final source = _source;
    if (source != null) _captureAvailableFields(source.data);
  }

  void _captureAvailableFields(FlightData data) {
    final oldPoint = _point;
    final hasPosition = _hasValidPosition(data);
    final hasAltitude =
        (data.hasFix || data.baroAltitude != null) && data.altitude.isFinite;
    final latitude = oldPoint?.latitude ?? (hasPosition ? data.latitude : null);
    final longitude =
        oldPoint?.longitude ?? (hasPosition ? data.longitude : null);
    final altitude = oldPoint?.altitude ?? (hasAltitude ? data.altitude : null);

    if (latitude == oldPoint?.latitude &&
        longitude == oldPoint?.longitude &&
        altitude == oldPoint?.altitude) {
      return;
    }

    _point = TakeoffPoint(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );
    notifyListeners();
  }

  bool _hasValidPosition(FlightData data) =>
      data.hasFix &&
      data.latitude.isFinite &&
      data.longitude.isFinite &&
      data.latitude >= -90 &&
      data.latitude <= 90 &&
      data.longitude >= -180 &&
      data.longitude <= 180;

  void _clearPoint() {
    if (_point == null) return;
    _point = null;
    notifyListeners();
  }
}
