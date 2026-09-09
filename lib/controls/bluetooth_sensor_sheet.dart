import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/ble/ble_sensor_service.dart';
import '../data/ble/sensor_readings.dart';

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

  @override
  void initState() {
    super.initState();
    _svc.init();
  }

  @override
  void dispose() {
    _svc.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(Icons.bluetooth, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Bluetooth Sensor',
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
                animation: _svc,
                builder: (context, _) {
                  if (!_svc.supported) {
                    return _buildUnsupported(theme);
                  }
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _sectionLabel(theme, 'Options'),
                      const SizedBox(height: 8),
                      _optionsCard(theme),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Connection'),
                      const SizedBox(height: 8),
                      _adapterBanner(theme),
                      if (_svc.error != null) ...[
                        const SizedBox(height: 8),
                        _errorBanner(theme, _svc.error!),
                      ],
                      const SizedBox(height: 8),
                      _connectionCard(theme),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Live data fields'),
                      const SizedBox(height: 8),
                      _readingsCard(theme, _svc.readings),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Nearby devices'),
                      const SizedBox(height: 8),
                      _scanControls(theme),
                      const SizedBox(height: 8),
                      _scanList(theme),
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
  Widget _buildUnsupported(ThemeData theme) {
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
              'Bluetooth sensors are only available on iOS and Android.',
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
  Widget _optionsCard(ThemeData theme) {
    return _card(
      theme,
      [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Bluetooth sensor'),
          subtitle: const Text('Scan and connect to external sensors'),
          value: _svc.enabled,
          onChanged: (v) => _svc.setEnabled(v),
        ),
      ],
    );
  }

  Widget _adapterBanner(ThemeData theme) {
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
          Text('Bluetooth: ${_svc.adapterState.name}',
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

  Widget _connectionCard(ThemeData theme) {
    final connected = _svc.isConnected;
    final connecting = _svc.hasSavedDevice && !connected;

    if (!_svc.hasSavedDevice) {
      return _card(theme, [
        _row(theme, Icons.link_off, 'Status', 'No device selected',
            valueColor: theme.colorScheme.onSurfaceVariant),
      ]);
    }

    final statusColor =
        connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return _card(theme, [
      _row(
        theme,
        connected ? Icons.link : Icons.link_off,
        _svc.selectedName ?? _svc.selectedId ?? 'Device',
        connected
            ? 'Connected'
            : (connecting ? 'Connecting…' : 'Disconnected'),
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
                label: const Text('Connect'),
              ),
            if (connected)
              TextButton.icon(
                onPressed: () => _svc.disconnect(),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Disconnect'),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _svc.forgetDevice(),
              icon: Icon(Icons.delete_outline,
                  size: 18, color: theme.colorScheme.error),
              label: Text('Forget',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── All data fields ─────────────────────────────────────────────────────
  Widget _readingsCard(ThemeData theme, SensorReadings r) {
    // Show every known field; unavailable ones render as "—".
    final rows = <Widget>[
      _fieldRow(theme, Icons.terrain, 'Altitude',
          r.altitudeM?.toStringAsFixed(0), 'm'),
      _fieldRow(theme, Icons.swap_vert, 'Vertical speed',
          r.varioMs?.toStringAsFixed(1), 'm/s'),
      _fieldRow(theme, Icons.compress, 'Pressure',
          r.pressureHpa?.toStringAsFixed(2), 'hPa'),
      _fieldRow(theme, Icons.thermostat, 'Temperature',
          r.temperatureC?.toStringAsFixed(1), '°C'),
      _fieldRow(theme, Icons.favorite, 'Heart rate',
          r.heartRate?.toString(), 'bpm'),
      _fieldRow(theme, Icons.battery_full, 'Battery',
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
  Widget _scanControls(ThemeData theme) {
    final scanning = _svc.isScanning;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: !_svc.enabled
              ? null
              : (scanning ? () => _svc.stopScan() : () => _svc.startScan()),
          icon: Icon(scanning ? Icons.stop : Icons.search, size: 18),
          label: Text(scanning ? 'Stop' : 'Scan'),
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

  Widget _scanList(ThemeData theme) {
    final results = _svc.scanResults;
    if (results.isEmpty) {
      return _card(theme, [
        _row(theme, Icons.search_off, 'Devices',
            _svc.enabled ? 'Tap Scan' : 'Enable first',
            valueColor: theme.colorScheme.onSurfaceVariant),
      ]);
    }
    final children = <Widget>[];
    for (var i = 0; i < results.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(_scanTile(theme, results[i]));
    }
    return _card(theme, children);
  }

  Widget _scanTile(ThemeData theme, ScanResult r) {
    final name = r.advertisementData.advName.trim().isNotEmpty
        ? r.advertisementData.advName
        : (r.device.platformName.isNotEmpty
            ? r.device.platformName
            : '(unknown)');
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
            Text('${r.rssi} dBm',
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
