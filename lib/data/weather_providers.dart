import 'package:http/http.dart' as http;

import 'weather_service.dart';
import 'weather_units.dart';

// ── Provider contract (strategy pattern) ─────────────────────────────────────

/// The supported weather sources.
enum WeatherProviderId {
  /// Open-Meteo — free, no key. Default and primary fallback.
  openMeteo,

  /// OpenWeatherMap One Call 3.0 — requires a key.
  openWeatherMap,

  /// WeatherAPI.com forecast.json — requires a key.
  weatherApi,

  /// wttr.in JSON (j1) — free, no key. Secondary fallback.
  wttr,
}

/// Forecast model selector for Open-Meteo's `models` parameter. Only a
/// single model can be active at a time (multi-model requests return
/// nested arrays and a different payload shape); "best match" is the
/// provider's own default blend and requests no `models` parameter.
enum WeatherModel {
  bestMatch('best_match', 'Best match'),
  ecmwfIfs025('ecmwf_ifs025', 'ECMWF IFS 0.25°'),
  gfsSeamless('gfs_seamless', 'GFS Seamless'),
  cmaRaeForecast('cma_rae_forecast', 'CMA RAE');

  const WeatherModel(this.apiValue, this.label);

  /// Value for the Open-Meteo `models` parameter.
  final String apiValue;

  /// Label shown in the model picker.
  final String label;
}

/// Everything one provider request needs. [apiKey] is null when the provider
/// needs none (or the user hasn't configured one). [units] drives the
/// requested/displayed unit system; [pastDays] (Open-Meteo only, up to 92)
/// extends the hourly series into the past; [forecastDays] caps the forward
/// horizon (Open-Meteo supports up to 16).
class WeatherFetchRequest {
  final double lat;
  final double lon;
  final String? apiKey;
  final WeatherUnits units;
  final int pastDays;
  final int forecastDays;
  final WeatherModel model;

  const WeatherFetchRequest({
    required this.lat,
    required this.lon,
    this.apiKey,
    this.units = WeatherUnits.metric,
    this.pastDays = 0,
    this.forecastDays = 7,
    this.model = WeatherModel.bestMatch,
  });
}

/// One vendor adapter: translates the vendor's API layout into the unified
/// [WeatherData] model. Adapters never expose vendor types or units — all
/// conversions (m/s → requested unit, °F → requested unit, probability → %,
/// …) happen here, so the UI always receives values in the units that were
/// requested for the fetch.
abstract class WeatherProvider {
  WeatherProviderId get id;

  /// Brand name shown in the UI (same in every locale).
  String get label;

  /// Attribution line shown in the weather sheet footer.
  String get credit;

  /// Whether this provider cannot work without a user-supplied API key.
  bool get requiresKey;

  /// Fetches the unified forecast. Throws [WeatherException] on any failure
  /// (network, bad payload, rejected key) so the manager can fail over.
  Future<WeatherData> fetch(WeatherFetchRequest request);
}

/// Shared HTTP plumbing for all adapters: fixed-host HTTPS GET with a timeout
/// and status → [WeatherError] mapping. Hosts are compile-time constants, so
/// no adapter can ever be steered at an internal endpoint (no SSRF surface).
class WeatherHttp {
  final http.Client _client = http.Client();

  /// GETs [uri] (host must be a compile-time constant) and decodes the JSON
  /// body. Throws [WeatherException] on transport/status/parse failure.
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    assert(uri.scheme == 'https', 'Weather providers must use HTTPS');
    final http.Response resp;
    try {
      resp = await _client.get(uri).timeout(timeout);
    } catch (_) {
      throw const WeatherException(WeatherError.network);
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const WeatherException(WeatherError.unauthorized);
    }
    if (resp.statusCode != 200) {
      throw const WeatherException(WeatherError.network);
    }
    try {
      return WxParse.decodeBody(resp.body);
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(WeatherError.badResponse);
    }
  }
}

// ── Unit application (keyed / fallback vendors) ──────────────────────────────

