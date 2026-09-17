import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Top-level directory a control belongs to.
///
/// The catalog is organized into two directories:
/// - [ControlKind.data]: data controls (values/readouts).
/// - [ControlKind.widget]: widget controls (interactive/visual widgets).
enum ControlKind { data, widget }

extension ControlKindX on ControlKind {
  /// Localized directory title shown in the chooser.
  String titleOf(AppLocalizations l10n) {
    switch (this) {
      case ControlKind.data:
        return l10n.controlKindData;
      case ControlKind.widget:
        return l10n.controlKindWidget;
    }
  }

  /// Icon representing the directory.
  IconData get icon {
    switch (this) {
      case ControlKind.data:
        return Icons.data_object;
      case ControlKind.widget:
        return Icons.widgets_outlined;
    }
  }
}

/// Definition of an available control type that the user can add to the
/// dashboard from the edit-mode menu.
@immutable
class ControlType {
  /// Stable identifier, used for serialization and instantiation.
  final String id;

  /// Human readable label shown in the chooser.
  final String label;

  /// Icon shown in the chooser and (by default) on the placed control.
  final IconData icon;

  /// The directory this control belongs to.
  final ControlKind kind;

  /// Default width in grid cells.
  final int defaultCols;

  /// Default height in grid cells.
  final int defaultRows;

  const ControlType({
    required this.id,
    required this.label,
    required this.icon,
    required this.kind,
    this.defaultCols = 3,
    this.defaultRows = 2,
  });

  /// Localized display label, resolved from the stable [id]. Falls back to the
  /// hardcoded English [label] for any id without a translation.
  String labelOf(AppLocalizations l10n) => controlLabelForId(l10n, id) ?? label;
}

/// Maps a stable control [id] to its localized label. Returns `null` for an
/// unknown id so callers can fall back to the catalog's English [label].
String? controlLabelForId(AppLocalizations l10n, String id) {
  switch (id) {
    case 'altitude':
      return l10n.controlAltitude;
    case 'gps_altitude':
      return l10n.controlGpsAltitude;
    case 'baro_altitude':
      return l10n.controlBaroAltitude;
    case 'altitude_above_takeoff':
      return l10n.controlAltitudeAboveTakeoff;
    case 'max_altitude':
      return l10n.controlMaxAltitude;
    case 'vertical_speed':
      return l10n.controlVerticalSpeed;
    case 'ground_speed':
      return l10n.controlGroundSpeed;
    case 'glide_ratio':
      return l10n.controlGlide;
    case 'heading':
      return l10n.controlHeading;
    case 'bearing':
      return l10n.controlBearing;
    case 'gps_accuracy':
      return l10n.controlGpsAccuracy;
    case 'location':
      return l10n.controlLocation;
    case 'wind_speed':
      return l10n.controlWindSpeed;
    case 'wind_direction':
      return l10n.controlWindDirection;
    case 'pressure':
      return l10n.controlPressure;
    case 'temperature':
      return l10n.controlTemperature;
    case 'clock':
      return l10n.controlClock;
    case 'flight_time':
      return l10n.controlFlightTime;
    case 'air_time':
      return l10n.controlAirTime;
    case 'distance_to_takeoff':
      return l10n.controlDistanceToTakeoff;
    case 'sunrise':
      return l10n.controlSunrise;
    case 'sunset':
      return l10n.controlSunset;
    case 'sensor_battery':
      return l10n.controlSensorBattery;
    case 'heart_rate':
      return l10n.controlHeartRate;
    case 'phone_battery':
      return l10n.controlPhoneBattery;
    case 'vertical_graph':
      return l10n.controlVerticalGraph;
    case 'vario':
      return l10n.controlVario;
    case 'debug_sensor':
      return l10n.controlDebugSensor;
    case 'data_monitor':
      return l10n.controlDataMonitor;
    case 'map':
      return l10n.controlMap;
    case 'flight_button':
      return l10n.controlFlightButton;
    case 'status_line':
      return l10n.controlStatusLine;
    case 'compass_wind':
      return l10n.controlCompassWind;
    default:
      return null;
  }
}

/// A directory grouping several [ControlType]s together in the chooser.
@immutable
class ControlDirectory {
  final ControlKind kind;
  final List<ControlType> controls;

  const ControlDirectory({required this.kind, required this.controls});

  String titleOf(AppLocalizations l10n) => kind.titleOf(l10n);
  IconData get icon => kind.icon;
}

/// The full catalog of controls available to add from the menu.
///
/// Organized into two directories: Data Control and Widget Control.
/// Both are currently empty and ready to be populated with concrete controls.
class ControlCatalog {
  const ControlCatalog._();

