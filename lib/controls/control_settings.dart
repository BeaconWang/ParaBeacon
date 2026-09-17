import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

/// The kind of UI editor a setting uses.
enum SettingKind { toggle, slider, choice, color }

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
  }) : kind = SettingKind.toggle,
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
  }) : kind = SettingKind.slider,
       options = const {},
       palette = const [];

  const ControlSetting.choice({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.options,
  }) : kind = SettingKind.choice,
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
  }) : kind = SettingKind.color,
       min = 0,
       max = 1,
       divisions = null,
       unit = '',
       options = const {};

  /// Localized label for this setting, resolved from the current [l10n] by the
  /// stable [key]. Falls back to the hardcoded English [label] for any key not
  /// (yet) present in the translations, so unmapped settings still render.
  ///
  /// Resolved at render time (not stored), so it follows a runtime language
  /// switch immediately.
  String labelOf(AppLocalizations l10n) {
    // The `location` control stores its coordinate format under the same
    // `format` key that heading/wind-direction use for their compass format,
    // but its label differs ("Coordinate format" vs "Format"). Disambiguate by
    // the option set: only the coordinate one offers `decimal`.
    if (key == 'format' && options.containsKey('decimal')) {
      return l10n.settingCoordinateFormat;
    }
    return _settingLabel(l10n, key) ?? label;
  }

  /// Localized label for one of this setting's [choice] [options], resolved by
  /// the stable ([key], [optionKey]) pair. Falls back to the hardcoded English
  /// option text so unmapped options still render.
  String optionLabelOf(AppLocalizations l10n, Object optionKey) {
    // Coordinate-format options live under the shared `format` key too; route
    // them to their own translations.
    if (key == 'format' && options.containsKey('decimal')) {
      switch (optionKey) {
        case 'decimal':
          return l10n.settingCoordinateDecimal;
        case 'dms':
          return l10n.settingCoordinateDms;
      }
    }
    return _settingOptionLabel(l10n, key, optionKey) ??
        (options[optionKey] ?? optionKey.toString());
  }
}

/// Resolves a setting [key] to its localized label, or `null` when the key has
/// no translation (the caller then falls back to the English default).
String? _settingLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'showTitle':
      return l10n.settingShowTitle;
    case 'showBorder':
      return l10n.settingShowBorder;
    case 'borderColor':
      return l10n.settingBorderColor;
    case 'borderWidth':
      return l10n.settingBorderWidth;
    case 'borderRadius':
      return l10n.settingCornerRadius;
    case 'controlOpacity':
      return l10n.settingControlOpacity;
    case 'backgroundColor':
      return l10n.settingBackgroundColor;
    case 'backgroundOpacity':
      return l10n.settingBackgroundOpacity;
    case 'textColor':
      return l10n.settingTextColor;
    case 'maxScale':
      return l10n.settingScaleMax;
    case 'avgInterval':
      return l10n.settingAveragingInterval;
    case 'source':
      return l10n.settingAltitudeSource;
    case 'showSeconds':
      return l10n.settingShowSeconds;
    case 'showAutoDetect':
      return l10n.settingShowAutoDetect;
    case 'showGps':
      return l10n.settingShowGps;
    case 'gpsDetailed':
      return l10n.settingGpsDetailed;
    case 'showBluetooth':
      return l10n.settingShowBluetooth;
    case 'showSensorBattery':
      return l10n.settingShowSensorBattery;
    case 'showDeviceBattery':
      return l10n.settingShowDeviceBattery;
    case 'showFlightTimer':
      return l10n.settingShowFlightTimer;
    case 'showClock':
      return l10n.settingShowClock;
    case 'timeFormat':
      return l10n.settingTimeFormat;
    case 'glideAvg':
      return l10n.settingGlideAvg;
    case 'glideLeadingOne':
      return l10n.settingGlideLeadingOne;
    case 'glideShowVario':
      return l10n.settingGlideShowVario;
    case 'follow':
      return l10n.settingFollowPosition;
    case 'zoom':
      return l10n.settingZoom;
    case 'tileSource':
      return l10n.settingMapSource;
    case 'rotation':
      return l10n.settingRotation;
    case 'showNorth':
      return l10n.settingShowNorth;
    case 'pilotArrowCoef':
      return l10n.settingPilotArrowSize;
    case 'lineThickness':
      return l10n.settingLineThickness;
    case 'tracklogMinutes':
      return l10n.settingTracklogLength;
    case 'latestThermals':
      return l10n.settingLatestThermals;
    case 'useOffline':
      return l10n.settingPreferOffline;
    case 'showTrack':
      return l10n.settingShowTrack;
    case 'showThermal':
      return l10n.settingShowThermal;
    case 'windAlgorithm':
      return l10n.settingWindAlgorithm;
    case 'showWind':
      return l10n.settingShowWind;
    case 'showSun':
      return l10n.settingShowSun;
    case 'showBearing':
      return l10n.settingShowBearing;
    case 'showTakeoffLine':
      return l10n.settingShowTakeoffLine;
    case 'showScale':
      return l10n.settingShowScale;
    case 'showAirspace':
      return l10n.settingShowAirspace;
    case 'showLegend':
      return l10n.settingShowLegend;
    case 'showZoomLevel':
      return l10n.settingShowZoomLevel;
    case 'showAttribution':
      return l10n.settingShowAttribution;
    case 'showStatus':
      return l10n.settingShowStatus;
    // `format` is shared by the heading and wind-direction controls; both use
    // the same label and option set.
    case 'format':
      return l10n.settingFormat;
    default:
      return null;
  }
}