/// Converts canonical-metric values (°C, km/h, mm — what the keyed and
/// fallback vendors natively return after their metric parse) into the
/// units the user requested. Open-Meteo is exempt: it applies the units
/// server-side, so its parse is already in requested units.
WeatherData toRequestedUnits(WeatherData data, WeatherUnits units) {
  final temp = units.temperature;
  final wind = units.wind;
  final precip = units.precipitation;
  if (temp == TemperatureUnit.celsius &&
      wind == WindSpeedUnit.kmh &&
      precip == PrecipitationUnit.mm) {
    return data;
  }
  double t(double c) =>
      WeatherUnits.convertTemperature(c, TemperatureUnit.celsius, temp);
  double? tn(double? c) => c == null ? null : t(c);
  double w(double kmh) => WeatherUnits.convertWindFromKmh(kmh, wind);
  double? wn(double? kmh) => kmh == null ? null : w(kmh);
  double p(double mm) => WeatherUnits.convertPrecipFromMm(mm, precip);
  double? pn(double? mm) => mm == null ? null : p(mm);

  return WeatherData(
    current: data.current.copyWith(
      temperature: t(data.current.temperature),
      apparentTemperature: t(data.current.apparentTemperature),
      precipitation: p(data.current.precipitation),
      windSpeed: w(data.current.windSpeed),
      windGusts: w(data.current.windGusts),
    ),
    hourly: [
      for (final h in data.hourly)
        h.copyWith(
          temperature: t(h.temperature),
          apparentTemperature: tn(h.apparentTemperature),
          precipitation: p(h.precipitation),
          rain: pn(h.rain),
          snowfall: pn(h.snowfall),
          windSpeed: w(h.windSpeed),
          windGusts: w(h.windGusts),
          windSpeed80m: wn(h.windSpeed80m),
          windSpeed120m: wn(h.windSpeed120m),
          soilTemperature: tn(h.soilTemperature),
          et0: pn(h.et0),
        ),
    ],
    daily: [
      for (final d in data.daily)
        d.copyWith(
          tMax: t(d.tMax),
          tMin: t(d.tMin),
          precipSum: p(d.precipSum),
          snowfallSum: pn(d.snowfallSum),
          windMax: w(d.windMax),
          windGustsMax: w(d.windGustsMax),
        ),
    ],
    source: data.source,
    servedByFallback: data.servedByFallback,
    timezone: data.timezone,
    utcOffsetSeconds: data.utcOffsetSeconds,
    currentTime: data.currentTime,
  );
}

// ── 1) Open-Meteo (default / fallback, no key) ───────────────────────────────

/// Forecast from api.open-meteo.com/v1/forecast. This is the full-featured
/// adapter: one request pulls the complete parameter set (temperature,
/// apparent temp, humidity, precipitation probability/rain/snowfall, cloud
/// layers, visibility, winds at 10/80/120 m, gusts, soil temperature,
/// shortwave radiation, soil moisture, ET0, CAPE), the daily summary with
/// sunrise/sunset, up to 92 days of history (`past_days`), a model
/// selection (`models`) and the user's unit preferences
/// (`temperature_unit` / `wind_speed_unit` / `precipitation_unit`).
///
/// Times are returned in the location's timezone (`timezone=auto`) and
/// displayed as-is; values already come in the requested units.
class OpenMeteoProvider extends WeatherProvider {
  /// The ONLY host this adapter will ever contact.
  static const String _host = 'api.open-meteo.com';

  /// Open-Meteo's supported `past_days` ceiling.
  static const int maxPastDays = 92;

  /// Open-Meteo's supported `forecast_days` ceiling.
  static const int maxForecastDays = 16;

  /// Full hourly parameter list — the "single, complex request" that feeds
  /// every panel of the weather screen.
  static const String _hourlyParams =
      'temperature_2m,apparent_temperature,relative_humidity_2m,'
      'precipitation_probability,precipitation,rain,snowfall,weather_code,'
      'cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,'
      'visibility,'
      'wind_speed_10m,wind_direction_10m,wind_gusts_10m,'
      'wind_speed_80m,wind_speed_120m,'
      'soil_temperature_0cm,shortwave_radiation,soil_moisture_0_to_1cm,'
      'et0_fao_evapotranspiration,cape,is_day';

  static const String _dailyParams =
      'weather_code,temperature_2m_max,temperature_2m_min,'
      'precipitation_sum,snowfall_sum,precipitation_probability_max,'
      'wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,'
      'sunrise,sunset';

  static const String _currentParams =
      'temperature_2m,apparent_temperature,relative_humidity_2m,is_day,'
      'precipitation,rain,weather_code,cloud_cover,surface_pressure,'
      'wind_speed_10m,wind_direction_10m,wind_gusts_10m';

