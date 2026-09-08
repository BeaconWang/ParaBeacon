import 'dart:async';

import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';
import '../data/flight_state.dart';

/// Color state of a data value, mirroring XCTrack's value coloring.
enum ValueState { neutral, good, bad }

/// A generic "data control": a readout showing an optional title, a large
/// value, and a unit, colored by [ValueState].
///
/// This mirrors XCTrack's `ValueWidget` layout (title / value / units) used by
/// data widgets such as Vertical Speed, Ground Speed, Altitude, etc.
class DataValueControl extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final ValueState state;
  final bool showTitle;

  const DataValueControl({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.state = ValueState.neutral,
    this.showTitle = true,
  });

  Color _valueColor(ThemeData theme) {
    switch (state) {
      case ValueState.good:
        return const Color(0xFF4CD964); // climbing / positive
      case ValueState.bad:
        return const Color(0xFFFF6B6B); // sinking / negative
      case ValueState.neutral:
        return theme.colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the value font to the available space.
        final valueSize =
            (constraints.maxHeight * 0.42).clamp(16.0, 48.0).toDouble();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle)
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: _valueColor(theme),
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Vertical speed data control, inspired by XCTrack's `WVerticalSpeed`.
///
/// Displays vertical speed in m/s with color state: green when climbing
/// (>= 0), red when sinking hard (<= -1), neutral for gentle sink.
///
/// Reads from the unified [FlightDataProvider]. An optional [verticalSpeed]
/// override can be supplied (e.g. for tests/previews).
class VerticalSpeedControl extends StatelessWidget {
  /// Optional override for the vertical speed in m/s. When null the value is
  /// read from the shared flight-data source.
  final double? verticalSpeed;

  /// Whether to show the "Vertical Speed" title.
  final bool showTitle;

  const VerticalSpeedControl({
    super.key,
    this.verticalSpeed,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = verticalSpeed ?? FlightDataProvider.of(context).verticalSpeed;
    final ValueState state;
    if (v >= 0.0) {
      state = ValueState.good;
    } else if (v <= -1.0) {
      state = ValueState.bad;
    } else {
      state = ValueState.neutral;
    }
    return DataValueControl(
      title: 'Vertical Speed',
      value: '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
      unit: 'm/s',
      state: state,
      showTitle: showTitle,
    );
  }
}

/// Coordinate display format for [LocationControl].
enum LocationFormat {
  /// Decimal degrees, e.g. `46.51970°, 6.63230°`.
  decimal,

  /// Degrees / minutes / seconds, e.g. `46°31'10.9"N 6°37'56.3"E`.
  dms,
}

/// GPS location data control: shows the current latitude/longitude read from
/// the unified [FlightDataProvider].
///
/// Renders two stacked rows (latitude then longitude) so both fit legibly in a
/// data tile. When there is no GPS fix it shows a muted placeholder.
class LocationControl extends StatelessWidget {
  /// Coordinate display format.
  final LocationFormat format;

  /// Whether to show the "Location" title.
  final bool showTitle;

  /// Optional overrides (e.g. for tests/previews). When null the values are
  /// read from the shared flight-data source.
  final double? latitude;
  final double? longitude;
  final bool? hasFix;

  const LocationControl({
    super.key,
    this.format = LocationFormat.decimal,
    this.showTitle = true,
    this.latitude,
    this.longitude,
    this.hasFix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = FlightDataProvider.of(context);
    final lat = latitude ?? data.latitude;
    final lon = longitude ?? data.longitude;
    final fix = hasFix ?? data.hasFix;

    return LayoutBuilder(
      builder: (context, constraints) {
        final valueSize =
            (constraints.maxHeight * 0.24).clamp(12.0, 26.0).toDouble();
        final valueStyle = TextStyle(
          fontSize: valueSize,
          fontWeight: FontWeight.bold,
          height: 1.05,
          color: fix
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle)
              Text(
                'LOCATION',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: fix
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatLat(lat), style: valueStyle),
                          const SizedBox(height: 2),
                          Text(_formatLon(lon), style: valueStyle),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_off,
                              size: valueSize,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('No GPS fix', style: valueStyle),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatLat(double lat) {
    switch (format) {
      case LocationFormat.decimal:
        return '${lat.toStringAsFixed(5)}°';
      case LocationFormat.dms:
        return _toDms(lat, lat >= 0 ? 'N' : 'S');
    }
  }

  String _formatLon(double lon) {
    switch (format) {
      case LocationFormat.decimal:
        return '${lon.toStringAsFixed(5)}°';
      case LocationFormat.dms:
        return _toDms(lon, lon >= 0 ? 'E' : 'W');
    }
  }

  /// Formats [value] degrees as `D°M'S.s"` followed by the [hemisphere].
  static String _toDms(double value, String hemisphere) {
    final abs = value.abs();
    final deg = abs.floor();
    final minFull = (abs - deg) * 60.0;
    final min = minFull.floor();
    final sec = (minFull - min) * 60.0;
    return "$deg°${min.toString().padLeft(2, '0')}'"
        "${sec.toStringAsFixed(1).padLeft(4, '0')}\"$hemisphere";
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Additional data controls, inspired by XCTrack's dashboard field set.
//
// These are thin adapters around [DataValueControl] that read one derived
// value from the shared [FlightDataProvider] (or another app-wide source such
// as [FlightState] / wall clock) and format it with sensible defaults. When a
// value isn't available (no GPS fix, no sensor, no flight, …) they render a
// muted `--` placeholder instead of a misleading zero.
// ═══════════════════════════════════════════════════════════════════════════

/// Formats [d] as `H:MM:SS`. Used by the Flight Time control.
String _formatHms(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Converts a 0-360° bearing to an 8-point cardinal label (N, NE, …).
String _cardinal8(double degrees) {
  const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized / 45.0).round()) % 8;
  return labels[index];
}

/// Which source to draw the altitude from.
enum AltitudeSource {
  /// Effective altitude ([FlightData.altitude]) — baro if present, else GPS.
  auto,

  /// GPS-only geometric altitude.
  gps,

  /// Barometric altitude only.
  baro,
}

/// Altitude readout in meters. Reads the "effective" altitude from
/// [FlightDataProvider] by default; can be pinned to GPS or baro via [source].
class AltitudeControl extends StatelessWidget {
  final bool showTitle;
  final AltitudeSource source;

  const AltitudeControl({
    super.key,
    this.showTitle = true,
    this.source = AltitudeSource.auto,
  });

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    final double? raw;
    final String title;
    switch (source) {
      case AltitudeSource.auto:
        // The "effective" altitude is always non-null (defaults to 0), but is
        // only meaningful once we have any positioning fix or baro reading.
        raw = data.hasFix || data.baroAltitude != null ? data.altitude : null;
        title = 'Altitude';
        break;
      case AltitudeSource.gps:
        raw = data.gpsAltitude;
        title = 'GPS Altitude';
        break;
      case AltitudeSource.baro:
        raw = data.baroAltitude;
        title = 'Baro Altitude';
        break;
    }
    return DataValueControl(
      title: title,
      value: raw == null ? '--' : raw.toStringAsFixed(0),
      unit: 'm',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Highest [FlightData.altitude] observed since this control was mounted.
///
/// Tracked locally (per-widget) so different pages can reset independently.
/// A full app-wide "max altitude for the current flight" would need to hook
/// into [FlightRecorder]; keeping it widget-local avoids that coupling while
/// still giving pilots a useful readout during a flight.
class MaxAltitudeControl extends StatefulWidget {
  final bool showTitle;

  const MaxAltitudeControl({super.key, this.showTitle = true});

  @override
  State<MaxAltitudeControl> createState() => _MaxAltitudeControlState();
}

class _MaxAltitudeControlState extends State<MaxAltitudeControl> {
  double _max = double.negativeInfinity;

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    // Only fold in a fresh sample once we have a real fix so the display
    // isn't dominated by the initial 0-altitude default before any GPS.
    if ((data.hasFix || data.baroAltitude != null) &&
        data.altitude.isFinite &&
        data.altitude > _max) {
      _max = data.altitude;
    }
    final hasSample = _max.isFinite;
    return DataValueControl(
      title: 'Max Altitude',
      value: hasSample ? _max.toStringAsFixed(0) : '--',
      unit: 'm',
      state: ValueState.neutral,
      showTitle: widget.showTitle,
    );
  }
}

/// Ground speed in km/h.
class GroundSpeedControl extends StatelessWidget {
  final bool showTitle;

  const GroundSpeedControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    // Ground speed is meaningful only with a GPS fix; without one, the
    // simulator-defaulted 0 would be misleading.
    final hasValue = data.hasFix;
    return DataValueControl(
      title: 'Ground Speed',
      value: hasValue ? data.groundSpeed.toStringAsFixed(0) : '--',
      unit: 'km/h',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Instantaneous glide ratio (L/D): horizontal speed divided by sink rate.
///
/// Only defined while sinking (vertical speed < 0); climbs and level flight
/// render `--`, matching XCTrack.
class GlideRatioControl extends StatelessWidget {
  final bool showTitle;

  const GlideRatioControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    // Ground speed is km/h, vertical speed is m/s. Convert to identical
    // units (m/s) before dividing so the ratio is dimensionless.
    final vsMs = data.verticalSpeed;
    final gsMs = data.groundSpeed / 3.6;
    final String value;
    if (!data.hasFix || vsMs.isNaN || gsMs.isNaN) {
      value = '--';
    } else if (vsMs >= -0.1) {
      // Climb or near-level flight: glide ratio is undefined (or absurdly
      // large). Show '--' rather than saturating the display.
      value = '--';
    } else {
      final ratio = gsMs / -vsMs;
      if (!ratio.isFinite || ratio <= 0) {
        value = '--';
      } else if (ratio >= 100) {
        value = '99+';
      } else {
        value = ratio.toStringAsFixed(1);
      }
    }
    return DataValueControl(
      title: 'Glide',
      value: value,
      unit: '',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Direction-of-travel readout in degrees or cardinal points.
class HeadingControl extends StatelessWidget {
  final bool showTitle;

  /// When true render `N`, `NE`, … instead of the raw degree value.
  final bool cardinal;

  const HeadingControl({
    super.key,
    this.showTitle = true,
    this.cardinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    final hasValue = data.hasFix;
    final String value;
    if (!hasValue) {
      value = '--';
    } else if (cardinal) {
      value = _cardinal8(data.heading);
    } else {
      value = data.heading.round().toString().padLeft(3, '0');
    }
    return DataValueControl(
      title: 'Heading',
      value: value,
      unit: cardinal ? '' : '°',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Wind speed in km/h (as read from the flight-data feed).
class WindSpeedControl extends StatelessWidget {
  final bool showTitle;

  const WindSpeedControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    return DataValueControl(
      title: 'Wind Speed',
      value: data.windSpeed.toStringAsFixed(0),
      unit: 'km/h',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Wind direction (direction wind is coming *from*), degrees or cardinal.
class WindDirectionControl extends StatelessWidget {
  final bool showTitle;
  final bool cardinal;

  const WindDirectionControl({
    super.key,
    this.showTitle = true,
    this.cardinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    final String value;
    if (cardinal) {
      value = _cardinal8(data.windDirection);
    } else {
      value = data.windDirection.round().toString().padLeft(3, '0');
    }
    return DataValueControl(
      title: 'Wind Dir',
      value: value,
      unit: cardinal ? '' : '°',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Barometric pressure in hPa. Shows `--` when no baro sensor contributes.
class PressureControl extends StatelessWidget {
  final bool showTitle;

  const PressureControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final p = FlightDataProvider.of(context).pressure;
    return DataValueControl(
      title: 'Pressure',
      value: p == null ? '--' : p.toStringAsFixed(1),
      unit: 'hPa',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Outside air temperature in °C.
class TemperatureControl extends StatelessWidget {
  final bool showTitle;

  const TemperatureControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final t = FlightDataProvider.of(context).temperature;
    return DataValueControl(
      title: 'Temperature',
      value: t == null ? '--' : t.toStringAsFixed(1),
      unit: '°C',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Connected-sensor battery level (0-100 %).
class SensorBatteryControl extends StatelessWidget {
  final bool showTitle;

  const SensorBatteryControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final b = FlightDataProvider.of(context).battery;
    // Colour the readout: green when comfortable, red when critical, neutral
    // otherwise — mirrors XCTrack's battery cell colouring.
    ValueState state = ValueState.neutral;
    if (b != null) {
      if (b <= 15) {
        state = ValueState.bad;
      } else if (b >= 60) {
        state = ValueState.good;
      }
    }
    return DataValueControl(
      title: 'Sensor Battery',
      value: b == null ? '--' : b.toString(),
      unit: '%',
      state: state,
      showTitle: showTitle,
    );
  }
}

/// Heart rate in bpm (from a paired HR strap).
class HeartRateControl extends StatelessWidget {
  final bool showTitle;

  const HeartRateControl({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final hr = FlightDataProvider.of(context).heartRate;
    return DataValueControl(
      title: 'Heart Rate',
      value: hr == null ? '--' : hr.toString(),
      unit: 'bpm',
      state: ValueState.neutral,
      showTitle: showTitle,
    );
  }
}

/// Wall-clock readout (HH:MM by default, or HH:MM:SS if [showSeconds]).
///
/// Ticks itself once per second (independent of the flight-data feed) so it
/// stays live even when the simulator is off and there's no incoming sensor
/// data.
class ClockControl extends StatefulWidget {
  final bool showTitle;
  final bool showSeconds;

  const ClockControl({
    super.key,
    this.showTitle = true,
    this.showSeconds = false,
  });

  @override
  State<ClockControl> createState() => _ClockControlState();
}

class _ClockControlState extends State<ClockControl> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return DataValueControl(
      title: 'Clock',
      value: widget.showSeconds ? '$hh:$mm:$ss' : '$hh:$mm',
      unit: '',
      state: ValueState.neutral,
      showTitle: widget.showTitle,
    );
  }
}

/// Elapsed time since take-off. Reads from the shared [FlightState] singleton
/// so every placed instance stays in sync with the Flight button(s).
///
/// Renders `--:--:--` while no flight is in progress.
class FlightTimeControl extends StatefulWidget {
  final bool showTitle;

  const FlightTimeControl({super.key, this.showTitle = true});

  @override
  State<FlightTimeControl> createState() => _FlightTimeControlState();
}

class _FlightTimeControlState extends State<FlightTimeControl> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Rebuild once per second while flying so the value ticks up smoothly.
    // Also rebuild when the flight state itself changes (start/stop) so we
    // switch between the running clock and the placeholder immediately.
    FlightState.instance.addListener(_onFlightStateChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && FlightState.instance.isFlying) setState(() {});
    });
  }

  void _onFlightStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FlightState.instance.removeListener(_onFlightStateChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = FlightState.instance;
    return DataValueControl(
      title: 'Flight Time',
      value: state.isFlying ? _formatHms(state.elapsed) : '--:--:--',
      unit: '',
      state: ValueState.neutral,
      showTitle: widget.showTitle,
    );
  }
}

