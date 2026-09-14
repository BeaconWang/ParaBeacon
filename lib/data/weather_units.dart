import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Unit contract ─────────────────────────────────────────────────────────────
//
// The user's unit preferences flow into the weather request itself
// (Open-Meteo `temperature_unit` / `wind_speed_unit` / `precipitation_unit`
// parameters) and double as the display labels. Adapters for vendors that
// cannot honor the requested units server-side convert their metric values
// into the requested units client-side via [convertTemperature] /
// [convertWindFromKmh] / [convertPrecipFromMm], keeping the unified-model
// contract: every [WeatherData] value is already in the requested units.

/// Temperature units accepted by Open-Meteo's `temperature_unit` parameter.
enum TemperatureUnit {
  celsius,
  fahrenheit;

  /// Value for the Open-Meteo `temperature_unit` parameter.
  String get apiValue => name; // 'celsius' | 'fahrenheit'

  /// Display label appended to temperature values.
  String get symbol => this == TemperatureUnit.fahrenheit ? '°F' : '°C';
}

/// Wind speed units accepted by Open-Meteo's `wind_speed_unit` parameter.
enum WindSpeedUnit {
  kmh,
  ms,
  mph,
  kn;

  /// Value for the Open-Meteo `wind_speed_unit` parameter.
  String get apiValue => name; // 'kmh' | 'ms' | 'mph' | 'kn'

  /// Display label appended to wind speed values.
  String get symbol => switch (this) {
        WindSpeedUnit.kmh => 'km/h',
        WindSpeedUnit.ms => 'm/s',
        WindSpeedUnit.mph => 'mph',
        WindSpeedUnit.kn => 'kn',
      };
}

/// Precipitation units accepted by Open-Meteo's `precipitation_unit`
/// parameter.
enum PrecipitationUnit {
  mm,
  inch;

  /// Value for the Open-Meteo `precipitation_unit` parameter.
  String get apiValue => name; // 'mm' | 'inch'

  /// Display label appended to precipitation amounts.
  String get symbol => this == PrecipitationUnit.inch ? 'in' : 'mm';
}

/// The complete unit configuration, resolved for one fetch.
class WeatherUnits {
  final TemperatureUnit temperature;
  final WindSpeedUnit wind;
  final PrecipitationUnit precipitation;

  const WeatherUnits({
    this.temperature = TemperatureUnit.celsius,
    this.wind = WindSpeedUnit.kmh,
    this.precipitation = PrecipitationUnit.mm,
  });

  /// Metric defaults used when no preference has been resolved yet
  /// (matches the app's historical display conventions).
  static const WeatherUnits metric = WeatherUnits();

  // ── Value conversion (canonical base = metric: °C, km/h, mm) ──────────────

  /// Converts a value that arrived in [from] units into [to] units.
  static double convertTemperature(
      double value, TemperatureUnit from, TemperatureUnit to) {
    if (from == to) return value;
    final celsius = from == TemperatureUnit.fahrenheit ? (value - 32) / 1.8 : value;
    return to == TemperatureUnit.fahrenheit ? celsius * 1.8 + 32 : celsius;
  }

  /// Canonical metric (km/h) → target wind unit.
  static double convertWindFromKmh(double kmh, WindSpeedUnit to) =>
      switch (to) {
        WindSpeedUnit.kmh => kmh,
        WindSpeedUnit.ms => kmh / 3.6,
        WindSpeedUnit.mph => kmh / 1.609344,
        WindSpeedUnit.kn => kmh / 1.852,
      };

  /// Canonical metric (mm) → target precipitation unit.
  static double convertPrecipFromMm(double mm, PrecipitationUnit to) =>
      to == PrecipitationUnit.inch ? mm / 25.4 : mm;

  /// Converts a value expressed in the *requested* unit back to km/h —
  /// used by the wind-flow animation, whose physics need canonical units.
  static double windToKmh(double value, WindSpeedUnit from) =>
      switch (from) {
        WindSpeedUnit.kmh => value,
        WindSpeedUnit.ms => value * 3.6,
        WindSpeedUnit.mph => value * 1.609344,
        WindSpeedUnit.kn => value * 1.852,
      };

  /// Converts a value expressed in the *requested* unit back to °C —
  /// used by the temperature palette of the background layers.
  static double temperatureToCelsius(double value, TemperatureUnit from) =>
      from == TemperatureUnit.celsius
          ? value
          : (value - 32) / 1.8;
}

// ── Persisted settings ────────────────────────────────────────────────────────

/// User-selected display/request units. Persisted in this device's
/// SharedPreferences; no account, no sync, nothing secret.
class WeatherUnitSettings extends ChangeNotifier {
  WeatherUnitSettings._();
  static final WeatherUnitSettings instance = WeatherUnitSettings._();

  static const _kTemperature = 'pb.weather.units.temperature';
  static const _kWind = 'pb.weather.units.wind';
  static const _kPrecipitation = 'pb.weather.units.precipitation';

  TemperatureUnit _temperature = TemperatureUnit.celsius;
  WindSpeedUnit _wind = WindSpeedUnit.kmh;
  PrecipitationUnit _precipitation = PrecipitationUnit.mm;
  bool _loaded = false;

  TemperatureUnit get temperature => _temperature;
  WindSpeedUnit get wind => _wind;
  PrecipitationUnit get precipitation => _precipitation;

  WeatherUnits get units => WeatherUnits(
        temperature: _temperature,
        wind: _wind,
        precipitation: _precipitation,
      );

  /// Loads persisted settings (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _temperature = TemperatureUnit.values.asNameMap()[sp.getString(_kTemperature)] ??
          TemperatureUnit.celsius;
      _wind = WindSpeedUnit.values.asNameMap()[sp.getString(_kWind)] ??
          WindSpeedUnit.kmh;
      _precipitation =
          PrecipitationUnit.values.asNameMap()[sp.getString(_kPrecipitation)] ??
              PrecipitationUnit.mm;
    } catch (_) {
      // Best-effort; leave defaults.
    }
    _loaded = true;
  }

  Future<void> setTemperature(TemperatureUnit unit) async {
    if (unit == _temperature) return;
    _temperature = unit;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kTemperature, unit.name);
    } catch (_) {}
  }

  Future<void> setWind(WindSpeedUnit unit) async {
    if (unit == _wind) return;
    _wind = unit;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kWind, unit.name);
    } catch (_) {}
  }

  Future<void> setPrecipitation(PrecipitationUnit unit) async {
    if (unit == _precipitation) return;
    _precipitation = unit;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kPrecipitation, unit.name);
    } catch (_) {}
  }
}