  final WeatherHttp _http = WeatherHttp();

  @override
  WeatherProviderId get id => WeatherProviderId.openMeteo;

  @override
  String get label => 'Open-Meteo';

  @override
  String get credit => 'Data by Open-Meteo';

  @override
  bool get requiresKey => false;

  @override
  Future<WeatherData> fetch(WeatherFetchRequest request) async {
    return parse(await _http.getJson(buildUri(request)));
  }

  /// Builds the single, complex request URL — exposed separately so tests
  /// can assert the exact parameter set (past_days, models, units) without
  /// touching the network.
  static Uri buildUri(WeatherFetchRequest request) {
    final units = request.units;
    final model = request.model;
    final uri = Uri.https(_host, '/v1/forecast', {
      'latitude': request.lat.toStringAsFixed(4),
      'longitude': request.lon.toStringAsFixed(4),
      'current': _currentParams,
      'hourly': _hourlyParams,
      'daily': _dailyParams,
      'timezone': 'auto',
      'forecast_days':
          '${request.forecastDays.clamp(1, maxForecastDays)}',
      if (request.pastDays > 0)
        'past_days': '${request.pastDays.clamp(0, maxPastDays)}',
      // `best_match` is the API default; request `models` only for a real
      // model toggle so the payload shape stays the simple column layout.
      if (model != WeatherModel.bestMatch) 'models': model.apiValue,
      'temperature_unit': units.temperature.apiValue,
      'wind_speed_unit': units.wind.apiValue,
      'precipitation_unit': units.precipitation.apiValue,
    });
    assert(uri.host == _host);
    return uri;
  }

  /// Column-oriented Open-Meteo payload → [WeatherData]. The extended
  /// metric fields are parsed when present and stay null otherwise (some
  /// forecast models do not carry every variable). Hourly rows are NOT
  /// capped: with `past_days` the series legitimately spans history plus
  /// the 16-day horizon and the hourly detail table scrolls through it.
  static WeatherData parse(Map<String, dynamic> j) {
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

    // The series starts at (today − past_days) 00:00 in the location's
    // timezone — display as-is, never compare to the device clock.
    final hourlyRaw = WxParse.mapOf(j, 'hourly');
    final times = WxParse.listOf(hourlyRaw, 'time');
    final hourly = <WeatherHour>[];
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      final s = WxParse.mapAt(hourlyRaw, i);
      final isDayFlag = WxParse.i(s['is_day']);
      hourly.add(WeatherHour(
        time: t,
        temperature: WxParse.d(s['temperature_2m']),
        precipProbability: WxParse.d(s['precipitation_probability']),
        precipitation: WxParse.d(s['precipitation']),
        windSpeed: WxParse.d(s['wind_speed_10m']),
        windDirection: WxParse.d(s['wind_direction_10m']),
        windGusts: WxParse.d(s['wind_gusts_10m']),
        kind: weatherKindFromWmo(WxParse.i(s['weather_code']) ?? -1),
        apparentTemperature: WxParse.dOrNull(s['apparent_temperature']),
        relativeHumidity: WxParse.dOrNull(s['relative_humidity_2m']),
        rain: WxParse.dOrNull(s['rain']),
        snowfall: WxParse.dOrNull(s['snowfall']),
        cloudCover: WxParse.dOrNull(s['cloud_cover']),
        cloudLow: WxParse.dOrNull(s['cloud_cover_low']),
        cloudMid: WxParse.dOrNull(s['cloud_cover_mid']),
        cloudHigh: WxParse.dOrNull(s['cloud_cover_high']),
        visibility: WxParse.dOrNull(s['visibility']),
        windSpeed80m: WxParse.dOrNull(s['wind_speed_80m']),
        windSpeed120m: WxParse.dOrNull(s['wind_speed_120m']),
        soilTemperature: WxParse.dOrNull(s['soil_temperature_0cm']),
        shortwaveRadiation: WxParse.dOrNull(s['shortwave_radiation']),
        soilMoisture: WxParse.dOrNull(s['soil_moisture_0_to_1cm']),
        et0: WxParse.dOrNull(s['et0_fao_evapotranspiration']),
        cape: WxParse.dOrNull(s['cape']),
        isDay: isDayFlag == null ? null : isDayFlag != 0,
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
        sunrise: DateTime.tryParse('${s['sunrise']}'),
        sunset: DateTime.tryParse('${s['sunset']}'),
        snowfallSum: WxParse.dOrNull(s['snowfall_sum']),
      ));
    }

