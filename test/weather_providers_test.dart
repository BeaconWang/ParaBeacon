import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/geocoding_service.dart';
import 'package:parabeacon/data/weather_providers.dart';
import 'package:parabeacon/data/weather_service.dart';
import 'package:parabeacon/data/weather_service_manager.dart';
import 'package:parabeacon/data/weather_units.dart';

void main() {
  // ── Open-Meteo ─────────────────────────────────────────────────────────────
  group('OpenMeteoProvider.parse', () {
    test('maps current, hourly and daily fields', () {
      final data = OpenMeteoProvider.parse({
        'current': {
          'temperature_2m': 21.4,
          'apparent_temperature': 19.8,
          'relative_humidity_2m': 55,
          'precipitation': 0.2,
          'weather_code': 61,
          'cloud_cover': 80,
          'surface_pressure': 1012.3,
          'wind_speed_10m': 12.5,
          'wind_direction_10m': 270,
          'wind_gusts_10m': 30.1,
          'is_day': 1,
        },
        'hourly': {
          'time': ['2026-09-14T08:00', '2026-09-14T09:00'],
          'temperature_2m': [20.0, 21.0],
          'precipitation_probability': [10, 40],
          'precipitation': [0.0, 0.1],
          'weather_code': [2, 61],
          'wind_speed_10m': [10.0, 14.0],
          'wind_direction_10m': [180, 200],
          'wind_gusts_10m': [20.0, 25.0],
        },
        'daily': {
          'time': ['2026-09-14'],
          'weather_code': [61],
          'temperature_2m_max': [24.0],
          'temperature_2m_min': [15.0],
          'precipitation_sum': [3.2],
          'precipitation_probability_max': [70],
          'wind_speed_10m_max': [22.0],
          'wind_gusts_10m_max': [40.0],
          'wind_direction_10m_dominant': [250],
        },
      });

      expect(data.current.temperature, 21.4);
      expect(data.current.kind, WeatherKind.rain);
      expect(data.current.isDay, isTrue);
      expect(data.hourly, hasLength(2));
      expect(data.hourly[1].kind, WeatherKind.rain);
      expect(data.hourly[1].precipProbability, 40);
      expect(data.daily.single.tMax, 24.0);
      expect(data.daily.single.windGustsMax, 40.0);
    });
  });

  // ── OpenWeatherMap One Call 3.0 ────────────────────────────────────────────
  group('OpenWeatherMapProvider.parse', () {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    test('converts m/s wind to km/h and maps condition ids', () {
      final data = OpenWeatherMapProvider.parse({
        'current': {
          'dt': nowSec,
          'sunrise': nowSec - 3600 * 6,
          'sunset': nowSec + 3600 * 6,
          'temp': 18.5,
          'feels_like': 17.0,
          'humidity': 60,
          'clouds': 40,
          'pressure': 1013,
          'wind_speed': 5.0, // m/s → 18 km/h
          'wind_deg': 45,
          'wind_gust': 8.0, // m/s → 28.8 km/h
          'weather': [
            {'id': 802}
          ],
        },
        'hourly': [
          {
            'dt': nowSec,
            'temp': 18.0,
            'pop': 0.3,
            'wind_speed': 4.0,
            'wind_deg': 30,
            'wind_gust': 7.0,
            'weather': [
              {'id': 500}
            ],
          },
        ],
        'daily': [
          {
            'dt': nowSec,
            'temp': {'min': 10.0, 'max': 21.0},
            'pop': 0.2,
            'wind_speed': 6.0,
            'wind_gust': 9.0,
            'wind_deg': 60,
            'weather': [
              {'id': 800}
            ],
          },
        ],
      });

      expect(data.current.windSpeed, closeTo(18.0, 0.01));
      expect(data.current.windGusts, closeTo(28.8, 0.01));
      expect(data.current.kind, WeatherKind.partlyCloudy);
      expect(data.current.isDay, isTrue);
      expect(data.hourly.single.kind, WeatherKind.rain);
      expect(data.hourly.single.precipProbability, closeTo(30, 0.01));
      expect(data.daily.single.kind, WeatherKind.clear);
      expect(data.daily.single.tMin, 10.0);
    });
  });

  // ── WeatherAPI.com ─────────────────────────────────────────────────────────
  group('WeatherApiComProvider.parse', () {
    test('parses current/day fields and skips elapsed hourly slots', () {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final data = WeatherApiComProvider.parse({
        'current': {
          'temp_c': 25.0,
          'feelslike_c': 27.0,
          'humidity': 70,
          'cloud': 20,
          'precip_mm': 0.0,
          'pressure_mb': 1008.0,
          'wind_kph': 9.0,
          'wind_degree': 130,
          'gust_kph': 15.0,
          'is_day': 1,
          'condition': {'code': 1000},
        },
        'forecast': {
          'forecastday': [
            {
              'date': '2026-09-14',
              'day': {
                'maxtemp_c': 28.0,
                'mintemp_c': 19.0,
                'totalprecip_mm': 1.5,
                'daily_chance_of_rain': 30,
                'maxwind_kph': 16.0,
                'condition': {'code': 1003},
              },
              'hour': [
                {
                  // One hour in the past → must be skipped.
                  'time_epoch': nowEpoch - 7200,
                  'temp_c': 20.0,
                  'chance_of_rain': 5,
                  'precip_mm': 0.0,
                  'wind_kph': 8.0,
                  'wind_degree': 100,
                  'gust_kph': 12.0,
                  'condition': {'code': 1000},
                },
                {
                  // Future → kept.
                  'time_epoch': nowEpoch + 3600,
                  'temp_c': 24.0,
                  'chance_of_rain': 25,
                  'precip_mm': 0.2,
                  'wind_kph': 11.0,
                  'wind_degree': 120,
                  'gust_kph': 18.0,
                  'condition': {'code': 1087},
                },
              ],
            },
          ],
        },
      });

      expect(data.current.temperature, 25.0);
      expect(data.current.kind, WeatherKind.clear);
      expect(data.daily.single.tMax, 28.0);
      expect(data.daily.single.kind, WeatherKind.mainlyClear);
      // Only the future slot survives the "Now" trim.
      expect(data.hourly, hasLength(1));
      expect(data.hourly.single.kind, WeatherKind.thunder);
    });
  });

  // ── wttr.in ────────────────────────────────────────────────────────────────
  group('WttrInProvider.parse', () {
    // Slots are only kept when they are at/after "now - 1h", so the fixtures
    // use tomorrow's date to stay independent of the time of day.
    String tomorrowDate() {
      final t = DateTime.now().add(const Duration(days: 1));
      String two(int n) => n.toString().padLeft(2, '0');
      return '${t.year}-${two(t.month)}-${two(t.day)}';
    }

    test('coerces string values and derives daily wind stats', () {
      final data = WttrInProvider.parse({
        'current_condition': [
          {
            'temp_C': '22',
            'FeelsLikeC': '24',
            'humidity': '65',
            'cloudcover': '30',
            'precipMM': '0.1',
            'pressure': '1015',
            'windspeedKmph': '11',
            'winddirDegree': '225',
            'weatherCode': '113',
          }
        ],
        'weather': [
          {
            'date': tomorrowDate(),
            'maxtempC': '26',
            'mintempC': '16',
            'hourly': [
              {
                'time': '1200',
                'tempC': '26',
                'chanceofrain': '10',
                'precipMM': '0.0',
                'windspeedKmph': '14',
                'winddirDegree': '230',
                'weatherCode': '113',
              },
              {
                'time': '1500',
                'tempC': '25',
                'chanceofrain': '40',
                'precipMM': '0.5',
                'windspeedKmph': '20',
                'winddirDegree': '240',
                'weatherCode': '299',
              },
            ],
          }
        ],
      });

      expect(data.current.temperature, 22);
      expect(data.current.kind, WeatherKind.clear); // WMO 113
      expect(data.current.windSpeed, 11);
      expect(data.hourly, hasLength(2));
      expect(data.daily, hasLength(1));
      final day = data.daily.single;
      expect(day.tMax, 26);
      expect(day.tMin, 16);
      expect(day.precipSum, closeTo(0.5, 0.001));
      expect(day.precipProbability, 40);
      // Max wind (and its direction) comes from the 15:00 slot.
      expect(day.windMax, 20);
      expect(day.windDirectionDominant, 240);
      // But the day's icon comes from the midday slot (113 → clear).
      expect(day.kind, WeatherKind.clear);
    });

    test('daily kind comes from the midday slot, not the windiest one', () {
      final data = WttrInProvider.parse({
        'current_condition': [
          {
            'temp_C': '10',
            'windspeedKmph': '5',
            'weatherCode': '113',
          }
        ],
        'weather': [
          {
            'date': tomorrowDate(),
            'maxtempC': '12',
            'mintempC': '5',
            'hourly': [
              {
                'time': '900',
                'tempC': '8',
                'chanceofrain': '0',
                'precipMM': '0.0',
                'windspeedKmph': '10',
                'winddirDegree': '90',
                'weatherCode': '299', // showers, windiest slot
              },
              {
                'time': '1200',
                'tempC': '12',
                'chanceofrain': '0',
                'precipMM': '0.0',
                'windspeedKmph': '5',
                'winddirDegree': '90',
                'weatherCode': '113', // clear, midday slot
              },
            ],
          }
        ],
      });
      expect(data.daily.single.kind, WeatherKind.clear);
      expect(data.daily.single.windDirectionDominant, 90);
      expect(data.daily.single.windMax, 10);
    });
  });

  // ── Manager ────────────────────────────────────────────────────────────────
  group('WeatherServiceManager', () {
    test('failover chain: selected first, then Open-Meteo, then wttr.in', () {
      expect(
        WeatherServiceManager.chainFor(WeatherProviderId.openWeatherMap),
        const [
          WeatherProviderId.openWeatherMap,
          WeatherProviderId.openMeteo,
          WeatherProviderId.wttr,
        ],
      );
      expect(
        WeatherServiceManager.chainFor(WeatherProviderId.openMeteo),
        const [WeatherProviderId.openMeteo, WeatherProviderId.wttr],
      );
      expect(
        WeatherServiceManager.chainFor(WeatherProviderId.wttr),
        const [WeatherProviderId.wttr, WeatherProviderId.openMeteo],
      );
    });

    test('fails over to the next provider when one throws', () async {
      // A key must be configured for the keyed provider to even be tried;
      // simulate the user having saved one.
      await WeatherProviderSettings.instance
          .setApiKey(WeatherProviderId.weatherApi, 'test-key');
      final failing = _FakeProvider(
        id: WeatherProviderId.weatherApi,
        label: 'FakeWAPI',
        throws: const WeatherException(WeatherError.unauthorized),
        requiresKey: true,
      );
      final working = _FakeProvider(
        id: WeatherProviderId.openMeteo,
        label: 'FakeOM',
      );
      final manager = WeatherServiceManager(providers: {
        WeatherProviderId.openMeteo: working,
        WeatherProviderId.openWeatherMap: failing,
        WeatherProviderId.weatherApi: failing,
        WeatherProviderId.wttr: failing,
      });

      final data = await manager.fetch(
        lat: 30.0,
        lon: 104.0,
        provider: WeatherProviderId.weatherApi,
      );
      expect(data.source, 'FakeOM');
      expect(data.servedByFallback, isTrue);
    });

    test('skips a keyed provider that has no key configured', () async {
      await WeatherProviderSettings.instance
          .setApiKey(WeatherProviderId.weatherApi, null);
      final keyed = _FakeProvider(
        id: WeatherProviderId.weatherApi,
        label: 'FakeWAPI',
        requiresKey: true,
      );
      final working = _FakeProvider(
        id: WeatherProviderId.openMeteo,
        label: 'FakeOM',
      );
      final manager = WeatherServiceManager(providers: {
        WeatherProviderId.openMeteo: working,
        WeatherProviderId.weatherApi: keyed,
        WeatherProviderId.wttr: keyed,
      });

      final data = await manager.fetch(
        lat: 30.0,
        lon: 104.0,
        provider: WeatherProviderId.weatherApi,
      );
      expect(data.source, 'FakeOM');
      expect(data.servedByFallback, isTrue);
    });

    test('throws the last error when every provider fails', () async {
      final failing = _FakeProvider(
        id: WeatherProviderId.openMeteo,
        label: 'FakeOM',
        throws: const WeatherException(WeatherError.network),
      );
      final manager = WeatherServiceManager(providers: {
        WeatherProviderId.openMeteo: failing,
        WeatherProviderId.wttr: failing,
      });

      await expectLater(
        manager.fetch(lat: 30.0, lon: 104.0, provider: WeatherProviderId.wttr),
        throwsA(isA<WeatherException>()),
      );
    });
  });

  // ── Open-Meteo request URL (unified full-parameter request) ────────────────
  group('OpenMeteoProvider.buildUri', () {
    test('default request pulls the full hourly parameter set', () {
      final uri = OpenMeteoProvider.buildUri(
        const WeatherFetchRequest(lat: 45.75, lon: 4.85),
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.open-meteo.com');
      expect(uri.path, '/v1/forecast');
      expect(uri.queryParameters['latitude'], '45.7500');
      expect(uri.queryParameters['longitude'], '4.8500');
      expect(uri.queryParameters['timezone'], 'auto');
      // No history / no explicit model by default.
      expect(uri.queryParameters['past_days'], isNull);
      expect(uri.queryParameters['models'], isNull);
      expect(uri.queryParameters['forecast_days'], '7');
      // Unit defaults (metric).
      expect(uri.queryParameters['temperature_unit'], 'celsius');
      expect(uri.queryParameters['wind_speed_unit'], 'kmh');
      expect(uri.queryParameters['precipitation_unit'], 'mm');

      final hourly = uri.queryParameters['hourly']!;
      // Exact match on purpose: a missing separator would glue two variables
      // together ("wind_speed_500hPasoil_temperature_0cm") while still
      // passing a `contains` check — and Open-Meteo answers HTTP 400, i.e.
      // "always load failed", for the whole request.
      expect(hourly.split(','), [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'precipitation_probability',
        'precipitation',
        'rain',
        'snowfall',
        'weather_code',
        'cloud_cover',
        'cloud_cover_low',
        'cloud_cover_mid',
        'cloud_cover_high',
        'visibility',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
        'wind_speed_80m',
        'wind_speed_120m',
        // One swipeable altitude page per pressure level.
        for (final hPa in kWindAloftPressureLevels) 'wind_speed_${hPa}hPa',
        'soil_temperature_0cm',
        'shortwave_radiation',
        'soil_moisture_0_to_1cm',
        'et0_fao_evapotranspiration',
        'cape',
        'is_day',
      ]);
      final daily = uri.queryParameters['daily']!;
      for (final p in ['sunrise', 'sunset', 'temperature_2m_max',
        'wind_gusts_10m_max', 'precipitation_probability_max']) {
        expect(daily.contains(p), isTrue, reason: 'missing daily param: $p');
      }
    });

    test('past days, forecast days, model and units are applied (and clamped)',
        () {
      final uri = OpenMeteoProvider.buildUri(
        const WeatherFetchRequest(
          lat: 0,
          lon: 0,
          pastDays: 200, // beyond the API ceiling → clamped to 92
          forecastDays: 30, // beyond the API ceiling → clamped to 16
          model: WeatherModel.gfsSeamless,
          units: WeatherUnits(
            temperature: TemperatureUnit.fahrenheit,
            wind: WindSpeedUnit.mph,
            precipitation: PrecipitationUnit.inch,
          ),
        ),
      );
      expect(uri.queryParameters['past_days'], '92');
      expect(uri.queryParameters['forecast_days'], '16');
      expect(uri.queryParameters['models'], 'gfs_seamless');
      expect(uri.queryParameters['temperature_unit'], 'fahrenheit');
      expect(uri.queryParameters['wind_speed_unit'], 'mph');
      expect(uri.queryParameters['precipitation_unit'], 'inch');
    });

    test('model api values map 1:1 to the Open-Meteo parameter', () {
      expect(WeatherModel.bestMatch.apiValue, 'best_match');
      expect(WeatherModel.ecmwfIfs025.apiValue, 'ecmwf_ifs025');
      expect(WeatherModel.gfsSeamless.apiValue, 'gfs_seamless');
      expect(WeatherModel.cmaRaeForecast.apiValue, 'cma_rae_forecast');
    });
  });

  // ── Open-Meteo detailed parse ──────────────────────────────────────────────
  group('OpenMeteoProvider.parse (extended)', () {
    test('maps extended hourly metrics, sunrise/sunset and context', () {
      final data = OpenMeteoProvider.parse({
        'timezone': 'Europe/Paris',
        'utc_offset_seconds': 7200,
        'current': {
          'temperature_2m': 20.0,
          'apparent_temperature': 19.0,
          'relative_humidity_2m': 50,
          'is_day': 1,
          'precipitation': 0.0,
          'rain': 0.0,
          'weather_code': 0,
          'cloud_cover': 10,
          'surface_pressure': 1015.0,
          'wind_speed_10m': 10.0,
          'wind_direction_10m': 180,
          'wind_gusts_10m': 20.0,
          'time': '2026-09-14T08:20',
        },
        'hourly': {
          'time': ['2026-09-14T08:00', '2026-09-14T09:00'],
          'temperature_2m': [20.0, 21.0],
          'apparent_temperature': [19.5, 20.5],
          'relative_humidity_2m': [55, 60],
          'precipitation_probability': [10, 40],
          'precipitation': [0.0, 0.1],
          'rain': [0.0, 0.1],
          'snowfall': [0.0, 0.0],
          'weather_code': [0, 2],
          'cloud_cover': [10, 50],
          'cloud_cover_low': [5, 30],
          'cloud_cover_mid': [3, 15],
          'cloud_cover_high': [2, 5],
          'visibility': [24140.0, 20000.0],
          'wind_speed_10m': [10.0, 12.0],
          'wind_direction_10m': [180, 200],
          'wind_gusts_10m': [20.0, 24.0],
          'wind_speed_80m': [15.0, 17.0],
          'wind_speed_120m': [18.0, 20.0],
          'soil_temperature_0cm': [18.0, 19.0],
          'shortwave_radiation': [120.0, 240.0],
          'soil_moisture_0_to_1cm': [0.25, 0.24],
          'et0_fao_evapotranspiration': [0.05, 0.12],
          'cape': [10, 500],
          'is_day': [1, 1],
        },
        'daily': {
          'time': ['2026-09-14'],
          'weather_code': [0],
          'temperature_2m_max': [24.0],
          'temperature_2m_min': [15.0],
          'precipitation_sum': [1.0],
          'snowfall_sum': [0.0],
          'precipitation_probability_max': [40],
          'wind_speed_10m_max': [22.0],
          'wind_gusts_10m_max': [40.0],
          'wind_direction_10m_dominant': [250],
          'sunrise': ['2026-09-14T06:23'],
          'sunset': ['2026-09-14T19:52'],
        },
      });

      // Response context (location timezone + provider's own now).
      expect(data.timezone, 'Europe/Paris');
      expect(data.utcOffsetSeconds, 7200);
      expect(data.currentTime, DateTime(2026, 9, 14, 8, 20));

      // Extended hourly metrics.
      final h = data.hourly[1];
      expect(h.apparentTemperature, 20.5);
      expect(h.relativeHumidity, 60);
      expect(h.rain, 0.1);
      expect(h.snowfall, 0.0);
      expect(h.cloudCover, 50);
      expect(h.cloudLow, 30);
      expect(h.cloudMid, 15);
      expect(h.cloudHigh, 5);
      expect(h.visibility, 20000);
      expect(h.windSpeed80m, 17);
      expect(h.windSpeed120m, 20);
      expect(h.soilTemperature, 19);
      expect(h.shortwaveRadiation, 240);
      expect(h.soilMoisture, 0.24);
      expect(h.et0, 0.12);
      expect(h.cape, 500);
      expect(h.isDay, isTrue);

      // Daily glance fields.
      final day = data.daily.single;
      expect(day.kind, WeatherKind.clear);
      expect(day.sunrise, DateTime(2026, 9, 14, 6, 23));
      expect(day.sunset, DateTime(2026, 9, 14, 19, 52));
      expect(day.snowfallSum, 0.0);
    });

    test('hourly series is NOT capped (past_days + 16-day horizon) and '
        'missing columns stay null', () {
      final times = [
        for (var i = 0; i < 400; i++)
          '2026-09-${(i ~/ 24 + 1).toString().padLeft(2, '0')}'
          'T${(i % 24).toString().padLeft(2, '0')}:00',
      ];
      final data = OpenMeteoProvider.parse({
        'current': {'weather_code': 0, 'is_day': 1},
        'hourly': {
          'time': times,
          'temperature_2m': [for (var i = 0; i < 400; i++) 10.0],
          // cape column missing entirely (e.g. model without the variable).
        },
        'daily': {'time': ['2026-09-01']},
      });
      expect(data.hourly, hasLength(400));
      expect(data.hourly.first.cape, isNull);
      expect(data.hourly.first.windSpeed80m, isNull);
      expect(data.daily.single.sunrise, isNull);
    });
  });

  // ── Unit conversion ───────────────────────────────────────────────────────
  group('toRequestedUnits', () {
    final metric = WeatherData(
      current: const WeatherCurrent(
        temperature: 20,
        apparentTemperature: 19,
        humidity: 50,
        precipitation: 2.54,
        cloudCover: 10,
        pressure: 1013,
        windSpeed: 36, // km/h
        windDirection: 180,
        windGusts: 54, // km/h
        isDay: true,
        kind: WeatherKind.clear,
      ),
      hourly: [
        WeatherHour(
          time: DateTime(2026),
          temperature: 0,
          precipProbability: 0,
          precipitation: 25.4, // mm
          windSpeed: 3.6,
          windDirection: 0,
          windGusts: 7.2,
          kind: WeatherKind.clear,
          apparentTemperature: -1,
          windSpeed80m: 10.8,
          windSpeed120m: 14.4,
          soilTemperature: 10,
          et0: 1,
        ),
      ],
      daily: [
        WeatherDay(
          date: DateTime(2026),
          tMax: 10,
          tMin: 0,
          precipSum: 50.8,
          precipProbability: 0,
          windMax: 18,
          windGustsMax: 36,
          windDirectionDominant: 0,
        ),
      ],
    );

    test('metric passthrough returns the identical object', () {
      expect(toRequestedUnits(metric, WeatherUnits.metric), same(metric));
    });

    test('converts °C→°F, km/h→m/s and mm→inch across the whole model', () {
      final out = toRequestedUnits(
        metric,
        const WeatherUnits(
          temperature: TemperatureUnit.fahrenheit,
          wind: WindSpeedUnit.ms,
          precipitation: PrecipitationUnit.inch,
        ),
      );
      expect(out.current.temperature, closeTo(68.0, 0.01));
      expect(out.current.apparentTemperature, closeTo(66.2, 0.01));
      expect(out.current.windSpeed, closeTo(10.0, 0.001));
      expect(out.current.windGusts, closeTo(15.0, 0.001));
      expect(out.current.precipitation, closeTo(0.1, 0.0001));

      expect(out.hourly.single.temperature, closeTo(32.0, 0.01));
      expect(out.hourly.single.soilTemperature, closeTo(50.0, 0.01));
      expect(out.hourly.single.windSpeed80m, closeTo(3.0, 0.001));
      expect(out.hourly.single.windSpeed120m, closeTo(4.0, 0.001));
      expect(out.hourly.single.precipitation, closeTo(1.0, 0.0001));
      expect(out.hourly.single.et0, closeTo(0.03937, 0.0001));

      expect(out.daily.single.tMax, closeTo(50.0, 0.01));
      expect(out.daily.single.precipSum, closeTo(2.0, 0.0001));
      expect(out.daily.single.windMax, closeTo(5.0, 0.001));
    });
  });

  group('WeatherUnits conversions', () {
    test('temperature round-trips', () {
      expect(
        WeatherUnits.convertTemperature(
            32, TemperatureUnit.fahrenheit, TemperatureUnit.celsius),
        closeTo(0, 1e-9),
      );
      expect(
        WeatherUnits.convertTemperature(
            100, TemperatureUnit.celsius, TemperatureUnit.fahrenheit),
        212,
      );
      expect(
        WeatherUnits.temperatureToCelsius(212, TemperatureUnit.fahrenheit),
        100,
      );
    });

    test('wind converts between km/h and m/s / mph / kn', () {
      expect(WeatherUnits.windToKmh(10, WindSpeedUnit.ms), closeTo(36, 1e-9));
      expect(WeatherUnits.windToKmh(10, WindSpeedUnit.kn), closeTo(18.52, 0.001));
      expect(
        WeatherUnits.convertWindFromKmh(36, WindSpeedUnit.mph),
        closeTo(22.3694, 0.0001),
      );
      expect(
        WeatherUnits.convertWindFromKmh(36, WindSpeedUnit.kn),
        closeTo(19.4384, 0.0001),
      );
    });

    test('precipitation converts mm → inch', () {
      expect(
        WeatherUnits.convertPrecipFromMm(25.4, PrecipitationUnit.inch),
        closeTo(1, 1e-9),
      );
      expect(
        WeatherUnits.convertPrecipFromMm(5, PrecipitationUnit.mm),
        5,
      );
    });
  });

  // ── Geocoding parse ───────────────────────────────────────────────────────
  group('GeocodedPlace.tryParse', () {
    test('parses string coordinates and keeps the short name', () {
      final place = GeocodedPlace.tryParse({
        'lat': '45.75',
        'lon': '4.85',
        'name': 'Lyon',
        'display_name': 'Lyon, Rhône, France',
      });
      expect(place, isNotNull);
      expect(place!.lat, 45.75);
      expect(place.lon, 4.85);
      expect(place.name, 'Lyon');
      expect(place.displayName, 'Lyon, Rhône, France');
    });

    test('falls back to the first display-name part when name is missing', () {
      final place = GeocodedPlace.tryParse({
        'lat': '1.0',
        'lon': '2.0',
        'display_name': 'Foo, Bar, Baz',
      });
      expect(place!.name, 'Foo');
    });

    test('rejects malformed entries', () {
      expect(
        GeocodedPlace.tryParse(
            {'lat': '99', 'lon': '2', 'display_name': 'X'}),
        isNull,
      ); // latitude out of range
      expect(
        GeocodedPlace.tryParse({'lat': 'a', 'lon': '2', 'display_name': 'X'}),
        isNull,
      ); // non-numeric
      expect(
        GeocodedPlace.tryParse({'lat': '1', 'lon': '2', 'display_name': ''}),
        isNull,
      ); // no name at all
      expect(GeocodedPlace.tryParse('nope'), isNull); // not a map
    });
  });

  windAloftTests();
}

/// Minimal in-memory provider used to exercise manager failover without
/// touching the network.
class _FakeProvider extends WeatherProvider {
  @override
  final WeatherProviderId id;
  @override
  final String label;
  final WeatherException? throws;
  @override
  final bool requiresKey;

  _FakeProvider({
    required this.id,
    required this.label,
    this.throws,
    this.requiresKey = false,
  });

  @override
  String get credit => label;

  @override
  Future<WeatherData> fetch(WeatherFetchRequest request) async {
    final error = throws;
    if (error != null) throw error;
    return const WeatherData(
      current: WeatherCurrent(
        temperature: 1,
        apparentTemperature: 1,
        humidity: 1,
        precipitation: 0,
        cloudCover: 0,
        pressure: 1000,
        windSpeed: 0,
        windDirection: 0,
        windGusts: 0,
        isDay: true,
        kind: WeatherKind.clear,
      ),
      hourly: [],
      daily: [],
    );
  }
}

// ── Wind aloft (upper-air profile) ──────────────────────────────────────────

/// Coverage for the upper-air wind levels behind the swipeable altitude
/// pages of the weather panel. Called from [main].
void windAloftTests() {
  group('wind aloft', () {
  test('pressure levels are turned into altitudes above ground', () {
    // Sea level: every requested level is available.
    final seaLevel = windAloftLevels(elevationMeters: 0);
    expect(seaLevel.first.metersAgl, 10);
    expect(seaLevel.map((l) => l.metersAgl).take(3), [10, 80, 120]);
    expect(seaLevel.length, 3 + kWindAloftPressureLevels.length);

    // A high site drops the levels that would sit inside the terrain. The
    // three above-ground levels always stay, whatever the elevation.
    final highSite = windAloftLevels(elevationMeters: 1800);
    expect(highSite.map((l) => l.metersAgl).take(3), [10, 80, 120]);
    expect(
      highSite
          .where((l) => l.pressureHPa != null)
          .every((l) => l.metersAgl >= 100),
      isTrue,
    );
    expect(highSite.length, lessThan(seaLevel.length));
    // 950 hPa (~540 m AMSL) is underground here, 500 hPa is not.
    expect(
      highSite.any((l) => l.pressureHPa == 950),
      isFalse,
    );
    expect(highSite.any((l) => l.pressureHPa == 500), isTrue);
  });

  test('wind speeds are read per level from an hourly sample', () {
    final hour = WeatherHour(
      time: DateTime(2026, 9, 14, 10),
      temperature: 20,
      precipitation: 0,
      precipProbability: 0,
      windSpeed: 12,
      windDirection: 270,
      windGusts: 16,
      windSpeed80m: 18,
      windSpeed120m: 21,
      windSpeedByLevel: const {950: 25, 700: 40},
      kind: WeatherKind.clear,
    );
    final levels = windAloftLevels(elevationMeters: 0);
    final at10 = levels.firstWhere((l) => l.metersAgl == 10);
    final at120 = levels.firstWhere((l) => l.metersAgl == 120);
    final at850 =
        levels.firstWhere((l) => l.pressureHPa == 850, orElse: () => at10);
    expect(at10.read(hour), 12);
    expect(at120.read(hour), 21);
    expect(at850.read(hour), isNull);
    expect(levels.firstWhere((l) => l.pressureHPa == 700).read(hour), 40);
  });

  test('Open-Meteo payload carries the levels and the grid elevation', () {
    final data = OpenMeteoProvider.parse({
      'elevation': 1500.0,
      'current': {'time': '2026-09-14T10:00'},
      'hourly': {
        'time': ['2026-09-14T10:00', '2026-09-14T11:00'],
        'wind_speed_10m': [10.0, 12.0],
        'wind_speed_950hPa': [20.0, 22.0],
        'wind_speed_500hPa': [60.0, 62.0],
      },
      'daily': {
        'time': ['2026-09-14'],
        'temperature_2m_max': [20.0],
        'temperature_2m_min': [10.0],
      },
    });

    expect(data.elevation, 1500);
    expect(data.hourly.first.windSpeedByLevel, {950: 20, 500: 60});
    expect(data.hourly.last.windSpeedByLevel, {950: 22, 500: 62});
  });

  test('levels are converted together with the rest of the wind', () {
    final metric = OpenMeteoProvider.parse({
      'elevation': 0,
      'current': {'time': '2026-09-14T10:00'},
      'hourly': {
        'time': ['2026-09-14T10:00'],
        'wind_speed_10m': [10.0],
        'wind_speed_500hPa': [40.0],
      },
      'daily': {
        'time': ['2026-09-14'],
        'temperature_2m_max': [20.0],
        'temperature_2m_min': [10.0],
      },
    });
    expect(metric.hourly.first.windSpeedByLevel, {500: 40});

    final imperial = toRequestedUnits(
      metric,
      const WeatherUnits(
        temperature: TemperatureUnit.fahrenheit,
        wind: WindSpeedUnit.mph,
        precipitation: PrecipitationUnit.inch,
      ),
    );
    expect(imperial.elevation, 0);
    expect(imperial.hourly.first.windSpeedByLevel![500],
        closeTo(40 / 1.609344, 0.001));
  });
});
}
