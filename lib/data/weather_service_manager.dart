import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_providers.dart';
import 'weather_service.dart';
import 'weather_units.dart';

/// Picks the active weather provider and fails over to no-key backups when
/// the active one fails.
///
/// Failover order (after the user's selection):
///   1. the selected provider (skipped when it needs a key and none is set)
///   2. Open-Meteo (free, no key)
///   3. wttr.in (free, no key)
///
/// Every provider call goes through the same unified [WeatherData] contract,
/// so the UI is unaware of which source actually answered — except for the
/// `source` / `servedByFallback` fields stamped onto the result for
/// attribution.
class WeatherServiceManager {
  /// [providers] overrides the adapter registry — used by tests to inject
  /// fakes; production code uses [instance].
  WeatherServiceManager({Map<WeatherProviderId, WeatherProvider>? providers})
      : _providers = providers ?? _defaultProviders();

  static final WeatherServiceManager instance = WeatherServiceManager();

  static Map<WeatherProviderId, WeatherProvider> _defaultProviders() => {
        WeatherProviderId.openMeteo: OpenMeteoProvider(),
        WeatherProviderId.openWeatherMap: OpenWeatherMapProvider(),
        WeatherProviderId.weatherApi: WeatherApiComProvider(),
        WeatherProviderId.wttr: WttrInProvider(),
      };

  final Map<WeatherProviderId, WeatherProvider> _providers;

  /// The adapters, in enum order (exposed for the settings UI).
  Iterable<WeatherProvider> get providers => _providers.values;

  WeatherProvider? providerOf(WeatherProviderId id) => _providers[id];

  /// The failover chain for [selected]: the selected provider first (skipped
  /// later if it is keyed but unconfigured), then the keyless providers in a
  /// fixed reliability order (Open-Meteo, then wttr.in). Pure function —
  /// unit-tested.
  static List<WeatherProviderId> chainFor(WeatherProviderId selected) {
    final chain = <WeatherProviderId>[selected];
    for (final id in const [
      WeatherProviderId.openMeteo,
      WeatherProviderId.wttr,
    ]) {
      if (!chain.contains(id)) chain.add(id);
    }
    return chain;
  }

  /// Fetches the unified forecast, walking the failover chain until one
  /// provider answers. Throws the last [WeatherException] only when every
  /// provider in the chain failed.
  ///
  /// [units] defaults to the persisted user preferences; [pastDays],
  /// [forecastDays] and [model] are honored by Open-Meteo and ignored by
  /// the other adapters (which return whatever horizon they support).
  Future<WeatherData> fetch({
    required double lat,
    required double lon,
    WeatherProviderId? provider,
    WeatherUnits? units,
    int pastDays = 0,
    int forecastDays = 7,
    WeatherModel model = WeatherModel.bestMatch,
  }) async {
    await WeatherProviderSettings.instance.load();
    await WeatherUnitSettings.instance.load();
    final settings = WeatherProviderSettings.instance;
    final selected = provider ?? settings.provider;
    final resolvedUnits = units ?? WeatherUnitSettings.instance.units;

    Object? lastError;
    for (final id in chainFor(selected)) {
      final p = _providers[id];
      if (p == null) continue; // unknown id (defensive)
      final key = p.requiresKey ? settings.apiKeyFor(id) : null;
      if (p.requiresKey && (key == null || key.isEmpty)) {
        // No key configured: skip this provider (do not count as an error —
        // the fallbacks below will serve the data).
        continue;
      }
      try {
        final data = await p.fetch(
          WeatherFetchRequest(
            lat: lat,
            lon: lon,
            apiKey: key,
            units: resolvedUnits,
            pastDays: pastDays,
            forecastDays: forecastDays,
            model: model,
          ),
        );
        return WeatherData(
          current: data.current,
          hourly: data.hourly,
          daily: data.daily,
          source: p.label,
          servedByFallback: id != selected,
          timezone: data.timezone,
          utcOffsetSeconds: data.utcOffsetSeconds,
          currentTime: data.currentTime,
        );
      } on WeatherException catch (e) {
        lastError = e;
        // Fail over to the next provider in the chain.
      } catch (_) {
        lastError = const WeatherException(WeatherError.badResponse);
      }
    }
    throw lastError is WeatherException
        ? lastError
        : const WeatherException(WeatherError.network);
  }
}

/// Persisted provider choice + API keys for the keyed providers.
///
/// Keys are *user* secrets: entered at runtime, stored only in this device's
/// SharedPreferences (the same convention as [GeoNameSettings]) and handed to
/// the adapter only at request time. No key is ever hard-coded or bundled.
class WeatherProviderSettings extends ChangeNotifier {
  WeatherProviderSettings._();
  static final WeatherProviderSettings instance = WeatherProviderSettings._();

  static const _kProvider = 'pb.weather.provider';
  static String _keyOf(WeatherProviderId id) => 'pb.weather.key.${id.name}';

  static const _defaultProvider = WeatherProviderId.openMeteo;

  WeatherProviderId _provider = _defaultProvider;
  final Map<WeatherProviderId, String?> _keys = {};
  bool _loaded = false;

  WeatherProviderId get provider => _provider;

  String? apiKeyFor(WeatherProviderId id) => _keys[id];

  bool hasKey(WeatherProviderId id) {
    final key = _keys[id];
    return key != null && key.isNotEmpty;
  }

  /// Loads persisted settings (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final stored = sp.getString(_kProvider);
      _provider = _decodeProvider(stored) ?? _defaultProvider;
      for (final id in WeatherProviderId.values) {
        _keys[id] = sp.getString(_keyOf(id));
      }
    } catch (_) {
      // Best-effort; leave defaults.
    }
    _loaded = true;
  }

  Future<void> setProvider(WeatherProviderId id) async {
    _provider = id;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kProvider, id.name);
    } catch (_) {}
  }

  Future<void> setApiKey(WeatherProviderId id, String? key) async {
    final trimmed = (key == null || key.trim().isEmpty) ? null : key.trim();
    _keys[id] = trimmed;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      if (trimmed == null) {
        await sp.remove(_keyOf(id));
      } else {
        await sp.setString(_keyOf(id), trimmed);
      }
    } catch (_) {}
  }

  static WeatherProviderId? _decodeProvider(String? stored) {
    for (final id in WeatherProviderId.values) {
      if (id.name == stored) return id;
    }
    return null;
  }
}