    return WeatherData(
      current: current,
      hourly: hourly,
      daily: daily,
      // Extra response context: location timezone + the provider's own
      // "current time" (location-local wall clock) for the now-marker.
      timezone: '${j['timezone']}'.isEmpty ? null : '${j['timezone']}',
      utcOffsetSeconds: WxParse.i(j['utc_offset_seconds']),
      currentTime: DateTime.tryParse('${cur['time']}'),
    );
  }
}

// ── 2) OpenWeatherMap One Call 3.0 (key required) ────────────────────────────

/// One Call 3.0 from api.openweathermap.org. Units are requested as
/// `metric` (°C, m/s) and converted into canonical metric values here; the
/// user's requested units are then applied by [toRequestedUnits].
/// Timestamps are UTC epoch seconds rendered in the device's local time.
class OpenWeatherMapProvider extends WeatherProvider {
  /// The ONLY host this adapter will ever contact.
  static const String _host = 'api.openweathermap.org';

  final WeatherHttp _http = WeatherHttp();

  @override
  WeatherProviderId get id => WeatherProviderId.openWeatherMap;

  @override
  String get label => 'OpenWeatherMap';

  @override
  String get credit => 'Weather data by OpenWeatherMap';

  @override
  bool get requiresKey => true;

  @override
  Future<WeatherData> fetch(WeatherFetchRequest request) async {
    final key = request.apiKey;
    if (key == null || key.isEmpty) {
      // Unreachable via the manager (it skips keyless providers), but keep the
      // guard so direct misuse fails loudly instead of leaking a blank key.
      throw const WeatherException(WeatherError.unauthorized);
    }
    final uri = Uri.https(_host, '/data/3.0/onecall', {
      'lat': request.lat.toStringAsFixed(4),
      'lon': request.lon.toStringAsFixed(4),
      'appid': key,
      'units': 'metric',
      'exclude': 'minutely,alerts',
    });
    assert(uri.host == _host);
    final data = parse(await _http.getJson(uri));
    return toRequestedUnits(data, request.units);
  }

  /// One Call 3.0 payload → [WeatherData] (canonical metric units).
  static WeatherData parse(Map<String, dynamic> j) {
    final cur = WxParse.mapOf(j, 'current');
    final curWx = _firstWeather(cur);
    final dt = WxParse.epoch(cur['dt']);
    final sunrise = WxParse.epoch(cur['sunrise']);
    final sunset = WxParse.epoch(cur['sunset']);
    final current = WeatherCurrent(
      temperature: WxParse.d(cur['temp']),
      apparentTemperature: WxParse.d(cur['feels_like']),
      humidity: WxParse.d(cur['humidity']),
      precipitation: WxParse.d(cur['rain']?['1h']) + WxParse.d(cur['snow']?['1h']),
      cloudCover: WxParse.d(cur['clouds']),
      pressure: WxParse.d(cur['pressure']),
      windSpeed: WxParse.d(cur['wind_speed']) * 3.6, // m/s → km/h
      windDirection: WxParse.d(cur['wind_deg']),
      windGusts: WxParse.d(cur['wind_gust']) * 3.6, // m/s → km/h
      isDay: dt != null &&
          sunrise != null &&
          sunset != null &&
          !dt.isBefore(sunrise) &&
          dt.isBefore(sunset),
      kind: curWx == null
          ? WeatherKind.unknown
          : weatherKindFromOwmId(curWx),
    );

    final hourly = <WeatherHour>[];
    for (final raw in WxParse.listOf(j, 'hourly').take(48)) {
      if (raw is! Map) continue;
      final s = raw.cast<String, dynamic>();
      final t = WxParse.epoch(s['dt']);
      if (t == null) continue;
      final wx = _firstWeather(s);
      hourly.add(WeatherHour(
        time: t,
        temperature: WxParse.d(s['temp']),
        precipProbability: WxParse.d(s['pop']) * 100, // 0..1 → %
        precipitation:
            WxParse.d(s['rain']?['1h']) + WxParse.d(s['snow']?['1h']),
        windSpeed: WxParse.d(s['wind_speed']) * 3.6,
        windDirection: WxParse.d(s['wind_deg']),
        windGusts: WxParse.d(s['wind_gust']) * 3.6,
        kind: wx == null ? WeatherKind.unknown : weatherKindFromOwmId(wx),
      ));
    }

    final daily = <WeatherDay>[];
    for (final raw in WxParse.listOf(j, 'daily')) {
      if (raw is! Map) continue;
      final s = raw.cast<String, dynamic>();
      final d = WxParse.epoch(s['dt']);
      if (d == null) continue;
      final temp = WxParse.mapOf(s, 'temp');
      final wx = _firstWeather(s);
      daily.add(WeatherDay(
        date: d,
        tMax: WxParse.d(temp['max']),
        tMin: WxParse.d(temp['min']),
        precipSum: WxParse.d(s['rain']) + WxParse.d(s['snow']),
        precipProbability: WxParse.d(s['pop']) * 100,
        windMax: WxParse.d(s['wind_speed']) * 3.6,
        windGustsMax: WxParse.d(s['wind_gust']) * 3.6,
        windDirectionDominant: WxParse.d(s['wind_deg']),
        kind: wx == null ? WeatherKind.unknown : weatherKindFromOwmId(wx),
      ));
    }

    return WeatherData(current: current, hourly: hourly, daily: daily);
  }

