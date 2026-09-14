import 'dart:convert';

import 'package:http/http.dart' as http;

// ── Overview ──────────────────────────────────────────────────────────────────
//
// This file holds the *unified weather model*: every vendor adapter
// (weather_providers.dart) translates its vendor payload into the classes
// below, so the UI never sees vendor types, vendor units or vendor quirks.
//
// Unit contract: all numeric values in [WeatherCurrent]/[WeatherHour]/
// [WeatherDay] are expressed in the units that were *requested* for the
// fetch (see `WeatherUnits` in weather_units.dart). Adapters convert
// vendor-native units into the requested ones before returning, so the UI
// can label values with the user's chosen units.
//
// Time contract: series times are parsed from the provider's own timestamps
// and represent the forecast location's local wall-clock time (Open-Meteo
// with `timezone=auto`). They are displayed as-is and never compared to the
// device clock. [WeatherData.currentTime] carries the provider's own
// "current time" string for the same location, used to place the "now"
// marker on charts.
//
// Security / privacy notes:
//  * Adapters only ever contact fixed, compile-time-constant hosts over
//    HTTPS (see weather_providers.dart / geocoding_service.dart). No
//    user- or flight-supplied host is ever contacted, so this cannot be
//    steered at an internal/metadata endpoint (no SSRF surface).
//  * API keys (when a keyed provider is selected) are user secrets entered
//    at runtime — never hard-coded or bundled.

/// Why a weather fetch failed — drives the error message in the UI.
enum WeatherError { network, badResponse, unauthorized }

class WeatherException implements Exception {
  const WeatherException(this.error);
  final WeatherError error;
}

// ── Parse helpers ─────────────────────────────────────────────────────────────

/// Shared coercion helpers for vendor JSON payloads. Values may arrive as
/// int, double, string or null depending on vendor and field; every helper
/// degrades to `null` / a fallback instead of throwing so a single odd
/// column never kills the whole forecast.
class WxParse {
  WxParse._();

  /// Numeric coercion. Some vendors (wttr.in j1) deliver every value as a
  /// string; Open-Meteo/OpenWeatherMap deliver numbers. Accepts both — and
  /// null / garbage degrades to the fallback instead of throwing.
  static double d(Object? v, [double fallback = 0]) =>
      dOrNull(v) ?? fallback;

  /// Nullable variant: null (or non-numeric) stays null — used for the
  /// extended metric fields that not every provider supplies.
  static double? dOrNull(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static int? i(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      if (parsed != null) return parsed;
      final dbl = double.tryParse(v.trim());
      if (dbl != null) return dbl.round();
    }
    return null;
  }

  static String s(Object? v) => v?.toString() ?? '';

  /// Vendor epoch is seconds since the Unix epoch (OpenWeatherMap,
  /// WeatherAPI.com); returns local-wall-clock-independent DateTime (UTC).
  static DateTime? epoch(Object? v) =>
      v is num && v > 0
          ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000)
          : null;

  static Map<String, dynamic> mapOf(Map<String, dynamic> j, String key) =>
      (j[key] is Map ? j[key] as Map : const {}).cast<String, dynamic>();

  static List<Object?> listOf(Map<String, dynamic> j, String key) =>
      j[key] is List ? (j[key] as List) : const [];

  /// Builds a column map (each field is a list) into a row at index [i].
  static Map<String, Object?> mapAt(Map<String, dynamic> m, int i) {
    final row = <String, Object?>{};
    m.forEach((k, v) {
      if (v is List && v.length > i) row[k] = v[i];
    });
    return row;
  }

  /// Compacts a JSON body to a `Map<String, dynamic>` or throws.
  static Map<String, dynamic> decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const WeatherException(WeatherError.badResponse);
  }
}

// ── Weather kinds ─────────────────────────────────────────────────────────────

