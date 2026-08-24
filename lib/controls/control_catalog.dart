import 'package:flutter/material.dart';

/// Definition of an available control type that the user can add to the
/// dashboard from the edit-mode menu.
///
/// Inspired by XCTrack's widget catalog, where each "widget" belongs to a
/// category (System, Flying, Air, Navigation, ...) and is instantiated when
/// the user picks it from the "Add widget" chooser.
@immutable
class ControlType {
  /// Stable identifier, used for serialization and instantiation.
  final String id;

  /// Human readable label shown in the chooser.
  final String label;

  /// Icon shown in the chooser and (by default) on the placed control.
  final IconData icon;

  /// Default width in grid cells.
  final int defaultCols;

  /// Default height in grid cells.
  final int defaultRows;

  const ControlType({
    required this.id,
    required this.label,
    required this.icon,
    this.defaultCols = 3,
    this.defaultRows = 2,
  });
}

/// A category grouping several [ControlType]s together in the chooser.
@immutable
class ControlCategory {
  final String title;
  final List<ControlType> controls;

  const ControlCategory({required this.title, required this.controls});
}

/// The full catalog of controls available to add from the menu.
///
/// This mirrors the categorized structure of XCTrack's widget list.
class ControlCatalog {
  const ControlCatalog._();

  static const List<ControlCategory> categories = [
    ControlCategory(
      title: 'System',
      controls: [
        ControlType(id: 'status_line', label: 'Status Line', icon: Icons.horizontal_rule, defaultCols: 6, defaultRows: 1),
        ControlType(id: 'clock', label: 'Clock', icon: Icons.schedule),
        ControlType(id: 'battery', label: 'Battery', icon: Icons.battery_full),
      ],
    ),
    ControlCategory(
      title: 'Flying',
      controls: [
        ControlType(id: 'altitude', label: 'Altitude', icon: Icons.terrain),
        ControlType(id: 'ground_speed', label: 'Ground Speed', icon: Icons.speed),
        ControlType(id: 'vertical_speed', label: 'Vertical Speed', icon: Icons.swap_vert),
        ControlType(id: 'glide_ratio', label: 'Glide Ratio', icon: Icons.trending_down),
        ControlType(id: 'air_time', label: 'Air Time', icon: Icons.timer_outlined),
      ],
    ),
    ControlCategory(
      title: 'Air',
      controls: [
        ControlType(id: 'wind_speed', label: 'Wind Speed', icon: Icons.air),
        ControlType(id: 'wind_direction', label: 'Wind Direction', icon: Icons.explore),
        ControlType(id: 'temperature', label: 'Temperature', icon: Icons.thermostat),
      ],
    ),
    ControlCategory(
      title: 'Navigation',
      controls: [
        ControlType(id: 'compass', label: 'Compass', icon: Icons.explore_outlined, defaultCols: 4, defaultRows: 4),
        ControlType(id: 'map', label: 'Map', icon: Icons.map, defaultCols: 6, defaultRows: 5),
        ControlType(id: 'bearing', label: 'Bearing', icon: Icons.navigation),
        ControlType(id: 'next_turnpoint', label: 'Next Turnpoint', icon: Icons.flag),
      ],
    ),
    ControlCategory(
      title: 'Buttons',
      controls: [
        ControlType(id: 'button_zoom', label: 'Zoom Button', icon: Icons.zoom_in, defaultCols: 2, defaultRows: 2),
        ControlType(id: 'button_camera', label: 'Camera Button', icon: Icons.photo_camera, defaultCols: 2, defaultRows: 2),
        ControlType(id: 'button_vario', label: 'Vario Button', icon: Icons.volume_up, defaultCols: 2, defaultRows: 2),
      ],
    ),
    ControlCategory(
      title: 'Others',
      controls: [
        ControlType(id: 'free_text', label: 'Free Text', icon: Icons.text_fields, defaultCols: 4, defaultRows: 2),
        ControlType(id: 'web_view', label: 'Web View', icon: Icons.web, defaultCols: 6, defaultRows: 4),
      ],
    ),
  ];

  /// Flat lookup of a control type by id.
  static ControlType? byId(String id) {
    for (final category in categories) {
      for (final control in category.controls) {
        if (control.id == id) return control;
      }
    }
    return null;
  }
}
