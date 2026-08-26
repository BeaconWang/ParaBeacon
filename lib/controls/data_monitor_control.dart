import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';

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
    final d = FlightDataProvider.of(context);

    final rows = <_Row>[
      _Row('Fix', d.hasFix ? 'YES' : 'NO', highlight: d.hasFix),
      _Row('Vertical speed', _fmt(d.verticalSpeed, 2), unit: 'm/s'),
      _Row('Ground speed', _fmt(d.groundSpeed, 1), unit: 'km/h'),
      _Row('Altitude', _fmt(d.altitude, 1), unit: 'm'),
      _Row('Baro altitude', _fmtN(d.baroAltitude, 1), unit: 'm'),
      _Row('GPS altitude', _fmtN(d.gpsAltitude, 1), unit: 'm'),
      _Row('Latitude', _fmt(d.latitude, 6), unit: '°'),
      _Row('Longitude', _fmt(d.longitude, 6), unit: '°'),
      _Row('Heading', _fmt(d.heading, 0), unit: '°'),
      _Row('Bearing', _fmtN(d.bearing, 0), unit: '°'),
      _Row('GPS accuracy', _fmtN(d.gpsAccuracy, 1), unit: 'm'),
      _Row('Satellites', d.satellites?.toString() ?? '—'),
      _Row('Wind speed', _fmt(d.windSpeed, 1), unit: 'km/h'),
      _Row('Wind direction', _fmt(d.windDirection, 0), unit: '°'),
      _Row('Pressure', _fmtN(d.pressure, 1), unit: 'hPa'),
      _Row('Temperature', _fmtN(d.temperature, 1), unit: '°C'),
      _Row('Battery', d.battery != null ? '${d.battery}' : '—', unit: '%'),
      _Row('Heart rate', d.heartRate != null ? '${d.heartRate}' : '—',
          unit: 'bpm'),
      _Row('Timestamp', _fmtTime(d.timestamp)),
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
                'Data Monitor',
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
                'LIVE',
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

  static String _fmt(double v, int decimals) => v.toStringAsFixed(decimals);

  static String _fmtN(double? v, int decimals) =>
      v == null ? '—' : v.toStringAsFixed(decimals);

  static String _fmtTime(DateTime? t) {
    if (t == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
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
