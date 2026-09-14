import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../data/flight_data_provider.dart';
import '../data/weather_service.dart';
import '../l10n/app_localizations.dart';

/// Opens the Weather screen (forecast at the pilot's location) as a
/// full-screen sheet.
Future<void> showWeatherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => const _WeatherSheet(),
  );
}

enum _Phase { loading, ready, error }

enum _ErrorKind { noFix, network }

class _WeatherSheet extends StatefulWidget {
  const _WeatherSheet();

  @override
  State<_WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends State<_WeatherSheet> {
  _Phase _phase = _Phase.loading;
  _ErrorKind _errorKind = _ErrorKind.noFix;
  WeatherData? _data;
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Resolves the location (live flight-data fix first, then a one-shot device
  /// fix) and fetches the forecast for it.
  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _data = null;
    });

    // Read the live flight-data snapshot synchronously, before any await, so
    // the (possibly stale) context is only used while mounted.
    final data = FlightDataProvider.transformerOf(context).data;
    final hasLiveFix = data.hasFix &&
        (data.latitude != 0.0 || data.longitude != 0.0);

    double? lat;
    double? lon;
    if (hasLiveFix) {
      lat = data.latitude;
      lon = data.longitude;
    } else {
      final fix = await _oneShotFix();
      lat = fix?.$1;
      lon = fix?.$2;
    }

    if (!mounted) return;
    if (lat == null || lon == null) {
      setState(() {
        _phase = _Phase.error;
        _errorKind = _ErrorKind.noFix;
      });
      return;
    }

