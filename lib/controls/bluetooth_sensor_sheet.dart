import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/ble/ble_sensor_service.dart';
import '../data/ble/sensor_readings.dart';
import '../data/sensors/internal_sensor_service.dart';
import '../l10n/app_localizations.dart';

/// Opens the Bluetooth sensor screen as a modal bottom sheet.
///
/// On unsupported platforms (Windows/desktop/web) it shows an informational
/// notice instead of scan/connect controls — no BLE code runs there.
Future<void> showBluetoothSensorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _BluetoothSensorSheet(),
  );
}

class _BluetoothSensorSheet extends StatefulWidget {
  const _BluetoothSensorSheet();

  @override
  State<_BluetoothSensorSheet> createState() => _BluetoothSensorSheetState();
}

class _BluetoothSensorSheetState extends State<_BluetoothSensorSheet> {
  final BleSensorService _svc = BleSensorService.instance;
  final InternalSensorService _internal = InternalSensorService.instance;

  @override
  void initState() {
    super.initState();
    _svc.init();
    _internal.init();
  }

  @override
  void dispose() {
    _svc.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.sensors, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(l10n.sensorTitle,
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_svc, _internal]),
                builder: (context, _) {
                  if (!_svc.supported) {
                    return _buildUnsupported(theme, l10n);
                  }
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _sectionLabel(theme, l10n.sensorOptions),
                      const SizedBox(height: 8),
                      _optionsCard(theme, l10n),
                      const SizedBox(height: 20),
                      if (_internal.supported) ...[
                        _sectionLabel(theme, l10n.sensorInternalSection),
                        const SizedBox(height: 8),
                        _internalSensorCard(theme, l10n),
                        const SizedBox(height: 20),
                      ],
                      _sectionLabel(theme, l10n.sensorConnection),
                      const SizedBox(height: 8),
                      _adapterBanner(theme, l10n),
                      if (_svc.error != null) ...[
                        const SizedBox(height: 8),
                        _errorBanner(theme, _svc.error!),
                      ],
                      const SizedBox(height: 8),
                      _connectionCard(theme, l10n),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.sensorLiveDataFields),
                      const SizedBox(height: 8),
                      _readingsCard(theme, l10n, _svc.readings),
                      if (_svc.isConnected) ...[
                        const SizedBox(height: 20),
                        _sectionLabel(theme, l10n.sensorExtCalibrationSection),
                        const SizedBox(height: 8),
                        _externalCalibrationCard(theme, l10n),
                      ],
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.sensorNearbyDevices),
                      const SizedBox(height: 8),
                      _scanControls(theme, l10n),
                      const SizedBox(height: 8),
                      _scanList(theme, l10n),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Unsupported platform ──────────────────────────────────────────────────
  Widget _buildUnsupported(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              l10n.sensorUnsupported,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Options ─────────────────────────────────────────────────────────────
  Widget _optionsCard(ThemeData theme, AppLocalizations l10n) {
    final internalAvailable = _internal.supported && _internal.available;
    return _card(
      theme,
      [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sensorEnableBluetooth),
          subtitle: Text(l10n.sensorEnableBluetoothSubtitle),
          value: _svc.enabled,
          onChanged: (v) => _svc.setEnabled(v),
        ),
        if (_internal.supported) ...[
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.sensorPreferInternal),
            subtitle: Text(
              internalAvailable
                  ? l10n.sensorPreferInternalSubtitle
                  : l10n.sensorNoInternalBarometer,
            ),
            // Only usable when the device actually has a barometer; reflect the
            // real state so the toggle greys out when there is nothing to use.
            value: _internal.enabled && internalAvailable,
            onChanged:
                internalAvailable ? (v) => _internal.setEnabled(v) : null,
          ),
        ],
      ],
    );
  }

  // ── Internal sensor (device barometer) ────────────────────────────────────
  Widget _internalSensorCard(ThemeData theme, AppLocalizations l10n) {
    final available = _internal.available;
    final active = _internal.isActiveFeed;
    final r = _internal.readings;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    if (!available) {
      statusColor = theme.colorScheme.onSurfaceVariant;
      statusIcon = Icons.sensors_off;
      statusText = l10n.sensorBarometerNotDetected;
    } else if (active) {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.sensors;
      statusText = l10n.sensorBarometerConnected;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant;
      statusIcon = Icons.sensors;
      statusText = l10n.sensorBarometerNotPreferred;
    }

    final children = <Widget>[
      _row(theme, statusIcon, l10n.sensorStatus, statusText,
          valueColor: statusColor),
    ];

    if (available) {
      children
        ..add(const Divider(height: 1))
        ..add(_fieldRow(theme, Icons.swap_vert, l10n.sensorFieldVerticalSpeed,
            r.varioMs?.toStringAsFixed(1), 'm/s'))
        ..add(const Divider(height: 1))
        ..add(_fieldRow(theme, Icons.terrain, l10n.sensorFieldAltitude,
            r.altitudeM?.toStringAsFixed(0), 'm'))
        ..add(const Divider(height: 1))
        ..add(_fieldRow(theme, Icons.compress, l10n.sensorFieldPressure,
            r.pressureHpa?.toStringAsFixed(2), 'hPa'))
        ..add(const Divider(height: 1))
        ..add(_fieldRow(theme, Icons.adjust, l10n.sensorFieldQnh,
            _internal.referencePressureHpa.toStringAsFixed(2), 'hPa'))
        ..add(const Divider(height: 1))
        ..add(_calibrationControls(theme, l10n));
    }

    return _card(theme, children);
  }

  // ── Barometer altitude calibration ────────────────────────────────────────
  //
  // Lets the user calibrate the barometric altimeter to a known altitude. The
  // service back-computes the sea-level reference pressure (QNH) so the derived
  // altitude reads correctly, and persists it.
  Widget _calibrationControls(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _internal.isCalibrated
                  ? l10n.sensorCalibrationCalibrated
                  : l10n.sensorCalibrationStandard,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_internal.isCalibrated)
            TextButton(
              onPressed: () => _internal.resetCalibration(),
              child: Text(l10n.sensorCalibrationReset),
            ),
          FilledButton.tonalIcon(
            onPressed: _internal.lastPressureHpa == null
                ? null
                : () => _openCalibrateDialog(
                      l10n,
                      currentAltitude: _internal.readings.altitudeM,
                      calibrate: _internal.calibrateToAltitude,
                    ),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(l10n.sensorCalibrate),
          ),
        ],
      ),
    );
  }

  /// Opens the "calibrate to a known altitude" dialog. [currentAltitude]
  /// pre-fills the field; [calibrate] applies the entered altitude to the
  /// relevant sensor and returns whether it succeeded.
  Future<void> _openCalibrateDialog(
    AppLocalizations l10n, {
    required double? currentAltitude,
    required Future<bool> Function(double altitudeM) calibrate,
  }) async {
    final controller = TextEditingController(
      text: currentAltitude == null ? '' : currentAltitude.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(l10n.sensorCalibrateTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sensorCalibrateDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.sensorCalibrateAltitudeLabel,
                      suffixText: 'm',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      final value = double.tryParse(controller.text.trim());
                      if (value != null) Navigator.of(context).pop(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    if (value == null) {
                      setLocalState(() => errorText = l10n.sensorCalibrateInvalid);
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null || !mounted) return;

    final ok = await calibrate(result);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sensorCalibrateFailed)),
      );
    }
  }

  // ── External sensor altitude calibration ──────────────────────────────────
  //
  // External varios report an altitude derived from their own pressure sensor,
  // which can read high/low versus a known field elevation. The app applies a
  // user-set additive offset (from calibrating to a known altitude) on top of
  // whatever the sensor reports, so the displayed altitude is correct.
  Widget _externalCalibrationCard(ThemeData theme, AppLocalizations l10n) {
    final calibrated = _svc.isAltitudeCalibrated;
    final offset = _svc.altitudeOffsetM;
    final hasAltitude = _svc.rawAltitudeM != null;

    return _card(theme, [
      _fieldRow(theme, Icons.terrain, l10n.sensorExtCalibrationCurrent,
          _svc.calibratedAltitudeM?.toStringAsFixed(0), 'm'),
      const Divider(height: 1),
      _fieldRow(
        theme,
        Icons.height,
        l10n.sensorFieldAltitudeOffset,
        calibrated ? '${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(0)}' : '0',
        'm',
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                calibrated
                    ? l10n.sensorExtCalibrationApplied
                    : l10n.sensorExtCalibrationNone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (calibrated)
              TextButton(
                onPressed: () => _svc.resetAltitudeCalibration(),
                child: Text(l10n.sensorCalibrationReset),
              ),
            FilledButton.tonalIcon(
              onPressed: !hasAltitude
                  ? null
                  : () => _openCalibrateDialog(
                        l10n,
                        currentAltitude: _svc.calibratedAltitudeM,
                        calibrate: _svc.calibrateToAltitude,
                      ),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(l10n.sensorCalibrate),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _adapterBanner(ThemeData theme, AppLocalizations l10n) {
    final on = _svc.isAdapterOn;
    final color = on ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(on ? Icons.bluetooth : Icons.bluetooth_disabled,
              color: color, size: 20),
          const SizedBox(width: 8),
          Text(l10n.sensorBluetoothState(_svc.adapterState.name),
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _errorBanner(ThemeData theme, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }

  Widget _connectionCard(ThemeData theme, AppLocalizations l10n) {
    final connected = _svc.isConnected;
    final connecting = _svc.hasSavedDevice && !connected;

    if (!_svc.hasSavedDevice) {
      return _card(theme, [
        _row(theme, Icons.link_off, l10n.sensorStatus,
            l10n.sensorNoDeviceSelected,
            valueColor: theme.colorScheme.onSurfaceVariant),
      ]);
    }

    final statusColor =
        connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return _card(theme, [
      _row(
        theme,
        connected ? Icons.link : Icons.link_off,
        _svc.selectedName ?? _svc.selectedId ?? l10n.sensorDevice,
        connected
            ? l10n.sensorConnected
            : (connecting ? l10n.sensorConnecting : l10n.sensorDisconnected),
        valueColor: statusColor,
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (!connected)
              TextButton.icon(
                onPressed: _svc.enabled && _svc.selectedId != null
                    ? () => _svc.connectToId(_svc.selectedId!)
                    : null,
                icon: const Icon(Icons.bluetooth_searching, size: 18),
                label: Text(l10n.sensorConnect),
              ),
            if (connected)
              TextButton.icon(
                onPressed: () => _svc.disconnect(),
                icon: const Icon(Icons.link_off, size: 18),
                label: Text(l10n.sensorDisconnect),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _svc.forgetDevice(),
              icon: Icon(Icons.delete_outline,
                  size: 18, color: theme.colorScheme.error),
              label: Text(l10n.sensorForget,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── All data fields ─────────────────────────────────────────────────────
  Widget _readingsCard(ThemeData theme, AppLocalizations l10n, SensorReadings r) {
    // Show every known field; unavailable ones render as "—".
    final rows = <Widget>[
      _fieldRow(theme, Icons.terrain, l10n.sensorFieldAltitude,
          r.altitudeM?.toStringAsFixed(0), 'm'),
      _fieldRow(theme, Icons.swap_vert, l10n.sensorFieldVerticalSpeed,
          r.varioMs?.toStringAsFixed(1), 'm/s'),
      _fieldRow(theme, Icons.compress, l10n.sensorFieldPressure,
          r.pressureHpa?.toStringAsFixed(2), 'hPa'),
      _fieldRow(theme, Icons.thermostat, l10n.sensorFieldTemperature,
          r.temperatureC?.toStringAsFixed(1), '°C'),
      _fieldRow(theme, Icons.favorite, l10n.sensorFieldHeartRate,
          r.heartRate?.toString(), 'bpm'),
      _fieldRow(theme, Icons.battery_full, l10n.sensorFieldBattery,
          r.batteryPct?.toString(), '%'),
    ];

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(rows[i]);
    }
    return _card(theme, children);
  }

  Widget _fieldRow(ThemeData theme, IconData icon, String label,
      String? value, String unit) {
    final available = value != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: available
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withAlpha(120)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            available ? '$value $unit' : '—',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: available
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan ────────────────────────────────────────────────────────────────
  Widget _scanControls(ThemeData theme, AppLocalizations l10n) {
    final scanning = _svc.isScanning;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: !_svc.enabled
              ? null
              : (scanning ? () => _svc.stopScan() : () => _svc.startScan()),
          icon: Icon(scanning ? Icons.stop : Icons.search, size: 18),
          label: Text(scanning ? l10n.sensorStop : l10n.sensorScan),
        ),
        const SizedBox(width: 12),
        if (scanning)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _scanList(ThemeData theme, AppLocalizations l10n) {
    final results = _svc.scanResults;
    if (results.isEmpty) {
      return _card(theme, [
        _row(theme, Icons.search_off, l10n.sensorDevices,
            _svc.enabled ? l10n.sensorTapScan : l10n.sensorEnableFirst,
            valueColor: theme.colorScheme.onSurfaceVariant),
      ]);
    }
    final children = <Widget>[];
    for (var i = 0; i < results.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(_scanTile(theme, l10n, results[i]));
    }
    return _card(theme, children);
  }

  Widget _scanTile(ThemeData theme, AppLocalizations l10n, ScanResult r) {
    final name = r.advertisementData.advName.trim().isNotEmpty
        ? r.advertisementData.advName
        : (r.device.platformName.isNotEmpty
            ? r.device.platformName
            : l10n.sensorUnknownDevice);
    return InkWell(
      onTap: () => _svc.connect(r.device, name: name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(_rssiIcon(r.rssi),
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.bodyMedium),
                  Text(r.device.remoteId.str,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            Text(l10n.sensorRssiDbm(r.rssi),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }

  IconData _rssiIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt;
    if (rssi >= -80) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  // ── Shared bits ───────────────────────────────────────────────────────────
  Widget _sectionLabel(ThemeData theme, String label) => Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _card(ThemeData theme, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  Widget _row(ThemeData theme, IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