  /// weather[0].id, or null when the weather array is missing/empty.
  static int? _firstWeather(Map<String, dynamic> s) {
    final list = WxParse.listOf(s, 'weather');
    if (list.isEmpty || list.first is! Map) return null;
    return WxParse.i((list.first as Map)['id']);
  }
}

// ── 3) WeatherAPI.com forecast.json (key required) ───────────────────────────

/// forecast.json from api.weatherapi.com. Response is metric by default
/// (°C, km/h — canonical already); hourly slots are epoch-based and
/// filtered to start at "now". Requested units applied by
/// [toRequestedUnits].
class WeatherApiComProvider extends WeatherProvider {
  /// The ONLY host this adapter will ever contact.
  static const String _host = 'api.weatherapi.com';

  final WeatherHttp _http = WeatherHttp();

  @override
  WeatherProviderId get id => WeatherProviderId.weatherApi;

  @override
  String get label => 'WeatherAPI.com';

  @override
  String get credit => 'Weather by WeatherAPI.com';

  @override
  bool get requiresKey => true;

  @override
  Future<WeatherData> fetch(WeatherFetchRequest request) async {
    final key = request.apiKey;
    if (key == null || key.isEmpty) {
      throw const WeatherException(WeatherError.unauthorized);
    }
    final uri = Uri.https(_host, '/v1/forecast.json', {
      'key': key,
      'q': '${request.lat.toStringAsFixed(4)},${request.lon.toStringAsFixed(4)}',
      'days': '5',
      'aqi': 'no',
      'alerts': 'no',
    });
    assert(uri.host == _host);
    final data = parse(await _http.getJson(uri));
    return toRequestedUnits(data, request.units);
  }

