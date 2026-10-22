import 'package:flutter/material.dart';

import '../data/color_palette_settings.dart';
import '../l10n/app_localizations.dart';

String _schemeName(AppLocalizations l10n, String id) => switch (id) {
  'high-saturation' => l10n.colorPaletteSchemeHighSaturation,
  'macaron' => l10n.colorPaletteSchemeMacaron,
  'morandi' => l10n.colorPaletteSchemeMorandi,
  'earth' => l10n.colorPaletteSchemeEarth,
  'dark-tech' => l10n.colorPaletteSchemeDarkTech,
  'maldives-ocean' => l10n.colorPaletteSchemeMaldivesOcean,
  'forest' => l10n.colorPaletteSchemeForest,
  'sunset' => l10n.colorPaletteSchemeSunset,
  'lavender' => l10n.colorPaletteSchemeLavender,
  'nordic' => l10n.colorPaletteSchemeNordic,
  'desert' => l10n.colorPaletteSchemeDesert,
  'sakura' => l10n.colorPaletteSchemeSakura,
  'glacier' => l10n.colorPaletteSchemeGlacier,
  _ => id,
};

Future<void> showColorPaletteSettingsSheet(BuildContext context) async {
  await ColorPaletteSettings.instance.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ColorPaletteSettingsSheet(),
  );
}

class _ColorPaletteSettingsSheet extends StatelessWidget {
  const _ColorPaletteSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ColorPaletteSettings.instance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: AnimatedBuilder(
          animation: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.colorPalettePreferencesTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.colorPaletteSettingsDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.colorPaletteSchemeLabel,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settings.schemeId,
                    isExpanded: true,
                    items: [
                      for (final preset in ColorPaletteSettings.presets)
                        DropdownMenuItem(
                          value: preset.id,
                          child: Text(_schemeName(l10n, preset.id)),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      settings.previewScheme(id);
                      settings.setScheme(id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(l10n.colorPaletteCountLabel)),
                  Text(
                    l10n.colorPaletteSettingsCount(settings.colorCount),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: settings.colorCount.toDouble(),
                min: ColorPaletteSettings.minColorCount.toDouble(),
                max: ColorPaletteSettings.maxColorCount.toDouble(),
                divisions:
                    ColorPaletteSettings.maxColorCount -
                    ColorPaletteSettings.minColorCount,
                label: settings.colorCount.toString(),
                onChanged: (value) => settings.previewColorCount(value.round()),
                onChangeEnd: (value) => settings.setColorCount(value.round()),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in settings.visiblePresetColors)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
