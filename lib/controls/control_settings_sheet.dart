import 'package:flutter/material.dart';

import 'control_settings.dart';
import 'placed_control.dart';

/// Shows a modal bottom sheet to edit a single control's settings.
///
/// Mutates [control.settings] live as the user changes values and calls
/// [onChanged] so the host can rebuild. Returns when dismissed.
Future<void> showControlSettingsSheet(
  BuildContext context, {
  required PlacedControl control,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ControlSettingsSheet(
      control: control,
      onChanged: onChanged,
    ),
  );
}

class _ControlSettingsSheet extends StatefulWidget {
  final PlacedControl control;
  final VoidCallback onChanged;

  const _ControlSettingsSheet({
    required this.control,
    required this.onChanged,
  });

  @override
  State<_ControlSettingsSheet> createState() => _ControlSettingsSheetState();
}

class _ControlSettingsSheetState extends State<_ControlSettingsSheet> {
  late final List<ControlSetting> _schema =
      settingsSchemaFor(widget.control.type.id);

  void _set(String key, dynamic value) {
    setState(() => widget.control.settings[key] = value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final control = widget.control;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(control.type.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${control.type.label} settings',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_schema.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'This control has no settings.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _schema.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildSettingTile(context, _schema[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, ControlSetting setting) {
    final control = widget.control;

    // Border color/width only take effect when `showBorder` is on. Grey out
    // those rows in that case so the user understands why toggling them has
    // no visible effect, but still let them edit the value ahead of time.
    final borderOff = !control.boolSetting('showBorder', fallback: true);
    final isBorderChild =
        setting.key == 'borderColor' || setting.key == 'borderWidth';
    final dimmed = isBorderChild && borderOff;
    final tile = _buildSettingTileBody(context, setting);
    if (!dimmed) return tile;
    return Opacity(opacity: 0.5, child: tile);
  }

  Widget _buildSettingTileBody(BuildContext context, ControlSetting setting) {
    final theme = Theme.of(context);
    final control = widget.control;

    switch (setting.kind) {
      case SettingKind.toggle:
        final value = control.boolSetting(
          setting.key,
          fallback: setting.defaultValue as bool,
        );
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(setting.label),
          value: value,
          onChanged: (v) => _set(setting.key, v),
        );

      case SettingKind.slider:
        final value = control.doubleSetting(
          setting.key,
          fallback: setting.defaultValue as double,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(setting.label)),
                  Text(
                    '${value.toStringAsFixed(setting.divisions != null && (setting.max - setting.min) <= setting.divisions! ? 0 : 1)}'
                    '${setting.unit.isNotEmpty ? ' ${setting.unit}' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(setting.min, setting.max),
                min: setting.min,
                max: setting.max,
                divisions: setting.divisions,
                label: value.toStringAsFixed(1),
                onChanged: (v) => _set(setting.key, v),
              ),
            ],
          ),
        );

      case SettingKind.choice:
        final value = control.setting(setting.key) ?? setting.defaultValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(setting.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: setting.options.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: value == entry.key,
                    onSelected: (_) => _set(setting.key, entry.key),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case SettingKind.color:
        final value = control.intSetting(
          setting.key,
          fallback: setting.defaultValue as int,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(setting.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: setting.palette
                    .map((argb) => _ColorSwatch(
                          argb: argb,
                          selected: argb == value,
                          onTap: () => _set(setting.key, argb),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
    }
  }
}

/// Small square swatch used by the color picker. Renders a diagonal "auto"
/// glyph for the special sentinel value `0` so the user can revert to the
/// theme default.
class _ColorSwatch extends StatelessWidget {
  final int argb;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.argb,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuto = argb == 0;
    final color = isAuto ? theme.colorScheme.surfaceContainerHighest : Color(argb);
    final ringColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: isAuto ? 'Automatic color' : 'Color 0x${argb.toRadixString(16)}',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: selected ? 3 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: isAuto
              ? Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
      ),
    );
  }
}
