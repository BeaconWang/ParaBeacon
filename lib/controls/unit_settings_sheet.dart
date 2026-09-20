import 'package:flutter/material.dart';

import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';

Future<void> showUnitSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _UnitSettingsSheet(),
  );
}

class _UnitSettingsSheet extends StatelessWidget {
  const _UnitSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UnitSettings.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.straighten, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(l10n.units, style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.unitsSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final dimension in UnitDimension.values) ...[
                    _UnitChoiceGroup(
                      dimension: dimension,
                      title: _dimensionLabel(l10n, dimension),
                      onChanged: (unit) =>
                          UnitSettings.instance.setDefault(dimension, unit),
                    ),
                    if (dimension != UnitDimension.values.last)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _dimensionLabel(AppLocalizations l10n, UnitDimension dimension) {
    return switch (dimension) {
      UnitDimension.altitude => l10n.unitAltitude,
      UnitDimension.speed => l10n.unitSpeed,
      UnitDimension.verticalSpeed => l10n.unitVerticalSpeed,
      UnitDimension.distance => l10n.unitDistance,
      UnitDimension.pressure => l10n.unitPressure,
      UnitDimension.temperature => l10n.unitTemperature,
    };
  }
}

class _UnitChoiceGroup extends StatelessWidget {
  final UnitDimension dimension;
  final String title;
  final ValueChanged<String> onChanged;

  const _UnitChoiceGroup({
    required this.dimension,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = UnitSettings.instance.defaultUnit(dimension);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dimension.choices.map((unit) {
            return ChoiceChip(
              label: Text(_unitLabel(l10n, dimension, unit)),
              selected: selected == unit,
              onSelected: (_) => onChanged(unit),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _unitLabel(
    AppLocalizations l10n,
    UnitDimension dimension,
    String unit,
  ) {
    return switch ((dimension, unit)) {
      (UnitDimension.altitude, 'm') => l10n.unitMeters,
      (UnitDimension.altitude, 'ft') => l10n.unitFeet,
      (UnitDimension.speed, 'kmh') => l10n.unitKilometersPerHour,
      (UnitDimension.speed, 'ms') => l10n.unitMetersPerSecond,
      (UnitDimension.speed, 'mph') => l10n.unitMilesPerHour,
      (UnitDimension.speed, 'kn') => l10n.unitKnots,
      (UnitDimension.verticalSpeed, 'ms') => l10n.unitMetersPerSecond,
      (UnitDimension.verticalSpeed, 'fpm') => l10n.unitFeetPerMinute,
      (UnitDimension.distance, 'auto') => l10n.unitAutomaticDistance,
      (UnitDimension.distance, 'km') => l10n.unitKilometers,
      (UnitDimension.distance, 'mi') => l10n.unitMiles,
      (UnitDimension.distance, 'm') => l10n.unitMeters,
      (UnitDimension.distance, 'ft') => l10n.unitFeet,
      (UnitDimension.pressure, 'hpa') => l10n.unitHectopascals,
      (UnitDimension.pressure, 'inhg') => l10n.unitInchesOfMercury,
      (UnitDimension.temperature, 'c') => l10n.unitCelsius,
      (UnitDimension.temperature, 'f') => l10n.unitFahrenheit,
      _ => UnitValues.label(dimension, unit),
    };
  }
}