/// Broad weather condition groups. The UI renders each group with a Material
/// icon and a localized description.
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
WeatherKind weatherKindFromWmo(int code) {
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

/// Legacy alias for [weatherKindFromWmo] (Open-Meteo uses WMO codes).
WeatherKind weatherKindFromCode(int code) => weatherKindFromWmo(code);

/// Maps an OpenWeatherMap condition id to a [WeatherKind].
WeatherKind weatherKindFromOwmId(int id) {
  if (id >= 200 && id < 300) return WeatherKind.thunder;
  if (id >= 300 && id < 400) return WeatherKind.drizzle;
  switch (id) {
    case 500 || 501:
      return WeatherKind.rain;
    case 502 || 503 || 504:
      return WeatherKind.showers;
    case 511:
      return WeatherKind.freezing;
    case 520 || 521 || 522 || 531:
      return WeatherKind.showers;
  }
  if (id >= 600 && id < 700) return WeatherKind.snow;
  if (id >= 700 && id < 800) return WeatherKind.fog;
  if (id == 800) return WeatherKind.clear;
  if (id == 801 || id == 802) return WeatherKind.partlyCloudy;
  if (id == 803 || id == 804) return WeatherKind.overcast;
  return WeatherKind.unknown;
}

/// Maps a WeatherAPI.com condition code to a [WeatherKind].
WeatherKind weatherKindFromWapiCode(int code) {
  switch (code) {
    case 1000:
      return WeatherKind.clear;
    case 1003:
      return WeatherKind.mainlyClear;
    case 1006 || 1009:
      return WeatherKind.overcast;
    case 1030 || 1135 || 1147:
      return WeatherKind.fog;
    case 1063 || 1150 || 1153 || 1168 || 1171 || 1180 || 1183:
      return WeatherKind.drizzle;
    case 1186 || 1189 || 1192 || 1195 || 1240 || 1243 || 1246:
      return WeatherKind.rain;
    case 1069 || 1072 || 1198 || 1201 || 1237 || 1249 || 1252:
      return WeatherKind.freezing;
    case 1114 || 1117 || 1210 || 1213 || 1216 || 1219 || 1222 || 1225 ||
        1255 || 1258 || 1261 || 1262:
      return WeatherKind.snow;
    case 1087 || 1273 || 1276 || 1279 || 1282:
      return WeatherKind.thunder;
    default:
      return WeatherKind.unknown;
  }
}

/// Maps a WWO (wttr.in) weather code to a [WeatherKind].
WeatherKind weatherKindFromWwoCode(int code) {
  switch (code) {
    case 113:
      return WeatherKind.clear;
    case 116:
      return WeatherKind.partlyCloudy;
    case 119 || 122:
      return WeatherKind.overcast;
    case 143 || 248 || 260:
      return WeatherKind.fog;
    case 176 || 263 || 266 || 281 || 284 || 293 || 296:
      return WeatherKind.drizzle;
    case 299 || 302 || 305 || 308:
      return WeatherKind.rain;
    case 182 || 185 || 311 || 314 || 317 || 320 || 350 || 362 || 365 ||
        374 || 377 || 392 || 395:
      return WeatherKind.freezing;
    case 179 || 323 || 326 || 329 || 332 || 335 || 338 || 368 || 371:
      return WeatherKind.snow;
    case 227 || 230:
      return WeatherKind.showers;
    case 200 || 386 || 389:
      return WeatherKind.thunder;
    default:
      return WeatherKind.unknown;
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

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

  /// Unit-conversion helper: returns a copy with the supplied fields
  /// replaced (all in one unit system; see WeatherUnits).
  WeatherCurrent copyWith({
    double? temperature,
    double? apparentTemperature,
    double? precipitation,
    double? windSpeed,
    double? windGusts,
  }) {
    return WeatherCurrent(
      temperature: temperature ?? this.temperature,
      apparentTemperature: apparentTemperature ?? this.apparentTemperature,
      humidity: humidity,
      precipitation: precipitation ?? this.precipitation,
      cloudCover: cloudCover,
      pressure: pressure,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection,
      windGusts: windGusts ?? this.windGusts,
      isDay: isDay,
      kind: kind,
    );
  }
}

/// One hourly forecast slot.
///
/// The base fields are always populated (adapters guarantee them). The
/// extended fields are nullable: they carry the "full parameter set" from
/// Open-Meteo (temperature/humidity/cloud layers/visibility/upper winds/
/// soil/radiation/CAPE …) and stay null for providers that do not supply
/// them (OpenWeatherMap, WeatherAPI.com, wttr.in).
class WeatherHour {
  final DateTime time;

  // Base fields (every adapter).
  final double temperature;
  final double precipProbability;
  final double precipitation;
  final double windSpeed;
  final double windDirection;
  final double windGusts;
  final WeatherKind kind;

  // Extended fields (Open-Meteo full parameter set; null elsewhere).
  final double? apparentTemperature;
  final double? relativeHumidity;
  final double? rain;
  final double? snowfall;
  final double? cloudCover;
  final double? cloudLow;
  final double? cloudMid;
  final double? cloudHigh;
  final double? visibility; // meters
  final double? windSpeed80m;
  final double? windSpeed120m;
  final double? soilTemperature;
  final double? shortwaveRadiation;
  final double? soilMoisture; // m³/m³
  final double? et0; // FAO reference evapotranspiration, mm/h
  final double? cape; // Convective Available Potential Energy, J/kg
  final bool? isDay;

  const WeatherHour({
    required this.time,
    required this.temperature,
    required this.precipProbability,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.kind,
    this.apparentTemperature,
    this.relativeHumidity,
    this.rain,
    this.snowfall,
    this.cloudCover,
    this.cloudLow,
    this.cloudMid,
    this.cloudHigh,
    this.visibility,
    this.windSpeed80m,
    this.windSpeed120m,
    this.soilTemperature,
    this.shortwaveRadiation,
    this.soilMoisture,
    this.et0,
    this.cape,
    this.isDay,
  });

  /// Unit-conversion helper: returns a copy with the supplied fields
  /// replaced. Only convertible fields are exposed (percentages,
  /// visibility, radiation, moisture and CAPE are unit-independent).
  WeatherHour copyWith({
    double? temperature,
    double? apparentTemperature,
    double? precipitation,
    double? rain,
    double? snowfall,
    double? windSpeed,
    double? windGusts,
    double? windSpeed80m,
    double? windSpeed120m,
    double? soilTemperature,
    double? et0,
  }) {
    return WeatherHour(
      time: time,
      temperature: temperature ?? this.temperature,
      precipProbability: precipProbability,
      precipitation: precipitation ?? this.precipitation,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection,
      windGusts: windGusts ?? this.windGusts,
      kind: kind,
      apparentTemperature: apparentTemperature ?? this.apparentTemperature,
      relativeHumidity: relativeHumidity,
      rain: rain ?? this.rain,
      snowfall: snowfall ?? this.snowfall,
      cloudCover: cloudCover,
      cloudLow: cloudLow,
      cloudMid: cloudMid,
      cloudHigh: cloudHigh,
      visibility: visibility,
      windSpeed80m: windSpeed80m ?? this.windSpeed80m,
      windSpeed120m: windSpeed120m ?? this.windSpeed120m,
      soilTemperature: soilTemperature ?? this.soilTemperature,
      shortwaveRadiation: shortwaveRadiation,
      soilMoisture: soilMoisture,
      et0: et0 ?? this.et0,
      cape: cape,
      isDay: isDay,
    );
  }
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

  /// Location-local sunrise/sunset instants (nullable for providers that
  /// do not supply them — wttr.in, OpenWeatherMap when absent).
  final DateTime? sunrise;
  final DateTime? sunset;

  final double? snowfallSum;

  const WeatherDay({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.precipSum,
    required this.precipProbability,
    required this.windMax,
    required this.windGustsMax,
    required this.windDirectionDominant,
    this.kind = WeatherKind.unknown,
    this.sunrise,
    this.sunset,
    this.snowfallSum,
  });

  /// Unit-conversion helper: returns a copy with the supplied fields
  /// replaced.
  WeatherDay copyWith({
    double? tMax,
    double? tMin,
    double? precipSum,
    double? snowfallSum,
    double? windMax,
    double? windGustsMax,
  }) {
    return WeatherDay(
      date: date,
      tMax: tMax ?? this.tMax,
      tMin: tMin ?? this.tMin,
      precipSum: precipSum ?? this.precipSum,
      precipProbability: precipProbability,
      windMax: windMax ?? this.windMax,
      windGustsMax: windGustsMax ?? this.windGustsMax,
      windDirectionDominant: windDirectionDominant,
      kind: kind,
      sunrise: sunrise,
      sunset: sunset,
      snowfallSum: snowfallSum ?? this.snowfallSum,
    );
  }
}

/// The complete unified forecast response for one location, regardless of
/// which vendor adapter produced it.
class WeatherData {
  final WeatherCurrent current;
  final List<WeatherHour> hourly;
  final List<WeatherDay> daily;

  /// Human-readable label of the provider that actually served this data
  /// (stamped by the manager for attribution), null for raw parses.
  final String? source;

  /// True when the user's selected provider failed and a fallback served
  /// the data instead.
  final bool servedByFallback;

  /// IANA timezone of the forecast location (e.g. "Europe/Paris"), as
  /// reported by Open-Meteo with `timezone=auto`.
  final String? timezone;

  /// UTC offset of the forecast location in seconds.
  final int? utcOffsetSeconds;

  /// The provider's own "current time" at the forecast location
  /// (location-local wall clock). Used to place the "now" marker on charts.
  final DateTime? currentTime;

  const WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
    this.source,
    this.servedByFallback = false,
    this.timezone,
    this.utcOffsetSeconds,
    this.currentTime,
  });
}