  /// forecast.json payload → [WeatherData]. Hourly slots at-or-after the
  /// current hour are kept (max 48).
  static WeatherData parse(Map<String, dynamic> j) {
    final cur = WxParse.mapOf(j, 'current');
    final curCond = _conditionCode(cur);
    final current = WeatherCurrent(
      temperature: WxParse.d(cur['temp_c']),
      apparentTemperature: WxParse.d(cur['feelslike_c']),
      humidity: WxParse.d(cur['humidity']),
      precipitation: WxParse.d(cur['precip_mm']),
      cloudCover: WxParse.d(cur['cloud']),
      pressure: WxParse.d(cur['pressure_mb']),
      windSpeed: WxParse.d(cur['wind_kph']),
      windDirection: WxParse.d(cur['wind_degree']),
      windGusts: WxParse.d(cur['gust_kph']),
      isDay: WxParse.i(cur['is_day']) != 0,
      kind: curCond == null
          ? WeatherKind.unknown
          : weatherKindFromWapiCode(curCond),
    );

    // The hourly series starts at 00:00 of today; keep only current/future
    // slots so the strip begins at "Now" like the other providers.
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
    final hourly = <WeatherHour>[];
    for (final day in WxParse.listOf(
        WxParse.mapOf(j, 'forecast'), 'forecastday')) {
      if (day is! Map || hourly.length >= 48) break;
      for (final raw in WxParse.listOf(
          day.cast<String, dynamic>(), 'hour')) {
        if (raw is! Map || hourly.length >= 48) break;
        final s = raw.cast<String, dynamic>();
        final epoch = WxParse.i(s['time_epoch']);
        if (epoch == null || epoch < nowEpoch) continue;
        final t = WxParse.epoch(epoch);
        if (t == null) continue;
        final wx = _conditionCode(s);
        hourly.add(WeatherHour(
          time: t,
          temperature: WxParse.d(s['temp_c']),
          precipProbability: WxParse.d(s['chance_of_rain']),
          precipitation: WxParse.d(s['precip_mm']),
          windSpeed: WxParse.d(s['wind_kph']),
          windDirection: WxParse.d(s['wind_degree']),
          windGusts: WxParse.d(s['gust_kph']),
          kind: wx == null
              ? WeatherKind.unknown
              : weatherKindFromWapiCode(wx),
        ));
      }
    }

    final daily = <WeatherDay>[];
    for (final day in WxParse.listOf(
        WxParse.mapOf(j, 'forecast'), 'forecastday')) {
      if (day is! Map) continue;
      final s = day.cast<String, dynamic>();
      final d = DateTime.tryParse(WxParse.s(s['date']));
      if (d == null) continue;
      final daySum = WxParse.mapOf(s, 'day');
      final wx = _conditionCode(daySum);
      final astro = WxParse.mapOf(s, 'astro');
      daily.add(WeatherDay(
        date: d,
        tMax: WxParse.d(daySum['maxtemp_c']),
        tMin: WxParse.d(daySum['mintemp_c']),
        precipSum: WxParse.d(daySum['totalprecip_mm']),
        precipProbability: WxParse.d(daySum['daily_chance_of_rain']),
        windMax: WxParse.d(daySum['maxwind_kph']),
        windGustsMax: WxParse.d(daySum['maxwind_kph']), // no gust field
        windDirectionDominant: 0, // no dominant-direction field
        kind: wx == null
            ? WeatherKind.unknown
            : weatherKindFromWapiCode(wx),
        sunrise: _tryParseHm(d, astro['sunrise']),
        sunset: _tryParseHm(d, astro['sunset']),
      ));
    }

    return WeatherData(current: current, hourly: hourly, daily: daily);
  }

  /// WeatherAPI astro times ("06:23 AM") are wall-clock strings paired with
  /// the forecast [date]; combines them into a DateTime, or null.
  static DateTime? _tryParseHm(DateTime date, Object? hhmm) {
    final s = WxParse.s(hhmm).trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false)
        .firstMatch(s);
    if (m == null) return null;
    var hour = int.tryParse(m.group(1)!) ?? 0;
    final minute = int.tryParse(m.group(2)!) ?? 0;
    final pm = (m.group(3) ?? '').toUpperCase() == 'PM';
    if (pm && hour < 12) hour += 12;
    if (!pm && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static int? _conditionCode(Map<String, dynamic> s) =>
      WxParse.i(WxParse.mapOf(s, 'condition')['code']);
}

// ── 4) wttr.in (no key, secondary fallback) ──────────────────────────────────

/// JSON (j1) format from wttr.in. Everything arrives as strings; metric by
/// default (°C, km/h, mm, hPa — canonical already). Only ~8 three-hourly
/// slots per day over 3 days, so hourly rows are coarser and daily wind
/// stats are derived from the slots. Least reliable of the sources — used
/// as last resort. Requested units applied by [toRequestedUnits].
class WttrInProvider extends WeatherProvider {
  /// The ONLY host this adapter will ever contact.
  static const String _host = 'wttr.in';

  final WeatherHttp _http = WeatherHttp();

  @override
  WeatherProviderId get id => WeatherProviderId.wttr;

  @override
  String get label => 'wttr.in';

  @override
  String get credit => 'Data by wttr.in';

  @override
  bool get requiresKey => false;

  @override
  Future<WeatherData> fetch(WeatherFetchRequest request) async {
    final uri = Uri.https(
      _host,
      '/${request.lat.toStringAsFixed(4)},${request.lon.toStringAsFixed(4)}',
      {'format': 'j1'},
    );
    assert(uri.host == _host);
    final data = parse(await _http.getJson(uri));
    return toRequestedUnits(data, request.units);
  }

