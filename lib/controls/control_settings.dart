import 'package:flutter/foundation.dart';

/// The kind of UI editor a setting uses.
enum SettingKind {
  toggle,
  slider,
  choice,
  color,
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

  /// Palette for a color setting: an ordered list of ARGB int swatches to
  /// choose from. The special value `0` is treated as "use theme default"
  /// (i.e. the widget's own fallback) so the user can revert to the
  /// automatic outline color.
  final List<int> palette;

  const ControlSetting.toggle({
    required this.key,
    required this.label,
    required bool this.defaultValue,
  })  : kind = SettingKind.toggle,
        min = 0,
        max = 1,
        divisions = null,
        unit = '',
        options = const {},
        palette = const [];

  const ControlSetting.slider({
    required this.key,
    required this.label,
    required double this.defaultValue,
    required this.min,
    required this.max,
    this.divisions,
    this.unit = '',
  })  : kind = SettingKind.slider,
        options = const {},
        palette = const [];

  const ControlSetting.choice({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.options,
  })  : kind = SettingKind.choice,
        min = 0,
        max = 1,
        divisions = null,
        unit = '',
        palette = const [];

  /// A color setting. [defaultValue] and every entry in [palette] must be an
  /// ARGB int (e.g. `0xFF2196F3`). A value of `0` in the palette means
  /// "automatic / theme default".
  const ControlSetting.color({
    required this.key,
    required this.label,
    required int this.defaultValue,
    required this.palette,
  })  : kind = SettingKind.color,
        min = 0,
        max = 1,
        divisions = null,
        unit = '',
        options = const {};
}

/// Default palette for the border color picker.
///
/// The first entry (`0`) means "automatic" — the control widget will fall
/// back to the theme's outline color, which is the historical behavior.
const List<int> _borderColorPalette = [
  0x00000000, // automatic (theme default)
  0xFFFFFFFF, // white
  0xFF000000, // black
  0xFF9E9E9E, // grey
  0xFFF44336, // red
  0xFFFF9800, // orange
  0xFFFFEB3B, // yellow
  0xFF4CAF50, // green
  0xFF00BCD4, // cyan
  0xFF2196F3, // blue
  0xFF9C27B0, // purple
];

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
  ControlSetting.color(
    key: 'borderColor',
    label: 'Border color',
    defaultValue: 0, // 0 == automatic (theme outline)
    palette: _borderColorPalette,
  ),
  ControlSetting.slider(
    key: 'borderWidth',
    label: 'Border width',
    defaultValue: 1.0,
    min: 0.5,
    max: 6.0,
    divisions: 11,
    unit: 'px',
  ),
  ControlSetting.slider(
    key: 'borderRadius',
    label: 'Corner radius',
    defaultValue: 8.0,
    min: 0.0,
    max: 32.0,
    divisions: 32,
    unit: 'px',
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
  'location': [
    ControlSetting.choice(
      key: 'format',
      label: 'Coordinate format',
      defaultValue: 'decimal',
      options: {
        'decimal': 'Decimal degrees',
        'dms': 'Deg / min / sec',
      },
    ),
  ],
  'flight_button': [
    ControlSetting.toggle(
      key: 'showAutoDetect',
      label: 'Show auto-detect checkbox',
      defaultValue: true,
    ),
  ],
  'map': [
    ControlSetting.toggle(
      key: 'follow',
      label: 'Follow position',
      defaultValue: true,
    ),
    ControlSetting.slider(
      key: 'zoom',
      label: 'Zoom',
      defaultValue: 13.0,
      min: 3.0,
      max: 18.0,
      divisions: 15,
    ),
    ControlSetting.choice(
      key: 'tileSource',
      label: 'Map source',
      defaultValue: 'osm',
      options: {
        'osm': 'OpenStreetMap',
        'osmfr': 'OSM France',
        'carto-dark': 'Carto Dark',
        'carto-voyager': 'Carto Voyager',
        'amap': '高德地图',
        'amap-sat': '高德卫星',
      },
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
