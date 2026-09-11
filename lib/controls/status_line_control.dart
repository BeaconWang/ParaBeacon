import 'dart:async';

import 'package:flutter/material.dart';

import '../data/ble/ble_sensor_service.dart';
import '../data/device_battery_service.dart';
import '../data/flight_data_provider.dart';
import '../data/flight_state.dart';
import 'data_value_control.dart' show formatWallClock;

/// A compact horizontal status bar summarising the live system state, inspired
/// by XCTrack's "Status line" widget.
///
/// It renders a row of small icon + value cells covering the most useful
/// at-a-glance indicators:
///   * GPS fix quality (satellite count / accuracy)
///   * Bluetooth sensor connection state
///   * Sensor battery level
///   * Device battery level + charging state
///   * Recording / flight state
///   * Wall clock
///
/// Cells that have no meaningful value (no fix, no battery sensor, …) render a
/// muted `--` rather than a misleading zero. The bar scales its icon/text size
/// to the tile height and lays the cells out evenly across the width.
///
/// Each cell can be individually shown or hidden via the control's settings
/// ([showGps], [showBluetooth], [showSensorBattery], [showDeviceBattery],
/// [showFlightTimer], [showClock]). The clock cell honors the 12/24-hour
/// preference ([use24Hour]).
class StatusLineControl extends StatefulWidget {
  final bool showGps;
  final bool showBluetooth;
  final bool showSensorBattery;
  final bool showDeviceBattery;
  final bool showFlightTimer;
  final bool showClock;

  /// When true the clock cell uses a 24-hour format, otherwise 12-hour AM/PM.
  final bool use24Hour;

  const StatusLineControl({
    super.key,
    this.showGps = true,
    this.showBluetooth = true,
    this.showSensorBattery = true,
    this.showDeviceBattery = true,
    this.showFlightTimer = true,
    this.showClock = true,
    this.use24Hour = true,
  });

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
    // Rebuild when the BLE connection state changes so the sensor icon updates
    // immediately on connect / disconnect.
    BleSensorService.instance.addListener(_onChanged);
    // Rebuild when the device battery level / charging state changes.
    DeviceBatteryService.instance.addListener(_onChanged);
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
    BleSensorService.instance.removeListener(_onChanged);
    DeviceBatteryService.instance.removeListener(_onChanged);
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

    // Bluetooth sensor cell. Distinguishes: connected (green), enabled but
    // waiting/disconnected (muted "searching"), disabled/unsupported (off).
    final ble = BleSensorService.instance;
    final IconData bleIcon;
    final Color bleColor;
    final String bleValue;
    if (!ble.supported) {
      bleIcon = Icons.bluetooth_disabled;
      bleColor = theme.colorScheme.onSurfaceVariant;
      bleValue = '--';
    } else if (ble.isConnected) {
      bleIcon = Icons.bluetooth_connected;
      bleColor = const Color(0xFF4CD964);
      bleValue = 'ON';
    } else if (ble.enabled) {
      bleIcon = Icons.bluetooth_searching;
      bleColor = theme.colorScheme.onSurfaceVariant;
      bleValue = '...';
    } else {
      bleIcon = Icons.bluetooth_disabled;
      bleColor = theme.colorScheme.onSurfaceVariant;
      bleValue = 'OFF';
    }

    // Sensor battery cell (from the connected BLE vario).
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

    // Device (phone/tablet) battery cell — shows the charge level and whether
    // the device is currently charging. When charging, a bolt icon is used and
    // the cell is tinted green regardless of level.
    final deviceBattery = DeviceBatteryService.instance;
    final int? devLevel = deviceBattery.level;
    final bool charging = deviceBattery.isCharging;
    final IconData devIcon;
    final Color devColor;
    if (charging) {
      devIcon = Icons.battery_charging_full;
      devColor = const Color(0xFF4CD964);
    } else if (devLevel == null) {
      devIcon = Icons.battery_unknown;
      devColor = theme.colorScheme.onSurfaceVariant;
    } else if (devLevel <= 15) {
      devIcon = Icons.battery_alert;
      devColor = const Color(0xFFFF6B6B);
    } else if (devLevel >= 80) {
      devIcon = Icons.battery_full;
      devColor = theme.colorScheme.onSurface;
    } else {
      devIcon = Icons.battery_5_bar;
      devColor = theme.colorScheme.onSurface;
    }
    // Append a charging marker to the value so the state is unambiguous even in
    // monochrome / high-contrast themes where the tint may be hard to read.
    final devValue = devLevel == null
        ? (charging ? '⚡' : '--')
        : '$devLevel%${charging ? ' ⚡' : ''}';

    // Flight / recording cell.
    final flying = flight.isFlying;
    final flightIcon =
        flying ? Icons.flight_takeoff : Icons.flight_land_outlined;
    final flightValue = flying ? _formatHms(flight.elapsed) : '--:--';
    final flightColor = flying
        ? const Color(0xFF4CD964)
        : theme.colorScheme.onSurfaceVariant;

    // Clock cell.
    final clockValue = formatWallClock(DateTime.now(),
        use24Hour: widget.use24Hour);

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

        final cells = <Widget>[
          if (widget.showGps) cell(gpsIcon, gpsValue, gpsColor),
          if (widget.showBluetooth) cell(bleIcon, bleValue, bleColor),
          if (widget.showSensorBattery)
            cell(battIcon, battery == null ? '--' : '$battery%', battColor),
          if (widget.showDeviceBattery) cell(devIcon, devValue, devColor),
          if (widget.showFlightTimer)
            cell(flightIcon, flightValue, flightColor),
          if (widget.showClock)
            cell(Icons.access_time, clockValue,
                theme.colorScheme.onSurfaceVariant),
        ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: cells,
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