  static const List<ControlDirectory> directories = [
    ControlDirectory(
      kind: ControlKind.data,
      controls: [
        // ── Altitude family ────────────────────────────────────────────
        ControlType(
          id: 'altitude',
          label: 'Altitude',
          icon: Icons.terrain,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'gps_altitude',
          label: 'GPS Altitude',
          icon: Icons.gps_fixed,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'baro_altitude',
          label: 'Baro Altitude',
          icon: Icons.height,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'altitude_above_takeoff',
          label: 'Altitude Above Takeoff',
          icon: Icons.flight_takeoff,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'max_altitude',
          label: 'Max Altitude',
          icon: Icons.landscape,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        // ── Motion ────────────────────────────────────────────────────
        ControlType(
          id: 'vertical_speed',
          label: 'Vertical Speed',
          icon: Icons.swap_vert,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'ground_speed',
          label: 'Ground Speed',
          icon: Icons.speed,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'glide_ratio',
          label: 'Glide',
          icon: Icons.trending_flat,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'heading',
          label: 'Heading',
          icon: Icons.explore_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'bearing',
          label: 'Bearing',
          icon: Icons.near_me,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'gps_accuracy',
          label: 'GPS Accuracy',
          icon: Icons.gps_not_fixed,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        // ── Position ──────────────────────────────────────────────────
        ControlType(
          id: 'location',
          label: 'Location',
          icon: Icons.my_location,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        // ── Air / weather ─────────────────────────────────────────────
        ControlType(
          id: 'wind_speed',
          label: 'Wind Speed',
          icon: Icons.air,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'wind_direction',
          label: 'Wind Direction',
          icon: Icons.navigation_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'pressure',
          label: 'Pressure',
          icon: Icons.compress,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'temperature',
          label: 'Temperature',
          icon: Icons.thermostat_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        // ── Time ──────────────────────────────────────────────────────
        ControlType(
          id: 'clock',
          label: 'Clock',
          icon: Icons.access_time,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'flight_time',
          label: 'Flight Time',
          icon: Icons.timer_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'air_time',
          label: 'Air Time',
          icon: Icons.flight_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'distance_to_takeoff',
          label: 'Distance to Takeoff',
          icon: Icons.straighten,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'sunrise',
          label: 'Sunrise',
          icon: Icons.wb_twilight,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'sunset',
          label: 'Sunset',
          icon: Icons.nights_stay_outlined,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        // ── Sensors ───────────────────────────────────────────────────
        ControlType(
          id: 'sensor_battery',
          label: 'Sensor Battery',
          icon: Icons.battery_std,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'heart_rate',
          label: 'Heart Rate',
          icon: Icons.favorite_outline,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
        ControlType(
          id: 'phone_battery',
          label: 'Phone Battery',
          icon: Icons.battery_full,
          kind: ControlKind.data,
          defaultCols: 3,
          defaultRows: 2,
        ),
      ],
    ),
    ControlDirectory(
      kind: ControlKind.widget,
      controls: [
        ControlType(
          id: 'vertical_graph',
          label: 'Vertical Graph',
          icon: Icons.show_chart,
          kind: ControlKind.widget,
          defaultCols: 6,
          defaultRows: 5,
        ),
        ControlType(
          id: 'vario',
          label: 'Vario',
          icon: Icons.swap_vert,
          kind: ControlKind.widget,
          defaultCols: 2,
          defaultRows: 5,
        ),
        ControlType(
          id: 'debug_sensor',
          label: 'Debug Sensor',
          icon: Icons.bluetooth_searching,
          kind: ControlKind.widget,
          defaultCols: 4,
          defaultRows: 6,
        ),
        ControlType(
          id: 'data_monitor',
          label: 'Data Monitor',
          icon: Icons.data_object,
          kind: ControlKind.widget,
          defaultCols: 4,
          defaultRows: 6,
        ),
        ControlType(
          id: 'map',
          label: 'Map',
          icon: Icons.map_outlined,
          kind: ControlKind.widget,
          defaultCols: 6,
          defaultRows: 6,
        ),
        ControlType(
          id: 'flight_button',
          label: 'Flight Button',
          icon: Icons.flight_takeoff,
          kind: ControlKind.widget,
          defaultCols: 2,
          defaultRows: 2,
        ),
        ControlType(
          id: 'status_line',
          label: 'Status Line',
          icon: Icons.horizontal_split,
          kind: ControlKind.widget,
          defaultCols: 6,
          defaultRows: 1,
        ),
        ControlType(
          id: 'compass_wind',
          label: 'Compass and Wind',
          icon: Icons.explore,
          kind: ControlKind.widget,
          defaultCols: 3,
          defaultRows: 3,
        ),
      ],
    ),
  ];

  /// Flat lookup of a control type by id.
  static ControlType? byId(String id) {
    for (final directory in directories) {
      for (final control in directory.controls) {
        if (control.id == id) return control;
      }
    }
    return null;
  }
}
