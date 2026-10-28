import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../l10n/app_localizations.dart';
import 'decimal_places.dart';

/// A debug control that displays every field of the unified [FlightData]
/// snapshot coming out of the data layer.
///
/// It subscribes to the shared [FlightDataProvider], so it live-updates with
/// whatever source is active (simulator, BLE sensor, or a debug override) and
/// is handy for verifying the whole data pipeline at a glance. Nullable fields
/// that are currently absent are rendered as a muted "—".
class DataMonitorControl extends StatelessWidget {
  const DataMonitorControl({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final d = FlightDataProvider.of(context);

    final rows = <_Row>[
      _Row(
        l10n.dataMonitorFix,
        d.hasFix ? l10n.dataMonitorYes : l10n.dataMonitorNo,
        highlight: d.hasFix,
      ),
      _Row(
        l10n.dataMonitorVerticalSpeed,
        _fmt(context, d.verticalSpeed, 2, 'monitorVerticalSpeedDecimals'),
        unit: 'm/s',
      ),
      _Row(
        l10n.dataMonitorGroundSpeed,
        _fmt(context, d.groundSpeed, 1, 'monitorGroundSpeedDecimals'),
        unit: 'km/h',
      ),
      _Row(
        l10n.dataMonitorAltitude,
        _fmt(context, d.altitude, 1, 'monitorAltitudeDecimals'),
        unit: 'm',
      ),
      _Row(
        l10n.dataMonitorBaroAltitude,
        _fmtN(context, d.baroAltitude, 1, 'monitorBaroAltitudeDecimals'),
        unit: 'm',
      ),
      _Row(
        l10n.dataMonitorGpsAltitude,
        _fmtN(context, d.gpsAltitude, 1, 'monitorGpsAltitudeDecimals'),
        unit: 'm',
      ),
      _Row(
        l10n.dataMonitorLatitude,
        _fmt(context, d.latitude, 6, 'monitorLatitudeDecimals'),
        unit: '°',
      ),
      _Row(
        l10n.dataMonitorLongitude,
        _fmt(context, d.longitude, 6, 'monitorLongitudeDecimals'),
        unit: '°',
      ),
      _Row(
        l10n.dataMonitorHeading,
        _fmt(context, d.heading, 0, 'monitorHeadingDecimals'),
        unit: '°',
      ),
      _Row(
        l10n.dataMonitorGpsAccuracy,
        _fmtN(context, d.gpsAccuracy, 1, 'monitorGpsAccuracyDecimals'),
        unit: 'm',
      ),
      _Row(l10n.dataMonitorSatellites, d.satellites?.toString() ?? '—'),
      _Row(
        l10n.dataMonitorWindSpeed,
        _fmt(context, d.windSpeed, 1, 'monitorWindSpeedDecimals'),
        unit: 'km/h',
      ),
      _Row(
        l10n.dataMonitorWindDirection,
        _fmt(context, d.windDirection, 0, 'monitorWindDirectionDecimals'),
        unit: '°',
      ),
      _Row(
        l10n.dataMonitorPressure,
        _fmtN(context, d.pressure, 1, 'monitorPressureDecimals'),
        unit: 'hPa',
      ),
      _Row(
        l10n.dataMonitorTemperature,
        _fmtN(context, d.temperature, 1, 'monitorTemperatureDecimals'),
        unit: '°C',
      ),
      _Row(
        l10n.dataMonitorBattery,
        d.battery != null ? '${d.battery}' : '—',
        unit: '%',
      ),
      _Row(
        l10n.dataMonitorHeartRate,
        d.heartRate != null ? '${d.heartRate}' : '—',
        unit: 'bpm',
      ),
      _Row(l10n.dataMonitorTimestamp, _fmtTime(d.timestamp)),

      // ── Derived (computed from the fields above, no extra sensors) ────────
      _Section(l10n.dataMonitorDerived),
      _Row(
        l10n.dataMonitorGlideRatio,
        _glideRatio(
          d,
          DecimalPlacesScope.rangeOf(context, 'monitorGlideRatioDecimals'),
        ),
      ),
      _Row(l10n.dataMonitorHeading, _cardinal8(d.heading)),
      _Row(
        l10n.dataMonitorWindDir,
        _cardinal8(
          d.windDirection,
          chinese: Localizations.localeOf(context).languageCode == 'zh',
        ),
      ),
      _Row(
        l10n.dataMonitorBaroGpsDelta,
        _altitudeDelta(
          d,
          DecimalPlacesScope.rangeOf(context, 'monitorAltitudeDeltaDecimals'),
        ),
        unit: 'm',
      ),
      _Row(
        l10n.dataMonitorTotalEnergy,
        _totalEnergyAltitude(
          d,
          DecimalPlacesScope.rangeOf(context, 'monitorTotalEnergyDecimals'),
        ),
        unit: 'm',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.data_object, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.dataMonitorTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: d.hasFix
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.dataMonitorLive,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: d.hasFix
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            itemBuilder: (context, i) => _buildRow(theme, rows[i], i),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, _Row row, int index) {
    // Section headers render as a compact, emphasized label spanning the row.
    if (row is _Section) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Text(
          row.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 9,
          ),
        ),
      );
    }
    final bg = index.isEven
        ? Colors.transparent
        : theme.colorScheme.surfaceContainerHighest.withAlpha(80);
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            row.unit == null ? row.value : '${row.value} ${row.unit}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: row.highlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(
    BuildContext context,
    double value,
    int decimals,
    String precisionKey,
  ) => formatDecimalValue(
    value,
    autoDecimals: decimals,
    range: DecimalPlacesScope.rangeOf(context, precisionKey),
  );

