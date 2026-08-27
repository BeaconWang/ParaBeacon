import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';
import '../data/raw_flight_data_source.dart';

/// A debug control that lets you manually drive the shared flight data with a
/// stack of sliders — one per sensor field.
///
/// Whenever a slider is enabled its value is written into the source's
/// [FlightDataOverride], which takes the highest priority over the raw
/// (simulated / bluetooth) sensor stream. Toggling a field off clears its
/// override so the real value flows through again.
///
/// This is intended for development / bench-testing a bluetooth sensor feed
/// without needing the physical device to report specific values.
class DebugSensorControl extends StatefulWidget {
  const DebugSensorControl({super.key});

  @override
  State<DebugSensorControl> createState() => _DebugSensorControlState();
}

/// Static description of one adjustable sensor field.
class _Field {
  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;

  const _Field({
    required this.key,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
  });
}

const List<_Field> _fields = [
  _Field(key: 'verticalSpeed', label: 'Vertical speed', unit: 'm/s', min: -10, max: 10),
  _Field(key: 'altitude', label: 'Altitude', unit: 'm', min: 0, max: 5000),
  _Field(key: 'groundSpeed', label: 'Ground speed', unit: 'km/h', min: 0, max: 120),
  _Field(key: 'heading', label: 'Heading', unit: '°', min: 0, max: 360),
  _Field(key: 'windSpeed', label: 'Wind speed', unit: 'km/h', min: 0, max: 80),
  _Field(key: 'windDirection', label: 'Wind dir', unit: '°', min: 0, max: 360),
];

class _DebugSensorControlState extends State<DebugSensorControl> {
  /// Whether each field is currently being forced.
  final Map<String, bool> _enabled = {};

  /// The current slider value for each field.
  final Map<String, double> _values = {};

  RawFlightDataSource? _source;

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _enabled[f.key] = false;
      _values[f.key] = ((f.min + f.max) / 2);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _source = FlightDataProvider.sourceOf(context);
    // Seed slider values from the current raw data the first time we attach so
    // enabling a field starts from a sensible reading.
    if (!_seeded) {
      _seeded = true;
      final raw = _source!.rawData;
      _values['verticalSpeed'] = raw.verticalSpeed;
      _values['altitude'] = raw.altitude;
      _values['groundSpeed'] = raw.groundSpeed;
      _values['heading'] = raw.heading;
      _values['windSpeed'] = raw.windSpeed;
      _values['windDirection'] = raw.windDirection;
    }
  }

  bool _seeded = false;

  @override
  void dispose() {
    // Remove any overrides this control installed so it doesn't keep forcing
    // values after being deleted.
    _source?.clearOverride();
    super.dispose();
  }

  /// Builds a [FlightDataOverride] from the currently enabled fields and pushes
  /// it to the source immediately (highest priority).
  void _applyOverride() {
    final source = _source;
    if (source == null) return;

    double? v(String key) => (_enabled[key] ?? false) ? _values[key] : null;

    source.setOverride(FlightDataOverride(
      verticalSpeed: v('verticalSpeed'),
      altitude: v('altitude'),
      groundSpeed: v('groundSpeed'),
      heading: v('heading'),
      windSpeed: v('windSpeed'),
      windDirection: v('windDirection'),
    ));
  }

  void _toggle(String key, bool on) {
    setState(() => _enabled[key] = on);
    _applyOverride();
  }

  void _setValue(String key, double value) {
    setState(() => _values[key] = value);
    // Only push when this field is active — its value has the highest priority.
    if (_enabled[key] ?? false) _applyOverride();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anyActive = _enabled.values.any((e) => e);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.bluetooth_searching,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Debug Sensor',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (anyActive)
              GestureDetector(
                onTap: () {
                  setState(() {
                    for (final f in _fields) {
                      _enabled[f.key] = false;
                    }
                  });
                  _source?.clearOverride();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'RESET',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _fields.length,
            itemBuilder: (context, index) =>
                _buildFieldRow(context, theme, _fields[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow(BuildContext context, ThemeData theme, _Field field) {
    final on = _enabled[field.key] ?? false;
    final value = (_values[field.key] ?? field.min).clamp(field.min, field.max);
    final decimals = (field.max - field.min) <= 30 ? 1 : 0;
    final valueColor =
        on ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: on,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => _toggle(field.key, v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                field.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: on
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(decimals)} ${field.unit}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: valueColor,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 12),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.toDouble(),
            min: field.min,
            max: field.max,
            // Disabling the slider when the field is off makes it clear that
            // the raw sensor value is flowing through.
            onChanged: on ? (v) => _setValue(field.key, v) : null,
          ),
        ),
      ],
    );
  }
}