/// Resolves a ([settingKey], [optionKey]) pair to its localized option label,
/// or `null` when there is no translation.
String? _settingOptionLabel(
  AppLocalizations l10n,
  String settingKey,
  Object optionKey,
) {
  switch (settingKey) {
    case 'glideAvg':
      switch (optionKey) {
        case '0':
          return l10n.settingGlideAvgInstant;
        default:
          return l10n.settingGlideAvgSeconds(optionKey.toString());
      }
    case 'timeFormat':
      switch (optionKey) {
        case '24h':
          return l10n.settingTimeFormat24h;
        case '12h':
          return l10n.settingTimeFormat12h;
      }
      return null;
    case 'format': // heading / wind_direction
      switch (optionKey) {
        case 'degrees':
          return l10n.settingFormatDegrees;
        case 'cardinal':
          return l10n.settingFormatCardinal;
      }
      return null;
    case 'source': // altitude source
      switch (optionKey) {
        case 'auto':
          return l10n.settingAltitudeSourceAuto;
        case 'gps':
          return l10n.settingAltitudeSourceGps;
        case 'baro':
          return l10n.settingAltitudeSourceBaro;
      }
      return null;
    case 'tileSource': // map source
      switch (optionKey) {
        case 'none':
          return l10n.settingMapSourceNone;
        case 'osm':
          return l10n.settingMapSourceOsm;
        case 'osmfr':
          return l10n.settingMapSourceOsmFr;
        case 'carto-dark':
          return l10n.settingMapSourceCartoDark;
        case 'carto-voyager':
          return l10n.settingMapSourceCartoVoyager;
        case 'amap':
          return l10n.settingMapSourceAmap;
        case 'amap-sat':
          return l10n.settingMapSourceAmapSat;
      }
      return null;
    case 'rotation': // map rotation
      switch (optionKey) {
        case 'north':
          return l10n.settingRotationNorth;
        case 'track':
          return l10n.settingRotationTrack;
      }
      return null;
    case 'windAlgorithm':
      switch (optionKey) {
        case 'none':
          return l10n.settingWindAlgorithmNone;
        case 'classic':
          return l10n.settingWindAlgorithmClassic;
        case 'particle':
          return l10n.settingWindAlgorithmParticle;
      }
      return null;
    default:
      return null;
  }
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

/// Default palette for the text color picker.
///
/// The first entry (`0`) means "automatic" — the control face uses the
/// theme's on-surface color (the historical behavior). Semantic colors
/// (green for climb, red for sink) are *not* overridden by this setting so
/// they keep conveying meaning regardless of the user's choice.
const List<int> _textColorPalette = [
  0x00000000, // automatic (theme onSurface)
  0xFFFFFFFF, // white
  0xFF000000, // black
  0xFFE0E0E0, // light grey
  0xFF9E9E9E, // grey
  0xFFF44336, // red
  0xFFFF9800, // orange
  0xFFFFEB3B, // yellow
  0xFF4CAF50, // green
  0xFF00BCD4, // cyan
  0xFF2196F3, // blue
  0xFF9C27B0, // purple
];

/// Default palette for the background color picker.
///
/// The first entry (`0`) means "automatic" — the control widget falls back
/// to the theme's surface color, which is the historical behavior. The
/// remaining entries are opaque ARGB values; the widget re-applies the
/// user's `backgroundOpacity` setting on top so alpha is controlled in a
/// single place.
const List<int> _backgroundColorPalette = [
  0x00000000, // automatic (theme surface)
  0xFFFFFFFF, // white
  0xFF000000, // black
  0xFF424242, // dark grey
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
  ControlSetting.slider(
    key: 'controlOpacity',
    label: 'Control opacity',
    defaultValue: 100.0,
    min: 0.0,
    max: 100.0,
    divisions: 100,
    unit: '%',
  ),
  ControlSetting.color(
    key: 'backgroundColor',
    label: 'Background color',
    defaultValue: 0, // 0 == automatic (theme surface)
    palette: _backgroundColorPalette,
  ),
  ControlSetting.slider(
    key: 'backgroundOpacity',
    label: 'Background opacity',
    defaultValue: 92.0,
    min: 0.0,
    max: 100.0,
    divisions: 100,
    unit: '%',
  ),
  ControlSetting.color(
    key: 'textColor',
    label: 'Text color',
    defaultValue: 0, // 0 == automatic (theme onSurface)
    palette: _textColorPalette,
  ),
];

/// Type-specific settings, keyed by control type id.
const Map<String, List<ControlSetting>> _typeSettings = {
  'vertical_graph': [
    ControlSetting.slider(
      key: 'interval',
      label: 'Shown interval',
      defaultValue: 60.0,
      min: 10.0,
      max: 600.0,
      divisions: 59,
      unit: 's',
    ),
    ControlSetting.slider(
      key: 'verticalStep',
      label: 'Vertical step',
      defaultValue: 50.0,
      min: 5.0,
      max: 500.0,
      divisions: 99,
      unit: 'm',
    ),
    ControlSetting.slider(
      key: 'dotSize',
      label: 'Dot size',
      defaultValue: 3.0,
      min: 1.0,
      max: 8.0,
      divisions: 14,
      unit: 'px',
    ),
  ],
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
      options: {'decimal': 'Decimal degrees', 'dms': 'Deg / min / sec'},
    ),
  ],
  'altitude': [
    ControlSetting.choice(
      key: 'source',
      label: 'Altitude source',
      defaultValue: 'auto',
      options: {
        'auto': 'Auto (baro if available)',
        'gps': 'GPS altitude',
        'baro': 'Barometric altitude',
      },
    ),
  ],
  'heading': [
    ControlSetting.choice(
      key: 'format',
      label: 'Format',
      defaultValue: 'degrees',
      options: {
        'degrees': 'Degrees (0-360°)',
        'cardinal': 'Cardinal (N, NE, …)',
      },
    ),
  ],
  'bearing': [
    ControlSetting.choice(
      key: 'format',
      label: 'Format',
      defaultValue: 'degrees',
      options: {
        'degrees': 'Degrees (0-360°)',
        'cardinal': 'Cardinal (N, NE, …)',
      },
    ),
  ],
  'wind_direction': [
    ControlSetting.choice(
      key: 'format',
      label: 'Format',
      defaultValue: 'degrees',
      options: {
        'degrees': 'Degrees (0-360°)',
        'cardinal': 'Cardinal (N, NE, …)',
      },
    ),
  ],
  'clock': [
    ControlSetting.toggle(
      key: 'showSeconds',
      label: 'Show seconds',
      defaultValue: false,
    ),
    ControlSetting.choice(
      key: 'timeFormat',
      label: 'Time format',
      defaultValue: '24h',
      options: {'24h': '24-hour', '12h': '12-hour (AM/PM)'},
    ),
  ],
  'glide_ratio': [
    ControlSetting.choice(
      key: 'glideAvg',
      label: 'Glide averaging',
      defaultValue: '8',
      options: {
        '0': 'Instant',
        '5': '5 s',
        '8': '8 s',
        '10': '10 s',
        '15': '15 s',
        '20': '20 s',
        '30': '30 s',
      },
    ),
    ControlSetting.toggle(
      key: 'glideLeadingOne',
      label: 'Show leading "1:"',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'glideShowVario',
      label: 'Show vario in lift',
      defaultValue: false,
    ),
  ],
  'sunrise': [
    ControlSetting.choice(
      key: 'timeFormat',
      label: 'Time format',
      defaultValue: '24h',
      options: {'24h': '24-hour', '12h': '12-hour (AM/PM)'},
    ),
  ],
  'sunset': [
    ControlSetting.choice(
      key: 'timeFormat',
      label: 'Time format',
      defaultValue: '24h',
      options: {'24h': '24-hour', '12h': '12-hour (AM/PM)'},
    ),
  ],
  'flight_button': [
    ControlSetting.toggle(
      key: 'showAutoDetect',
      label: 'Show auto-detect checkbox',
      defaultValue: true,
    ),
  ],
  'status_line': [
    ControlSetting.toggle(
      key: 'showGps',
      label: 'Show GPS status',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'gpsDetailed',
      label: 'Detailed GPS status',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'showBluetooth',
      label: 'Show Bluetooth sensor',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showSensorBattery',
      label: 'Show sensor battery',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showDeviceBattery',
      label: 'Show device battery',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showFlightTimer',
      label: 'Show flight timer',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showClock',
      label: 'Show clock',
      defaultValue: true,
    ),
    ControlSetting.choice(
      key: 'timeFormat',
      label: 'Time format',
      defaultValue: '24h',
      options: {'24h': '24-hour', '12h': '12-hour (AM/PM)'},
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
      defaultValue: 17.0,
      min: 3.0,
      max: 18.0,
      divisions: 15,
    ),
    ControlSetting.choice(
      key: 'tileSource',
      label: 'Map source',
      defaultValue: 'osm',
      options: {
        'none': 'None (no basemap)',
        'osm': 'OpenStreetMap',
        'osmfr': 'OSM France',
        'carto-dark': 'Carto Dark',
        'carto-voyager': 'Carto Voyager',
        'amap': '高德地图',
        'amap-sat': '高德卫星',
      },
    ),
    ControlSetting.choice(
      key: 'rotation',
      label: 'Rotation',
      defaultValue: 'north',
      options: {'north': 'North at the top', 'track': 'Track up (heading)'},
    ),
    ControlSetting.toggle(
      key: 'showNorth',
      label: 'Display North direction',
      defaultValue: false,
    ),
    ControlSetting.slider(
      key: 'pilotArrowCoef',
      label: 'Pilot arrow size',
      defaultValue: 100.0,
      min: 50.0,
      max: 200.0,
      divisions: 15,
      unit: '%',
    ),
    ControlSetting.slider(
      key: 'lineThickness',
      label: 'Thickness of lines',
      defaultValue: 1.0,
      min: 0.5,
      max: 3.0,
      divisions: 10,
      unit: 'x',
    ),
    ControlSetting.slider(
      key: 'tracklogMinutes',
      label: 'Tracklog length (0 = all)',
      defaultValue: 0.0,
      min: 0.0,
      max: 60.0,
      divisions: 60,
      unit: 'min',
    ),
    ControlSetting.slider(
      key: 'latestThermals',
      label: 'Show N latest thermals',
      defaultValue: 8.0,
      min: 0.0,
      max: 12.0,
      divisions: 12,
    ),
    ControlSetting.toggle(
      key: 'useOffline',
      label: 'Prefer offline maps (.mbtiles)',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showTrack',
      label: 'Show flight track',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showThermal',
      label: 'Show thermal assistant',
      defaultValue: true,
    ),
    ControlSetting.choice(
      key: 'windAlgorithm',
      label: 'Include wind in computation',
      defaultValue: 'classic',
      options: {
        'none': 'None',
        'classic': 'Classic',
        'particle': 'Particle drift',
      },
    ),
    ControlSetting.toggle(
      key: 'showWind',
      label: 'Show wind',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showSun',
      label: 'Show sun position',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'showBearing',
      label: 'Show bearing (course) line',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'showTakeoffLine',
      label: 'Show line to take-off',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'showScale',
      label: 'Display map scale',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showAirspace',
      label: 'Show airspace',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showLegend',
      label: 'Show vario legend',
      defaultValue: false,
    ),
    ControlSetting.toggle(
      key: 'showZoomLevel',
      label: 'Show zoom level',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showAttribution',
      label: 'Show map attribution',
      defaultValue: true,
    ),
    ControlSetting.toggle(
      key: 'showStatus',
      label: 'Show HDG/ALT & GPS status',
      defaultValue: true,
    ),
  ],
};

/// Control type ids whose face never renders a title. For these the
/// "Show title" toggle is meaningless and should be hidden from the
/// settings sheet to avoid confusing the user.
const Set<String> _controlsWithoutTitle = {
  'vario',
  'debug_sensor',
  'data_monitor',
  'flight_button',
  'map',
  'status_line',
  'compass_wind',
};

/// Returns the full ordered list of settings for a control type id
/// (common settings first, then type-specific ones).
List<ControlSetting> settingsSchemaFor(String typeId) {
  final hidesTitle = _controlsWithoutTitle.contains(typeId);
  return [
    for (final setting in _commonSettings)
      if (!(hidesTitle && setting.key == 'showTitle')) setting,
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
