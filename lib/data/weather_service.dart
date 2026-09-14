import 'dart:convert';

import 'package:http/http.dart' as http;

/// Weather forecast for the pilot's location via the free Open-Meteo service
/// (no API key required).
///
/// Security / privacy notes:
///  * No API key exists at all, so there is no secret to hard-code or leak.
///  * Requests only ever go to the single fixed host `api.open-meteo.com` over
///    HTTPS. No user- or flight-supplied host is ever contacted, so this cannot
///    be steered at an internal/metadata endpoint (no SSRF surface).
///  * Only the current coordinates (4-decimal precision, ~11 km) are sent;
///    no other flight data leaves the device.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  /// The ONLY host this service will ever contact.
  static const String _host = 'api.open-meteo.com';
  static const String _path = '/v1/forecast';

  final http.Client _client = http.Client();

  /// Fetches current conditions, the next [hours] hourly slots and [days]
  /// daily summaries for [lat]/[lon]. Throws [WeatherException] on failure so
  /// the caller can distinguish "no fix" from "network error".
  Future<WeatherData> fetch({
    required double lat,
    required double lon,
    int hours = 24,
    int days = 5,
  }) async {
    final uri = Uri.https(_host, _path, {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,is_day,'
              'precipitation,weather_code,cloud_cover,surface_pressure,'
              'wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'hourly':
          'temperature_2m,precipitation_probability,precipitation,weather_code,'
              'wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,'
              'precipitation_probability_max,wind_speed_10m_max,'
              'wind_gusts_10m_max,wind_direction_10m_dominant',
      'timezone': 'auto',
      'forecast_hours': '$hours',
      'forecast_days': '$days',
      'wind_speed_unit': 'kmh',
    });
    // Defense-in-depth: the URI host is built from a constant, but assert it
    // anyway so a future refactor can't accidentally point elsewhere.
    assert(uri.host == _host);

    final http.Response resp;
    try {
      resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const WeatherException(WeatherError.network);
    }
    if (resp.statusCode != 200) {
      throw const WeatherException(WeatherError.network);
    }

    try {
      return WeatherData.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const WeatherException(WeatherError.badResponse);
    }
  }
}

/// Why a weather fetch failed — drives the error message in the UI.
enum WeatherError { network, badResponse }

class WeatherException implements Exception {
  const WeatherException(this.error);
  final WeatherError error;
}

// ── Model ─────────────────────────────────────────────────────────────────────

/// One forecast point (current, hourly slot or daily summary).
class _Parse {
  /// [num] fields arrive as int or double depending on the value; normalize.
  static double d(Object? v, [double fallback = 0]) =>
      v is num ? v.toDouble() : fallback;

  static int? i(Object? v) => v is int ? v : (v is num ? v.round() : null);
}

/// Broad weather condition groups mapped from the WMO weather codes. The UI
/// renders each group with a Material icon and a localized description.
enum WeatherKind {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  freezing,
  snow,
  showers,
  thunder,
  unknown,
}

/// Maps an Open-Meteo WMO weather code to a [WeatherKind].
WeatherKind weatherKindFromCode(int code) {
  switch (code) {
    case 0:
      return WeatherKind.clear;
    case 1:
      return WeatherKind.mainlyClear;
    case 2:
      return WeatherKind.partlyCloudy;
    case 3:
      return WeatherKind.overcast;
    case 45 || 48:
      return WeatherKind.fog;
    case 51 || 53 || 55 || 56 || 57:
      return WeatherKind.drizzle;
    case 61 || 63 || 65 || 66 || 67:
      return WeatherKind.rain;
    case 71 || 73 || 75 || 77:
      return WeatherKind.snow;
    case 80 || 81 || 82:
      return WeatherKind.showers;
    case 85 || 86:
      return WeatherKind.snow;
    case 95 || 96 || 99:
      return WeatherKind.thunder;
    default:
      return WeatherKind.unknown;
  }
}

/// Current conditions at the location.
class WeatherCurrent {
  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double precipitation;
  final double cloudCover;
  final double pressure;
  final double windSpeed;
  final double windDirection;
  final double windGusts;
  final bool isDay;
  final WeatherKind kind;