// ── Legacy service (superseded by weather_providers.dart + manager) ──────────
//
// Retained only as a thin convenience wrapper so existing callers keep
// working: it fetches the basic parameter set from Open-Meteo through the
// same unified model. The full-featured path is
// `WeatherServiceManager.instance.fetch(...)`.

/// Minimal Open-Meteo forecast fetch (no API key required). See the class
/// doc in weather_providers.dart for the security notes shared by every
/// weather HTTP call.
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
      return OpenMeteoBasicParse.fromForecastJson(
        WxParse.decodeBody(resp.body),
      );
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(WeatherError.badResponse);
    }
  }
}

/// Basic-shape Open-Meteo parser used by the legacy [WeatherService] above.
/// The full-parameter parser lives in [OpenMeteoProvider] (weather_providers.dart).
class OpenMeteoBasicParse {
  OpenMeteoBasicParse._();

  static WeatherData fromForecastJson(Map<String, dynamic> j) {
    final cur = WxParse.mapOf(j, 'current');
    final current = WeatherCurrent(
      temperature: WxParse.d(cur['temperature_2m']),
      apparentTemperature: WxParse.d(cur['apparent_temperature']),
      humidity: WxParse.d(cur['relative_humidity_2m']),
      precipitation: WxParse.d(cur['precipitation']),
      cloudCover: WxParse.d(cur['cloud_cover']),
      pressure: WxParse.d(cur['surface_pressure']),
      windSpeed: WxParse.d(cur['wind_speed_10m']),
      windDirection: WxParse.d(cur['wind_direction_10m']),
      windGusts: WxParse.d(cur['wind_gusts_10m']),
      isDay: WxParse.i(cur['is_day']) != 0,
      kind: weatherKindFromWmo(WxParse.i(cur['weather_code']) ?? -1),
    );

    // With `forecast_hours` the series starts at the current hour in the
    // location's timezone — display as-is, never compare to the device clock.
    final hourlyRaw = WxParse.mapOf(j, 'hourly');
    final times = WxParse.listOf(hourlyRaw, 'time');
    final hourly = <WeatherHour>[];
    for (var i = 0; i < times.length && hourly.length < 24; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      final s = WxParse.mapAt(hourlyRaw, i);
      hourly.add(WeatherHour(
        time: t,
        temperature: WxParse.d(s['temperature_2m']),
        precipProbability: WxParse.d(s['precipitation_probability']),
        precipitation: WxParse.d(s['precipitation']),
        windSpeed: WxParse.d(s['wind_speed_10m']),
        windDirection: WxParse.d(s['wind_direction_10m']),
        windGusts: WxParse.d(s['wind_gusts_10m']),
        kind: weatherKindFromWmo(WxParse.i(s['weather_code']) ?? -1),
      ));
    }

    final dailyRaw = WxParse.mapOf(j, 'daily');
    final dayTimes = WxParse.listOf(dailyRaw, 'time');
    final daily = <WeatherDay>[];
    for (var i = 0; i < dayTimes.length; i++) {
      final d = DateTime.tryParse('${dayTimes[i]}');
      if (d == null) continue;
      final s = WxParse.mapAt(dailyRaw, i);
      daily.add(WeatherDay(
        date: d,
        tMax: WxParse.d(s['temperature_2m_max']),
        tMin: WxParse.d(s['temperature_2m_min']),
        precipSum: WxParse.d(s['precipitation_sum']),
        precipProbability: WxParse.d(s['precipitation_probability_max']),
        windMax: WxParse.d(s['wind_speed_10m_max']),
        windGustsMax: WxParse.d(s['wind_gusts_10m_max']),
        windDirectionDominant: WxParse.d(s['wind_direction_10m_dominant']),
        kind: weatherKindFromWmo(WxParse.i(s['weather_code']) ?? -1),
      ));
    }

    return WeatherData(current: current, hourly: hourly, daily: daily);
  }
}
