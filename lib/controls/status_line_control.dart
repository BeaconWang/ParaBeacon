import 'dart:async';

import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';
import '../data/flight_state.dart';

/// A compact horizontal status bar summarising the live system state, inspired
/// by XCTrack's "Status line" widget.
///
/// It renders a row of small icon + value cells covering the most useful
/// at-a-glance indicators:
///   * GPS fix quality (satellite count / accuracy)
///   * Sensor battery level
///   * Recording / flight state
///   * Wall clock
///
/// Cells that have no meaningful value (no fix, no battery sensor, …) render a
/// muted `--` rather than a misleading zero. The bar scales its icon/text size
/// to the tile height and lays the cells out evenly across the width.
class StatusLineControl extends StatefulWidget {
  const StatusLineControl({super.key});

  @override
  State<StatusLineControl> createState() => _StatusLineControlState();
}

class _StatusLineControlState extends State<StatusLineControl> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tick once per second so the clock and flight timer stay live even when no
    // fresh sensor data arrives.
    FlightState.instance.addListener(_onChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FlightState.instance.removeListener(_onChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = FlightDataProvider.of(context);
    final flight = FlightState.instance;

    // GPS cell.
    final gpsIcon = data.hasFix ? Icons.gps_fixed : Icons.gps_off;
    final String gpsValue;
    if (!data.hasFix) {
      gpsValue = '--';
    } else if (data.satellites != null) {
      gpsValue = '${data.satellites}';
    } else if (data.gpsAccuracy != null) {
      gpsValue = '${data.gpsAccuracy!.toStringAsFixed(0)}m';
    } else {
      gpsValue = 'OK';
    }
    final gpsColor = data.hasFix
        ? const Color(0xFF4CD964)
        : theme.colorScheme.onSurfaceVariant;

    // Battery cell.
    final battery = data.battery;
    final IconData battIcon;
    final Color battColor;
    if (battery == null) {
      battIcon = Icons.battery_unknown;
      battColor = theme.colorScheme.onSurfaceVariant;
    } else if (battery <= 15) {
      battIcon = Icons.battery_alert;
      battColor = const Color(0xFFFF6B6B);
    } else if (battery >= 80) {
      battIcon = Icons.battery_full;
      battColor = const Color(0xFF4CD964);
    } else {
      battIcon = Icons.battery_5_bar;
      battColor = theme.colorScheme.onSurface;
    }

    // Flight / recording cell.
    final flying = flight.isFlying;
    final flightIcon =
        flying ? Icons.flight_takeoff : Icons.flight_land_outlined;
    final flightValue = flying ? _formatHms(flight.elapsed) : '--:--';
    final flightColor = flying
        ? const Color(0xFF4CD964)
        : theme.colorScheme.onSurfaceVariant;

    // Clock cell.
    final now = DateTime.now();
    final clockValue =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 40.0;
        final iconSize = (h * 0.42).clamp(12.0, 32.0).toDouble();
        final textSize = (h * 0.30).clamp(9.0, 22.0).toDouble();

        Widget cell(IconData icon, String value, Color color) {
          return Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: color),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            cell(gpsIcon, gpsValue, gpsColor),
            cell(battIcon, battery == null ? '--' : '$battery%', battColor),
            cell(flightIcon, flightValue, flightColor),
            cell(Icons.access_time, clockValue,
                theme.colorScheme.onSurfaceVariant),
          ],
        );
      },
    );
  }

  /// Formats [d] as `H:MM` (hours:minutes) for a compact status readout.
  static String _formatHms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