  static String _fmtN(
    BuildContext context,
    double? value,
    int decimals,
    String precisionKey,
  ) => value == null ? '—' : _fmt(context, value, decimals, precisionKey);

  static String _fmtTime(DateTime? t) {
    if (t == null) return '—';
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// Instantaneous glide ratio (L/D): horizontal speed / sink rate. Only
  /// meaningful while sinking; climbs / near-level flight and no-fix render "—".
  /// Matches the logic used by the standalone glide-ratio control.
  static String _glideRatio(FlightData d, DecimalPlaceRange? precision) {
    final vsMs = d.verticalSpeed; // m/s (+climb / -sink)
    final gsMs = d.groundSpeed / 3.6; // km/h -> m/s
    if (!d.hasFix || vsMs.isNaN || gsMs.isNaN || vsMs >= -0.1) return '—';
    final ratio = gsMs / -vsMs;
    if (!ratio.isFinite || ratio <= 0) return '—';
    if (ratio >= 100) return '99+';
    return formatDecimalValue(ratio, autoDecimals: 1, range: precision);
  }

  /// Difference between the barometric and GPS altitudes, in meters. Requires
  /// both to be present, otherwise "—".
  static String _altitudeDelta(FlightData d, DecimalPlaceRange? precision) {
    final baro = d.baroAltitude;
    final gps = d.gpsAltitude;
    if (baro == null || gps == null) return '—';
    final delta = baro - gps;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${formatDecimalValue(delta, autoDecimals: 1, range: precision)}';
  }

  /// Total-energy altitude: the altitude plus the kinetic-energy equivalent
  /// height (v² / 2g) from the ground speed. Gives a speed-compensated height
  /// that is less sensitive to pull-ups/dives.
  static String _totalEnergyAltitude(
    FlightData d,
    DecimalPlaceRange? precision,
  ) {
    final vMs = d.groundSpeed / 3.6; // km/h -> m/s
    const g = 9.80665;
    final te = d.altitude + (vMs * vMs) / (2 * g);
    return formatDecimalValue(te, autoDecimals: 1, range: precision);
  }

  /// 8-point compass label for a bearing in degrees.
  static String _cardinal8(double degrees, {bool chinese = false}) {
    const englishLabels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    const chineseLabels = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    final labels = chinese ? chineseLabels : englishLabels;
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized / 45.0).round()) % 8;
    return labels[index];
  }
}

/// One displayed key/value line.
class _Row {
  final String label;
  final String value;
  final String? unit;
  final bool highlight;

  _Row(this.label, this.value, {this.unit, this.highlight = false});
}

/// A full-width section header inside the monitor list (no value column).
class _Section extends _Row {
  _Section(String label) : super(label, '');
}
