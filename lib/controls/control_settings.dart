import 'package:flutter/foundation.dart';

import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';

/// The kind of UI editor a setting uses.
enum SettingKind { toggle, slider, choice, color, decimalRange }

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

  /// Optional toggle key that must be enabled before this setting is shown.
  final String? visibleWhenKey;

  /// Highest supported digit count for a decimal-range setting.
  final int maxDecimalPlaces;

  const ControlSetting.decimalRange({
    required this.key,
    required this.label,
    this.defaultValue = 'default',
    this.maxDecimalPlaces = 8,
  }) : kind = SettingKind.decimalRange,
       min = 0,
       max = 1,
       divisions = null,
       unit = '',
       options = const {},
       visibleWhenKey = null;

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
       maxDecimalPlaces = 0,
       visibleWhenKey = null;

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
       maxDecimalPlaces = 0,
       visibleWhenKey = null;

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
       maxDecimalPlaces = 0,
       visibleWhenKey = null;

  /// A color setting. The picker uses the shared preset palette and supports
  /// custom ARGB color numbers.
  const ControlSetting.color({
    required this.key,
    required this.label,
    required int this.defaultValue,
    this.visibleWhenKey,
  }) : kind = SettingKind.color,
       min = 0,
       max = 1,
       divisions = null,
       unit = '',
       options = const {},
       maxDecimalPlaces = 0;

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
    final resolved = _settingLabel(l10n, key) ?? label;
    if (kind == SettingKind.decimalRange && key.startsWith('monitor')) {
      return '$resolved · ${l10n.settingDecimalPlaces}';
    }
    return resolved;
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
    case 'showSourceIcon':
      return l10n.settingShowSourceIcon;
    case 'showSeconds':
      return l10n.settingShowSeconds;
    case 'showAutoDetect':
      return l10n.settingShowAutoDetect;
    case 'showDistance':
      return l10n.settingShowDistance;
    case 'showBearingDir':
      return l10n.settingShowBearingMetric;
    case 'showElevation':
      return l10n.settingShowElevation;
    case 'showGlide':
      return l10n.settingShowGlide;
    case 'showEta':
      return l10n.settingShowEta;
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
    case 'showTakeoffPoint':
      return l10n.settingShowTakeoffPoint;
    case 'showDefaultLandingPoint':
      return l10n.settingShowDefaultLandingPoint;
    case 'showNearestLandingPoint':
      return l10n.settingShowNearestLandingPoint;
    case 'showDefaultLandingLine':
      return l10n.settingShowDefaultLandingLine;
    case 'showLastLandingLine':
      return l10n.settingShowLastLandingLine;
    case 'takeoffPointColor':
      return l10n.settingTakeoffPointColor;
    case 'defaultLandingPointColor':
      return l10n.settingDefaultLandingPointColor;
    case 'lastLandingPointColor':
      return l10n.settingLastLandingPointColor;
    case 'takeoffLineColor':
      return l10n.settingTakeoffLineColor;
    case 'defaultLandingLineColor':
      return l10n.settingDefaultLandingLineColor;
    case 'lastLandingLineColor':
      return l10n.settingLastLandingLineColor;
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
    case 'showVerticalAcceleration':
      return l10n.settingShowVerticalAcceleration;
    case 'verticalAccelerationFillOpacity':
      return l10n.settingVerticalAccelerationFillOpacity;
    case 'valueDecimals':
      return l10n.settingDecimalPlaces;
    case 'verticalSpeedDecimals':
      return l10n.settingVarioDecimals;
    case 'groundSpeedDecimals':
      return l10n.settingGroundSpeedDecimals;
    case 'windDirectionDecimals':
      return l10n.settingWindDirectionDecimals;
    case 'latitudeDecimals':
      return l10n.settingLatitudeDecimals;
    case 'longitudeDecimals':
      return l10n.settingLongitudeDecimals;
    case 'dmsSecondsDecimals':
      return l10n.settingDmsSecondsDecimals;
    case 'averageDecimals':
      return l10n.settingAverageDecimals;
    case 'peakDecimals':
      return l10n.settingPeakDecimals;
    case 'ratioDecimals':
      return l10n.settingRatioDecimals;
    case 'varioDecimals':
      return l10n.settingVarioDecimals;
    case 'headingDecimals':
      return l10n.settingHeadingDecimals;
    case 'windSpeedDecimals':
      return l10n.settingWindSpeedDecimals;
    case 'altitudeDecimals':
      return l10n.settingAltitudeDecimals;
    case 'accelerationDecimals':
      return l10n.settingAccelerationDecimals;
    case 'distanceDecimals':
      return l10n.settingDistanceDecimals;
    case 'altitudeDifferenceDecimals':
      return l10n.settingAltitudeDifferenceDecimals;
    case 'bearingDecimals':
      return l10n.settingBearingDecimals;
    case 'accuracyDecimals':
      return l10n.settingAccuracyDecimals;
    case 'monitorVerticalSpeedDecimals':
      return l10n.dataMonitorVerticalSpeed;
    case 'monitorGroundSpeedDecimals':
      return l10n.dataMonitorGroundSpeed;
    case 'monitorAltitudeDecimals':
      return l10n.dataMonitorAltitude;
    case 'monitorBaroAltitudeDecimals':
      return l10n.dataMonitorBaroAltitude;
    case 'monitorGpsAltitudeDecimals':
      return l10n.dataMonitorGpsAltitude;
    case 'monitorLatitudeDecimals':
      return l10n.dataMonitorLatitude;
    case 'monitorLongitudeDecimals':
      return l10n.dataMonitorLongitude;
    case 'monitorHeadingDecimals':
      return l10n.dataMonitorHeading;
    case 'monitorGpsAccuracyDecimals':
      return l10n.dataMonitorGpsAccuracy;
    case 'monitorWindSpeedDecimals':
      return l10n.dataMonitorWindSpeed;
    case 'monitorWindDirectionDecimals':
      return l10n.dataMonitorWindDirection;
    case 'monitorPressureDecimals':
      return l10n.dataMonitorPressure;
    case 'monitorTemperatureDecimals':
      return l10n.dataMonitorTemperature;
    case 'monitorGlideRatioDecimals':
      return l10n.dataMonitorGlideRatio;
    case 'monitorAltitudeDeltaDecimals':
      return l10n.dataMonitorBaroGpsDelta;
    case 'monitorTotalEnergyDecimals':
      return l10n.dataMonitorTotalEnergy;
    case 'mapRequiredGlideRatioDecimals':
      return l10n.settingRatioDecimals;
    case 'mapHeadingDecimals':
      return l10n.settingHeadingDecimals;
    case 'mapAltitudeDecimals':
      return l10n.settingAltitudeDecimals;
    case 'mapWindSpeedDecimals':
      return l10n.settingWindSpeedDecimals;
    case 'mapZoomDecimals':
      return l10n.settingZoomLevelDecimals;
    case 'mapGridDistanceDecimals':
      return l10n.settingGridDistanceDecimals;
    case 'mapScaleDistanceDecimals':
      return l10n.settingMapScaleDistanceDecimals;
    case 'mapVarioColorMinDecimals':
      return l10n.settingVarioMinimumDecimals;
    case 'mapVarioSinkDecimals':
      return l10n.settingSinkThresholdDecimals;
    case 'mapVarioLiftDecimals':
      return l10n.settingLiftThresholdDecimals;
    case 'mapVarioColorMaxDecimals':
      return l10n.settingVarioMaximumDecimals;
    case 'interval':
      return l10n.settingVerticalGraphInterval;
    case 'verticalStep':
      return l10n.settingVerticalGraphStep;
    case 'dotSize':
      return l10n.settingVerticalGraphDotSize;
    // `format` is shared by the heading and wind-direction controls; both use
    // the same label and option set.
    case 'format':
      return l10n.settingFormat;
    case 'bearingReference':
      return l10n.settingBearingReference;
    case 'displayUnit':
      return l10n.settingDisplayUnit;
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
    case 'bearingReference':
      switch (optionKey) {
        case 'absolute':
          return l10n.settingBearingAbsolute;
        case 'relative':
          return l10n.settingBearingRelative;
      }
      return null;
    case 'displayUnit':
      switch (optionKey) {
        case 'default':
          return l10n.settingUnitDefault;
        case 'm':
          return l10n.unitMeters;
        case 'ft':
          return l10n.unitFeet;
        case 'kmh':
          return l10n.unitKilometersPerHour;
        case 'ms':
          return l10n.unitMetersPerSecond;
        case 'mph':
          return l10n.unitMilesPerHour;
        case 'kn':
          return l10n.unitKnots;
        case 'fpm':
          return l10n.unitFeetPerMinute;
        case 'auto':
          return l10n.unitAutomaticDistance;
        case 'km':
          return l10n.unitKilometers;
        case 'mi':
          return l10n.unitMiles;
        case 'hpa':
          return l10n.unitHectopascals;
        case 'inhg':
          return l10n.unitInchesOfMercury;
        case 'c':
          return l10n.unitCelsius;
        case 'f':
          return l10n.unitFahrenheit;
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
  ),
];

