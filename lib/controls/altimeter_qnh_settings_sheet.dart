import 'package:flutter/material.dart';

import '../data/sensors/internal_sensor_service.dart';
import '../l10n/app_localizations.dart';

/// Opens the altimeter/QNH settings screen.
Future<void> showAltimeterQnhSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AltimeterQnhSettingsSheet(),
  );
}

class _AltimeterQnhSettingsSheet extends StatefulWidget {
  const _AltimeterQnhSettingsSheet();

  @override
  State<_AltimeterQnhSettingsSheet> createState() =>
      _AltimeterQnhSettingsSheetState();
}

class _AltimeterQnhSettingsSheetState
    extends State<_AltimeterQnhSettingsSheet> {
  final InternalSensorService _sensor = InternalSensorService.instance;

  @override
  void initState() {
    super.initState();
    _sensor.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _sensor,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.altimeterQnhSettings,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _statusCard(theme, l10n),
                const SizedBox(height: 16),
                _sectionLabel(theme, l10n.altimeterQnhCurrent),
                const SizedBox(height: 8),
                _card(theme, [
                  _valueRow(
                    theme,
                    Icons.adjust,
                    l10n.altimeterQnhManual,
                    '${_sensor.referencePressureHpa.toStringAsFixed(2)} hPa',
                  ),
                  const Divider(height: 1),
                  _valueRow(
                    theme,
                    Icons.compress,
                    l10n.sensorFieldPressure,
                    _sensor.lastPressureHpa == null
                        ? l10n.altimeterQnhNoReading
                        : '${_sensor.lastPressureHpa!.toStringAsFixed(2)} hPa',
                  ),
                  const Divider(height: 1),
                  _valueRow(
                    theme,
                    Icons.terrain,
                    l10n.sensorFieldAltitude,
                    _sensor.readings.altitudeM == null
                        ? l10n.altimeterQnhNoReading
                        : '${_sensor.readings.altitudeM!.toStringAsFixed(0)} m',
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel(theme, l10n.altimeterQnhCalibration),
                const SizedBox(height: 8),
                _card(theme, [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.altimeterQnhManual),
                    subtitle: Text(l10n.altimeterQnhManualDescription),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editQnh(l10n),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.sensorCalibrateTitle),
                    subtitle: Text(l10n.sensorCalibrateDescription),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _sensor.lastPressureHpa == null
                        ? null
                        : () => _calibrateToAltitude(l10n),
                  ),
                  if (_sensor.isCalibrated) ...[
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restart_alt),
                      title: Text(l10n.altimeterQnhReset),
                      subtitle: Text(l10n.sensorCalibrationStandard),
                      onTap: () => _sensor.resetCalibration(),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                Text(
                  l10n.altimeterQnhRange,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusCard(ThemeData theme, AppLocalizations l10n) {
    final available = _sensor.available;
    final enabled = _sensor.enabled;
    final color = available && enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final status = !available
        ? l10n.altimeterQnhSensorUnavailable
        : !enabled
            ? l10n.altimeterQnhSensorDisabled
            : l10n.sensorBarometerConnected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              available && enabled ? Icons.sensors : Icons.sensors_off,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(status)),
            Switch(
              value: enabled,
              onChanged: _sensor.supported ? _sensor.setEnabled : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(text, style: theme.textTheme.titleMedium);
  }

  Widget _card(ThemeData theme, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: children),
      ),
    );
  }

  Widget _valueRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }

  Future<void> _editQnh(AppLocalizations l10n) async {
    final controller = TextEditingController(
      text: _sensor.referencePressureHpa.toStringAsFixed(2),
    );
    String? error;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.altimeterQnhManualTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.altimeterQnhManualLabel,
              suffixText: 'hPa',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final parsed = _parseQnh(controller.text);
              if (parsed == null) {
                setState(() => error = l10n.altimeterQnhManualInvalid);
              } else {
                Navigator.of(context).pop(parsed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parseQnh(controller.text);
                if (parsed == null) {
                  setState(() => error = l10n.altimeterQnhManualInvalid);
                } else {
                  Navigator.of(context).pop(parsed);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final accepted = await _sensor.setReferencePressureHpa(value);
    if (!accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.altimeterQnhManualInvalid)),
      );
    }
  }

  double? _parseQnh(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value < 870 || value > 1085) {
      return null;
    }
    return value;
  }

  Future<void> _calibrateToAltitude(AppLocalizations l10n) async {
    final controller = TextEditingController(
      text: _sensor.readings.altitudeM?.toStringAsFixed(0) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sensorCalibrateTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: l10n.sensorCalibrateAltitudeLabel,
            suffixText: 'm',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed.isFinite) {
                Navigator.of(context).pop(parsed);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final accepted = await _sensor.calibrateToAltitude(value);
    if (!accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sensorCalibrateFailed)),
      );
    }
  }
}