  const WeatherCurrent({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.cloudCover,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.isDay,
    required this.kind,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> j) {
    return WeatherCurrent(
      temperature: _Parse.d(j['temperature_2m']),
      apparentTemperature: _Parse.d(j['apparent_temperature']),
      humidity: _Parse.d(j['relative_humidity_2m']),
      precipitation: _Parse.d(j['precipitation']),
      cloudCover: _Parse.d(j['cloud_cover']),
      pressure: _Parse.d(j['surface_pressure']),
      windSpeed: _Parse.d(j['wind_speed_10m']),
      windDirection: _Parse.d(j['wind_direction_10m']),
      windGusts: _Parse.d(j['wind_gusts_10m']),
      isDay: _Parse.i(j['is_day']) != 0,
      kind: weatherKindFromCode(_Parse.i(j['weather_code']) ?? -1),
    );
  }
}

/// One hourly forecast slot.
class WeatherHour {
  final DateTime time;
  final double temperature;
  final double precipProbability;
  final double precipitation;
  final double windSpeed;
  final double windDirection;
  final double windGusts;
  final WeatherKind kind;

  const WeatherHour({
    required this.time,
    required this.temperature,
    required this.precipProbability,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.kind,
  });
}

/// One daily forecast summary.
class WeatherDay {
  final DateTime date;
  final double tMax;
  final double tMin;
  final double precipSum;
  final double precipProbability;
  final double windMax;
  final double windGustsMax;
  final double windDirectionDominant;
  final WeatherKind kind;

  const WeatherDay({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.precipSum,
    required this.precipProbability,
    required this.windMax,
    required this.windGustsMax,
    required this.windDirectionDominant,
    required this.kind,
  });
}

/// The complete forecast response for one location.
class WeatherData {
  final WeatherCurrent current;
  final List<WeatherHour> hourly;
  final List<WeatherDay> daily;

  const WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  factory WeatherData.fromJson(Map<String, dynamic> j) {
    final current =
        WeatherCurrent.fromJson((j['current'] as Map).cast<String, dynamic>());

    // Hourly slots. With `forecast_hours` the series starts at the current
    // hour *in the location's timezone*, so it is displayed as-is and the
    // first slot is labeled "Now" — never compare these times to the device's
    // local clock (they live in the forecast location's timezone).
    final hourlyRaw = _mapOf(j, 'hourly');
    final times = _listOf(hourlyRaw, 'time');
    final List<WeatherHour> hourly = [];
    for (var i = 0; i < times.length && hourly.length < 24; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      final slot = _mapAt(hourlyRaw, i);
      hourly.add(WeatherHour(
        time: t,
        temperature: _Parse.d(slot['temperature_2m']),
        precipProbability: _Parse.d(slot['precipitation_probability']),
        precipitation: _Parse.d(slot['precipitation']),
        windSpeed: _Parse.d(slot['wind_speed_10m']),
        windDirection: _Parse.d(slot['wind_direction_10m']),
        windGusts: _Parse.d(slot['wind_gusts_10m']),
        kind: weatherKindFromCode(_Parse.i(slot['weather_code']) ?? -1),
      ));
    }

    // Daily summaries.
    final dailyRaw = _mapOf(j, 'daily');
    final dayTimes = _listOf(dailyRaw, 'time');
    final List<WeatherDay> daily = [];
    for (var i = 0; i < dayTimes.length; i++) {
      final d = DateTime.tryParse('${dayTimes[i]}');
      if (d == null) continue;
      final slot = _mapAt(dailyRaw, i);
      daily.add(WeatherDay(
        date: d,
        tMax: _Parse.d(slot['temperature_2m_max']),
        tMin: _Parse.d(slot['temperature_2m_min']),
        precipSum: _Parse.d(slot['precipitation_sum']),
        precipProbability: _Parse.d(slot['precipitation_probability_max']),
        windMax: _Parse.d(slot['wind_speed_10m_max']),
        windGustsMax: _Parse.d(slot['wind_gusts_10m_max']),
        windDirectionDominant: _Parse.d(slot['wind_direction_10m_dominant']),
        kind: weatherKindFromCode(_Parse.i(slot['weather_code']) ?? -1),
      ));
    }

    return WeatherData(current: current, hourly: hourly, daily: daily);
  }

  static Map<String, dynamic> _mapOf(Map<String, dynamic> j, String key) =>
      (j[key] is Map ? j[key] as Map : const {}).cast<String, dynamic>();

  static List<Object?> _listOf(Map<String, dynamic> j, String key) =>
      j[key] is List ? (j[key] as List) : const [];

  /// Builds a column map (each field is a list) into a row at index [i].
  static Map<String, Object?> _mapAt(Map<String, dynamic> m, int i) {
    final row = <String, Object?>{};
    m.forEach((k, v) {
      if (v is List && v.length > i) row[k] = v[i];
    });
    return row;
  }
}