ControlSetting _unitSetting(UnitDimension dimension) {
  final options = <Object, String>{
    'default': 'Default',
    for (final unit in dimension.choices)
      unit: UnitValues.label(dimension, unit),
  };
  return ControlSetting.choice(
    key: 'displayUnit',
    label: 'Display unit',
    defaultValue: 'default',
    options: options,
  );
}

/// Metric show/hide toggles and bearing format shared by the two
/// landing-waypoint widget controls (default + last landing point).
const List<ControlSetting> _landingWaypointSettings = [
  ControlSetting.toggle(
    key: 'showDistance',
    label: 'Show distance',
    defaultValue: true,
  ),
  ControlSetting.toggle(
    key: 'showBearingDir',
    label: 'Show bearing',
    defaultValue: true,
  ),
  ControlSetting.toggle(
    key: 'showElevation',
    label: 'Show elevation change',
    defaultValue: true,
  ),
  ControlSetting.toggle(
    key: 'showGlide',
    label: 'Show glide ratio',
    defaultValue: true,
  ),
  ControlSetting.toggle(
    key: 'showEta',
    label: 'Show ETA',
    defaultValue: true,
  ),
  ControlSetting.choice(
    key: 'bearingReference',
    label: 'Direction',
    defaultValue: 'absolute',
    options: {
      'absolute': 'Absolute (compass)',
      'relative': 'Relative (to heading)',
    },
  ),
  ControlSetting.choice(
    key: 'format',
    label: 'Format',
    defaultValue: 'degrees',
    options: {
      'degrees': 'Degrees (0-360°)',
      'cardinal': 'Cardinal (N, NE, …)',
    },
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
    ControlSetting.toggle(
      key: 'showVerticalAcceleration',
      label: 'Show vertical acceleration',
      defaultValue: true,
    ),
    ControlSetting.slider(
      key: 'verticalAccelerationFillOpacity',
      label: 'Acceleration fill opacity',
      defaultValue: 30.0,
      min: 0.0,
      max: 100.0,
      divisions: 100,
      unit: '%',
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
    ControlSetting.toggle(
      key: 'showSourceIcon',
      label: 'Show source icon',
      defaultValue: true,
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
  'bearing_to_nearest_landing': [
    ControlSetting.choice(
      key: 'bearingReference',
      label: 'Direction',
      defaultValue: 'absolute',
      options: {
        'absolute': 'Absolute (compass)',
        'relative': 'Relative (to heading)',
      },
    ),
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
  'bearing_to_default_landing': [
    ControlSetting.choice(
      key: 'bearingReference',
      label: 'Direction',
      defaultValue: 'absolute',
      options: {
        'absolute': 'Absolute (compass)',
        'relative': 'Relative (to heading)',
      },
    ),
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
  'default_landing_waypoint': _landingWaypointSettings,
  'last_landing_waypoint': _landingWaypointSettings,
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
      defaultValue: 'amap-sat',
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
      key: 'showTakeoffPoint',
      label: 'Show take-off point',
      defaultValue: true,
    ),
    ControlSetting.color(
      key: 'takeoffPointColor',
      label: 'Take-off marker color',
      defaultValue: 0xFF43A047,
      visibleWhenKey: 'showTakeoffPoint',
    ),
    ControlSetting.toggle(
      key: 'showDefaultLandingPoint',
      label: 'Show default landing point',
      defaultValue: true,
    ),
    ControlSetting.color(
      key: 'defaultLandingPointColor',
      label: 'Default landing marker color',
      defaultValue: 0xFFF44336,
      visibleWhenKey: 'showDefaultLandingPoint',
    ),
    ControlSetting.toggle(
      key: 'showNearestLandingPoint',
      label: 'Show nearest landing point',
      defaultValue: true,
    ),
    ControlSetting.color(
      key: 'lastLandingPointColor',
      label: 'Last landing marker color',
      defaultValue: 0xFF9C27B0,
      visibleWhenKey: 'showNearestLandingPoint',
    ),
    ControlSetting.toggle(
      key: 'showTakeoffLine',
      label: 'Show line to take-off',
      defaultValue: false,
    ),
    ControlSetting.color(
      key: 'takeoffLineColor',
      label: 'Take-off line color',
      defaultValue: 0xFF43A047,
      visibleWhenKey: 'showTakeoffLine',
    ),
    ControlSetting.toggle(
      key: 'showDefaultLandingLine',
      label: 'Show line to default landing point',
      defaultValue: false,
    ),
    ControlSetting.color(
      key: 'defaultLandingLineColor',
      label: 'Default landing line color',
      defaultValue: 0xFFF44336,
      visibleWhenKey: 'showDefaultLandingLine',
    ),
    ControlSetting.toggle(
      key: 'showLastLandingLine',
      label: 'Show line to last landing point',
      defaultValue: false,
    ),
    ControlSetting.color(
      key: 'lastLandingLineColor',
      label: 'Last landing line color',
      defaultValue: 0xFF9C27B0,
      visibleWhenKey: 'showLastLandingLine',
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
    ControlSetting.decimalRange(
      key: 'mapRequiredGlideRatioDecimals',
      label: 'Required glide ratio',
    ),
    ControlSetting.decimalRange(key: 'mapHeadingDecimals', label: 'Heading'),
    ControlSetting.decimalRange(key: 'mapAltitudeDecimals', label: 'Altitude'),
    ControlSetting.decimalRange(
      key: 'mapWindSpeedDecimals',
      label: 'Wind speed',
    ),
    ControlSetting.decimalRange(key: 'mapZoomDecimals', label: 'Zoom level'),
    ControlSetting.decimalRange(
      key: 'mapGridDistanceDecimals',
      label: 'Grid distance',
    ),
    ControlSetting.decimalRange(
      key: 'mapScaleDistanceDecimals',
      label: 'Map scale distance',
    ),
    ControlSetting.decimalRange(
      key: 'mapVarioColorMinDecimals',
      label: 'Vario scale minimum',
    ),
    ControlSetting.decimalRange(
      key: 'mapVarioSinkDecimals',
      label: 'Sink threshold',
    ),
    ControlSetting.decimalRange(
      key: 'mapVarioLiftDecimals',
      label: 'Lift threshold',
    ),
    ControlSetting.decimalRange(
      key: 'mapVarioColorMaxDecimals',
      label: 'Vario scale maximum',
    ),
  ],
};

/// Decimal-place ranges shared by the two landing-waypoint widget controls.
const List<ControlSetting> _landingWaypointDecimals = [
  ControlSetting.decimalRange(key: 'distanceDecimals', label: 'Distance'),
  ControlSetting.decimalRange(key: 'bearingDecimals', label: 'Bearing'),
  ControlSetting.decimalRange(
    key: 'altitudeDifferenceDecimals',
    label: 'Elevation change',
  ),
  ControlSetting.decimalRange(key: 'ratioDecimals', label: 'Glide ratio'),
];

const Map<String, List<ControlSetting>> _decimalSettings = {
  'vertical_graph': [
    ControlSetting.decimalRange(key: 'altitudeDecimals', label: 'Altitude'),
    ControlSetting.decimalRange(
      key: 'accelerationDecimals',
      label: 'Acceleration',
    ),
  ],
  'vario': [ControlSetting.decimalRange(key: 'valueDecimals', label: 'Vario')],
  'vertical_speed': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Vertical speed'),
  ],
  'altitude': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Altitude'),
  ],
  'gps_altitude': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'GPS altitude'),
  ],
  'baro_altitude': [
    ControlSetting.decimalRange(
      key: 'valueDecimals',
      label: 'Barometric altitude',
    ),
  ],
  'max_altitude': [
    ControlSetting.decimalRange(
      key: 'valueDecimals',
      label: 'Maximum altitude',
    ),
  ],
  'altitude_above_takeoff': [
    ControlSetting.decimalRange(
      key: 'valueDecimals',
      label: 'Altitude above takeoff',
    ),
  ],
  'thermal_gain': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Thermal gain'),
  ],
  'ground_speed': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Ground speed'),
  ],
  'glide_ratio': [
    ControlSetting.decimalRange(key: 'ratioDecimals', label: 'Glide ratio'),
    ControlSetting.decimalRange(key: 'varioDecimals', label: 'Vario'),
  ],
  'heading': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Heading'),
  ],
  'gps_accuracy': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'GPS accuracy'),
  ],
  'location': [
    ControlSetting.decimalRange(key: 'latitudeDecimals', label: 'Latitude'),
    ControlSetting.decimalRange(key: 'longitudeDecimals', label: 'Longitude'),
    ControlSetting.decimalRange(
      key: 'dmsSecondsDecimals',
      label: 'DMS seconds',
    ),
  ],
  'wind_speed': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Wind speed'),
  ],
  'wind_direction': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Wind direction'),
  ],
  'pressure': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Pressure'),
  ],
  'temperature': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Temperature'),
  ],
  'distance_to_takeoff': [
    ControlSetting.decimalRange(key: 'valueDecimals', label: 'Distance'),
  ],
  'climb_avg': [
    ControlSetting.decimalRange(key: 'averageDecimals', label: 'Average'),
    ControlSetting.decimalRange(key: 'peakDecimals', label: 'Peak'),
  ],
  'takeoff_waypoint': [
    ControlSetting.decimalRange(key: 'distanceDecimals', label: 'Distance'),
    ControlSetting.decimalRange(
      key: 'altitudeDifferenceDecimals',
      label: 'Altitude difference',
    ),
    ControlSetting.decimalRange(key: 'bearingDecimals', label: 'Bearing'),
  ],
  'default_landing_waypoint': _landingWaypointDecimals,
  'last_landing_waypoint': _landingWaypointDecimals,
  'status_line': [
    ControlSetting.decimalRange(key: 'accuracyDecimals', label: 'GPS accuracy'),
  ],
  'compass_wind': [
    ControlSetting.decimalRange(key: 'headingDecimals', label: 'Heading'),
    ControlSetting.decimalRange(key: 'windSpeedDecimals', label: 'Wind speed'),
  ],
  'data_monitor': [
    ControlSetting.decimalRange(
      key: 'monitorVerticalSpeedDecimals',
      label: 'Vertical speed',
    ),
    ControlSetting.decimalRange(
      key: 'monitorGroundSpeedDecimals',
      label: 'Ground speed',
    ),
    ControlSetting.decimalRange(
      key: 'monitorAltitudeDecimals',
      label: 'Altitude',
    ),
    ControlSetting.decimalRange(
      key: 'monitorBaroAltitudeDecimals',
      label: 'Barometric altitude',
    ),
    ControlSetting.decimalRange(
      key: 'monitorGpsAltitudeDecimals',
      label: 'GPS altitude',
    ),
    ControlSetting.decimalRange(
      key: 'monitorLatitudeDecimals',
      label: 'Latitude',
    ),
    ControlSetting.decimalRange(
      key: 'monitorLongitudeDecimals',
      label: 'Longitude',
    ),
    ControlSetting.decimalRange(
      key: 'monitorHeadingDecimals',
      label: 'Heading',
    ),
    ControlSetting.decimalRange(
      key: 'monitorGpsAccuracyDecimals',
      label: 'GPS accuracy',
    ),
    ControlSetting.decimalRange(
      key: 'monitorWindSpeedDecimals',
      label: 'Wind speed',
    ),
    ControlSetting.decimalRange(
      key: 'monitorWindDirectionDecimals',
      label: 'Wind direction',
    ),
    ControlSetting.decimalRange(
      key: 'monitorPressureDecimals',
      label: 'Pressure',
    ),
    ControlSetting.decimalRange(
      key: 'monitorTemperatureDecimals',
      label: 'Temperature',
    ),
    ControlSetting.decimalRange(
      key: 'monitorGlideRatioDecimals',
      label: 'Glide ratio',
    ),
    ControlSetting.decimalRange(
      key: 'monitorAltitudeDeltaDecimals',
      label: 'Baro/GPS difference',
    ),
    ControlSetting.decimalRange(
      key: 'monitorTotalEnergyDecimals',
      label: 'Total energy altitude',
    ),
  ],
  'debug_sensor': [
    ControlSetting.decimalRange(
      key: 'verticalSpeedDecimals',
      label: 'Vertical speed',
    ),
    ControlSetting.decimalRange(key: 'altitudeDecimals', label: 'Altitude'),
    ControlSetting.decimalRange(
      key: 'groundSpeedDecimals',
      label: 'Ground speed',
    ),
    ControlSetting.decimalRange(key: 'headingDecimals', label: 'Heading'),
    ControlSetting.decimalRange(key: 'windSpeedDecimals', label: 'Wind speed'),
    ControlSetting.decimalRange(
      key: 'windDirectionDecimals',
      label: 'Wind direction',
    ),
  ],
};