  /// j1 payload → [WeatherData]. All values are strings; [WxParse] handles
  /// the numeric coercion.
  static WeatherData parse(Map<String, dynamic> j) {
    final curList = WxParse.listOf(j, 'current_condition');
    final cur =
        curList.isNotEmpty && curList.first is Map
            ? (curList.first as Map).cast<String, dynamic>()
            : <String, dynamic>{};
    final curSpeed = WxParse.d(cur['windspeedKmph']);
    final current = WeatherCurrent(
      temperature: WxParse.d(cur['temp_C']),
      apparentTemperature: WxParse.d(cur['FeelsLikeC']),
      humidity: WxParse.d(cur['humidity']),
      precipitation: WxParse.d(cur['precipMM']),
      cloudCover: WxParse.d(cur['cloudcover']),
      pressure: WxParse.d(cur['pressure']),
      windSpeed: curSpeed,
      windDirection: WxParse.d(cur['winddirDegree']),
      // j1 exposes a gust field for the current conditions; fall back to the
      // mean speed when absent.
      windGusts: cur['WindGustKmph'] != null
          ? WxParse.d(cur['WindGustKmph'])
          : curSpeed,
      // wttr.in has no day/night flag; infer from the local clock (the
      // queried location is the device's own location).
      isDay: _isDaytime(),
      kind: weatherKindFromWwoCode(WxParse.i(cur['weatherCode']) ?? -1),
    );

    // j1 gives 3-hourly slots: "0", "300", … "2100" (hhmm, no padding).
    final now = DateTime.now();
    final cutoff =
        DateTime(now.year, now.month, now.day, now.hour - 1);
    final hourly = <WeatherHour>[];
    final daily = <WeatherDay>[];

    for (final raw in WxParse.listOf(j, 'weather')) {
      if (raw is! Map) continue;
      final day = raw.cast<String, dynamic>();
      final date = DateTime.tryParse(WxParse.s(day['date']));
      if (date == null) continue;

      final slots = <WeatherHour>[];
      for (final h in WxParse.listOf(day, 'hourly')) {
        if (h is! Map || hourly.length >= 32) continue;
        final s = h.cast<String, dynamic>();
        final hhmm = WxParse.i(s['time']) ?? 0;
        final t = DateTime(
            date.year, date.month, date.day, hhmm ~/ 100, hhmm % 100);
        // Skip today's already-elapsed slots so the strip starts at "Now".
        if (t.isBefore(cutoff)) continue;
        final speed = WxParse.d(s['windspeedKmph']);
        slots.add(WeatherHour(
          time: t,
          temperature: WxParse.d(s['tempC']),
          precipProbability: WxParse.d(s['chanceofrain']),
          precipitation: WxParse.d(s['precipMM']),
          windSpeed: speed,
          windDirection: WxParse.d(s['winddirDegree']),
          windGusts: s['WindGustKmph'] != null
              ? WxParse.d(s['WindGustKmph'])
              : speed,
          kind: weatherKindFromWwoCode(WxParse.i(s['weatherCode']) ?? -1),
        ));
      }

      if (slots.isNotEmpty) {
        // Derive the daily summary: max wind/gust, summed precipitation, the
        // wettest probability, and the direction/kind of the most
        // representative slot (max wind / midday).
        WeatherHour maxWind = slots.first;
        for (final s in slots) {
          if (s.windSpeed > maxWind.windSpeed) maxWind = s;
        }
        WeatherHour midday = slots.first;
        for (final s in slots) {
          if ((s.time.hour - 12).abs() < (midday.time.hour - 12).abs()) {
            midday = s;
          }
        }
        daily.add(WeatherDay(
          date: date,
          tMax: WxParse.d(day['maxtempC']),
          tMin: WxParse.d(day['mintempC']),
          precipSum: slots.fold(0.0, (sum, s) => sum + s.precipitation),
          precipProbability:
              slots.fold(0.0, (m, s) => s.precipProbability > m
                  ? s.precipProbability
                  : m),
          windMax: maxWind.windSpeed,
          windGustsMax: slots.fold(0.0, (m, s) => s.windGusts > m
              ? s.windGusts
              : m),
          windDirectionDominant: maxWind.windDirection,
          kind: midday.kind,
        ));
      }
      hourly.addAll(slots);
    }

    return WeatherData(current: current, hourly: hourly, daily: daily);
  }

  static bool _isDaytime() {
    final h = DateTime.now().hour;
    return h >= 6 && h < 19;
  }
}
