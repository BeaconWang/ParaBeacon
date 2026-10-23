/// A minimum/maximum number of fractional digits for one displayed value.
class DecimalPlaceRange {
  final int min;
  final int max;

  const DecimalPlaceRange(this.min, this.max);

  static const maxSupportedPlaces = 8;

  static DecimalPlaceRange? parse(Object? value) {
    if (value is! String || value == 'auto') return null;
    final match = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (match == null) return null;
    final min = int.parse(match.group(1)!);
    final max = int.parse(match.group(2)!);
    if (min > max || max > maxSupportedPlaces) return null;
    return DecimalPlaceRange(min, max);
  }

  String encode() => '$min-$max';

  @override
  bool operator ==(Object other) =>
      other is DecimalPlaceRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Returns the keys that follow the app-wide default-precision switch.
///
/// Other decimal settings retain their existing per-value automatic precision.
int? defaultDecimalPlacesForControl(String typeId, String key, bool enabled) {
  final applies = switch ((typeId, key)) {
    ('gps_accuracy', 'valueDecimals') => true,
    ('altitude' || 'gps_altitude' || 'baro_altitude', 'valueDecimals') => true,
    ('max_altitude' || 'altitude_above_takeoff', 'valueDecimals') => true,
    ('vertical_graph', 'altitudeDecimals') => true,
    ('thermal_gain', 'valueDecimals') => true,
    ('takeoff_waypoint', 'altitudeDifferenceDecimals') => true,
    ('ground_speed', 'valueDecimals') => true,
    ('vertical_speed' || 'vario', 'valueDecimals') => true,
    ('glide_ratio', 'varioDecimals') => true,
    ('climb_avg', 'averageDecimals' || 'peakDecimals') => true,
    ('wind_speed', 'valueDecimals') => true,
    ('status_line', 'accuracyDecimals') => true,
    ('compass_wind', 'windSpeedDecimals') => true,
    (
      'data_monitor',
      'monitorVerticalSpeedDecimals' ||
          'monitorGroundSpeedDecimals' ||
          'monitorAltitudeDecimals' ||
          'monitorBaroAltitudeDecimals' ||
          'monitorGpsAltitudeDecimals' ||
          'monitorGpsAccuracyDecimals' ||
          'monitorWindSpeedDecimals' ||
          'monitorAltitudeDeltaDecimals' ||
          'monitorTotalEnergyDecimals',
    ) =>
      true,
    (
      'debug_sensor',
      'verticalSpeedDecimals' ||
          'altitudeDecimals' ||
          'groundSpeedDecimals' ||
          'windSpeedDecimals',
    ) =>
      true,
    (
      'map',
      'mapAltitudeDecimals' ||
          'mapWindSpeedDecimals' ||
          'mapVarioColorMinDecimals' ||
          'mapVarioSinkDecimals' ||
          'mapVarioLiftDecimals' ||
          'mapVarioColorMaxDecimals',
    ) =>
      true,
    _ => false,
  };
  return applies ? (enabled ? 1 : 0) : null;
}

/// Formats [value] with the default precision unless [range] overrides it.
/// Configured ranges show up to [DecimalPlaceRange.max] digits and trim trailing
/// zeroes without going below [DecimalPlaceRange.min].
String formatDecimalValue(
  double value, {
  required int autoDecimals,
  DecimalPlaceRange? range,
}) {
  if (!value.isFinite) return value.toString();
  final decimals =
      range?.max ??
      autoDecimals.clamp(0, DecimalPlaceRange.maxSupportedPlaces).toInt();
  var formatted = value.toStringAsFixed(decimals);
  if (range == null) return formatted;
  final dot = formatted.indexOf('.');
  if (dot < 0) return formatted;
  while (formatted.length > dot + 1 + range.min && formatted.endsWith('0')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  if (formatted.endsWith('.')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}