    try {
      final weather =
          await WeatherService.instance.fetch(lat: lat, lon: lon);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _data = weather;
        _lat = lat;
        _lon = lon;
      });
    } on WeatherException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorKind = _ErrorKind.network;
      });
    }
  }

  /// One-shot device position fix; null when permissions/services are off or
  /// the platform cannot provide a fix (e.g. desktop without location).
  Future<(double, double)?> _oneShotFix() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, l10n),
          const Divider(height: 1),
          Expanded(
            child: switch (_phase) {
              _Phase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
              _Phase.error => _buildError(theme, l10n),
              _Phase.ready => _buildContent(theme, l10n),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.air, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.weather, style: theme.textTheme.titleLarge),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.weatherRefresh,
            onPressed: _phase == _Phase.loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, AppLocalizations l10n) {
    final (icon, message) = switch (_errorKind) {
      _ErrorKind.noFix => (
          Icons.location_disabled_outlined,
          l10n.weatherNoGps,
        ),
      _ErrorKind.network => (
          Icons.cloud_off_outlined,
          l10n.weatherLoadFailed,
        ),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(l10n.weatherRetry),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n) {
    final data = _data!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _currentSection(theme, l10n, data.current),
        const SizedBox(height: 14),
        _statsRow(theme, l10n, data.current),
        if (data.hourly.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(theme, l10n.weatherHourly),
          const SizedBox(height: 8),
          _hourlyStrip(theme, l10n, data),
        ],
        if (data.daily.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(theme, l10n.weatherDaily),
          const SizedBox(height: 4),
          ...[for (var i = 0; i < data.daily.length; i++) i]
              .map((i) => _dayRow(theme, l10n, data, i)),
        ],
        const SizedBox(height: 24),
        Center(
          child: Text(
            '${l10n.weatherDataBy}\n'
            '${_coordsLabel(l10n)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ── Current conditions ────────────────────────────────────────────────────

  Widget _currentSection(
      ThemeData theme, AppLocalizations l10n, WeatherCurrent c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Big temperature + condition.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.temperature.round()}°',
                    style: theme.textTheme.displayMedium,
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(
                      kindIcon(c.kind, isDay: c.isDay),
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                kindLabel(l10n, c.kind),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.weatherFeelsLike(c.apparentTemperature.round()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // The primary instrument for a pilot: wind.
        _windBadge(theme, l10n, c.windSpeed, c.windGusts, c.windDirection),
      ],
    );
  }

  Widget _windBadge(ThemeData theme, AppLocalizations l10n, double speed,
      double gusts, double direction) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _WindArrow(direction: direction, size: 30, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            l10n.weatherWind,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.weatherSpeedKmh(speed.round()),
            style: theme.textTheme.titleLarge,
          ),
          Text(
            l10n.weatherGustsKmh(gusts.round()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Secondary stats ───────────────────────────────────────────────────────

  Widget _statsRow(
      ThemeData theme, AppLocalizations l10n, WeatherCurrent c) {
    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        _stat(theme, Icons.water_drop_outlined, l10n.weatherHumidity,
            '${c.humidity.round()}%'),
        _stat(theme, Icons.cloud_outlined, l10n.weatherCloudCover,
            '${c.cloudCover.round()}%'),
        _stat(theme, Icons.umbrella_outlined, l10n.weatherPrecipitation,
            '${c.precipitation.toStringAsFixed(1)} mm'),
        _stat(theme, Icons.speed_outlined, l10n.weatherPressure,
            '${c.pressure.round()} hPa'),
      ],
    );
  }

  Widget _stat(
      ThemeData theme, IconData icon, String label, String value) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hourly strip ──────────────────────────────────────────────────────────

  Widget _hourlyStrip(ThemeData theme, AppLocalizations l10n, WeatherData d) {
    final cells = <Widget>[];
    for (var i = 0; i < d.hourly.length; i++) {
      if (i > 0) cells.add(const SizedBox(width: 8));
      cells.add(_hourCell(theme, l10n, d.hourly[i], isFirst: i == 0));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: cells),
    );
  }

  Widget _hourCell(ThemeData theme, AppLocalizations l10n, WeatherHour h,
      {required bool isFirst}) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            isFirst ? l10n.weatherNow : '${two(h.time.hour)}:00',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isFirst
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isFirst ? FontWeight.bold : null,
            ),
          ),
          const SizedBox(height: 6),
          Icon(kindIcon(h.kind), size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text('${h.temperature.round()}°', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          _WindArrow(
            direction: h.windDirection,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Text(
            l10n.weatherSpeedKmh(h.windSpeed.round()),
            style: theme.textTheme.labelSmall,
          ),
          Text(
            l10n.weatherGustsShort(h.windGusts.round()),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (h.precipProbability > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.weatherPrecipProbability(h.precipProbability.round()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Daily rows ────────────────────────────────────────────────────────────

  Widget _dayRow(ThemeData theme, AppLocalizations l10n, WeatherData d, int i) {
    final day = d.daily[i];
    final localeName = Localizations.localeOf(context).toString();
    final label = i == 0
        ? l10n.weatherToday
        : DateFormat.E(localeName).format(day.date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis),
          ),
          Icon(kindIcon(day.kind), size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          if (day.precipProbability > 0)
            Text(
              l10n.weatherPrecipProbability(day.precipProbability.round()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          const Spacer(),
          Text('${day.tMin.round()}°',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(width: 8),
          Text('${day.tMax.round()}°', style: theme.textTheme.titleSmall),
          const SizedBox(width: 14),
          SizedBox(
            width: 86,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindArrow(
                  direction: day.windDirectionDominant,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.weatherSpeedKmh(day.windMax.round()),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _coordsLabel(AppLocalizations l10n) {
    final lat = _lat;
    final lon = _lon;
    if (lat == null || lon == null) return '';
    final latHemi = lat >= 0 ? 'N' : 'S';
    final lonHemi = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(3)}°$latHemi '
        '${lon.abs().toStringAsFixed(3)}°$lonHemi';
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(text, style: theme.textTheme.titleMedium);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// An arrow pointing where the wind is blowing TO (Open-Meteo's direction is
/// the direction the wind comes FROM, so we rotate by 180°).
class _WindArrow extends StatelessWidget {
  final double direction;
  final double size;
  final Color color;

  const _WindArrow({
    required this.direction,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (direction + 180) * math.pi / 180,
      child: Icon(
        Icons.arrow_upward,
        size: size,
        color: color,
      ),
    );
  }
}

/// Material icon for a [WeatherKind].
IconData kindIcon(WeatherKind kind, {bool isDay = true}) {
  switch (kind) {
    case WeatherKind.clear:
      return isDay ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined;
    case WeatherKind.mainlyClear:
      return Icons.wb_cloudy_outlined;
    case WeatherKind.partlyCloudy:
      return Icons.filter_drama;
    case WeatherKind.overcast:
      return Icons.cloud;
    case WeatherKind.fog:
      return Icons.blur_on;
    case WeatherKind.drizzle:
      return Icons.grain;
    case WeatherKind.rain:
      return Icons.water_drop;
    case WeatherKind.freezing:
      return Icons.ac_unit;
    case WeatherKind.snow:
      return Icons.snowing;
    case WeatherKind.showers:
      return Icons.umbrella;
    case WeatherKind.thunder:
      return Icons.thunderstorm;
    case WeatherKind.unknown:
      return Icons.cloud_queue;
  }
}

/// Localized description for a [WeatherKind].
String kindLabel(AppLocalizations l10n, WeatherKind kind) {
  switch (kind) {
    case WeatherKind.clear:
      return l10n.weatherConditionClear;
    case WeatherKind.mainlyClear:
      return l10n.weatherConditionMainlyClear;
    case WeatherKind.partlyCloudy:
      return l10n.weatherConditionPartlyCloudy;
    case WeatherKind.overcast:
      return l10n.weatherConditionOvercast;
    case WeatherKind.fog:
      return l10n.weatherConditionFog;
    case WeatherKind.drizzle:
      return l10n.weatherConditionDrizzle;
    case WeatherKind.rain:
      return l10n.weatherConditionRain;
    case WeatherKind.freezing:
      return l10n.weatherConditionFreezing;
    case WeatherKind.snow:
      return l10n.weatherConditionSnow;
    case WeatherKind.showers:
      return l10n.weatherConditionShowers;
    case WeatherKind.thunder:
      return l10n.weatherConditionThunder;
    case WeatherKind.unknown:
      return l10n.weatherConditionUnknown;
  }
}
