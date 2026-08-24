import 'package:flutter/foundation.dart';

/// The kind of UI editor a setting uses.
enum SettingKind {
  toggle,
  slider,
  choice,
}

/// Definition of a single configurable setting for a control.
///
/// This is a lightweight, serializable schema (values are stored in a
/// `Map<String, dynamic>` on the placed control), inspired by XCTrack's widget
/// settings (e.g. "Show title", averaging interval).
@immutable
class ControlSetting {
  /// Stable key used to store/read the value in the settings map.
  final String key;

  /// Human readable label shown in the settings sheet.
  final String label;

  final SettingKind kind;

  /// Default value when the control is created.
  final Object defaultValue;

  // Slider bounds (used when [kind] == SettingKind.slider).
  final double min;
  final double max;
  final int? divisions;

  /// Suffix shown next to a slider value (e.g. "m/s", "s").
  final String unit;

  /// Options for a choice setting: value -> label.
  final Map<Object, String> options;

  const ControlSetting.toggle({
    required this.key,
    required this.label,
    required bool this.defaultValue,
  })  : kind = SettingKind.toggle,
        min = 0,
        max = 1,
        divisions = null,
        unit = '',
        options = const {};

  const ControlSetting.slider({
    required this.key,
    required this.label,
    required double this.defaultValue,
    required this.min,
    required this.max,
    this.divisions,
    this.unit = '',
  })  : kind = SettingKind.slider,
        options = const {};

  const ControlSetting.choice({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.options,
  })  : kind = SettingKind.choice,
        min = 0,
        max = 1,
        divisions = null,
        unit = '';
}

/// Common settings that every control shares.
const List<ControlSetting> _commonSettings = [
  ControlSetting.toggle(
    key: 'showTitle',
    label: 'Show title',
    defaultValue: true,
  ),
  ControlSetting.toggle(
    key: 'showBorder',
    label: 'Show border',
    defaultValue: true,
  ),
];

/// Type-specific settings, keyed by control type id.
const Map<String, List<ControlSetting>> _typeSettings = {
  'vario': [
    ControlSetting.slider(
      key: 'maxScale',
      label: 'Scale (max)',
      defaultValue: 8.0,
      min: 2.0,
      max: 12.0,
      divisions: 10,
      unit: 'm/s',
    ),
  ],
  'vertical_speed': [
    ControlSetting.slider(
      key: 'avgInterval',
      label: 'Averaging interval',
      defaultValue: 2.0,
      min: 0.0,
      max: 30.0,
      divisions: 30,
      unit: 's',
    ),
  ],
};

/// Returns the full ordered list of settings for a control type id
/// (common settings first, then type-specific ones).
List<ControlSetting> settingsSchemaFor(String typeId) {
  return [
    ..._commonSettings,
    ...(_typeSettings[typeId] ?? const []),
  ];
}

/// Builds the default settings map for a control type id.
Map<String, dynamic> defaultSettingsFor(String typeId) {
  final map = <String, dynamic>{};
  for (final setting in settingsSchemaFor(typeId)) {
    map[setting.key] = setting.defaultValue;
  }
  return map;
}