/// Control type ids whose face never renders a title. For these the
/// "Show title" toggle is meaningless and should be hidden from the
/// settings sheet to avoid confusing the user.
const Set<String> _controlsWithoutTitle = {
  'vario',
  'climb_avg',
  'takeoff_waypoint',
  'default_landing_waypoint',
  'last_landing_waypoint',
  'debug_sensor',
  'data_monitor',
  'flight_button',
  'map',
  'status_line',
  'compass_wind',
};

const Map<String, UnitDimension> _unitDimensions = {
  'vertical_graph': UnitDimension.altitude,
  'vario': UnitDimension.verticalSpeed,
  'climb_avg': UnitDimension.verticalSpeed,
  'vertical_speed': UnitDimension.verticalSpeed,
  'altitude': UnitDimension.altitude,
  'gps_altitude': UnitDimension.altitude,
  'baro_altitude': UnitDimension.altitude,
  'max_altitude': UnitDimension.altitude,
  'altitude_above_takeoff': UnitDimension.altitude,
  'ground_speed': UnitDimension.speed,
  'wind_speed': UnitDimension.speed,
  'distance_to_takeoff': UnitDimension.distance,
  'takeoff_waypoint': UnitDimension.distance,
  'default_landing_waypoint': UnitDimension.distance,
  'last_landing_waypoint': UnitDimension.distance,
  'gps_accuracy': UnitDimension.altitude,
  'pressure': UnitDimension.pressure,
  'temperature': UnitDimension.temperature,
  'compass_wind': UnitDimension.speed,
};

/// Returns the full ordered list of settings for a control type id
/// (common settings first, then type-specific ones).
List<ControlSetting> settingsSchemaFor(String typeId) {
  final hidesTitle = _controlsWithoutTitle.contains(typeId);
  final dimension = _unitDimensions[typeId];
  return [
    for (final setting in _commonSettings)
      if (!(hidesTitle && setting.key == 'showTitle')) setting,
    ...(_typeSettings[typeId] ?? const []),
    ...(_decimalSettings[typeId] ?? const []),
    if (dimension != null) _unitSetting(dimension),
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
