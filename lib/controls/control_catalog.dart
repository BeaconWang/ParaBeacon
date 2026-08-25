import 'package:flutter/material.dart';

/// Top-level directory a control belongs to.
///
/// The catalog is organized into two directories:
/// - [ControlKind.data]: data controls (values/readouts).
/// - [ControlKind.widget]: widget controls (interactive/visual widgets).
enum ControlKind {
  data,
  widget,
}

extension ControlKindX on ControlKind {
  /// Human readable directory title shown in the chooser.
  String get title {
    switch (this) {
      case ControlKind.data:
        return 'Data Control';
      case ControlKind.widget:
        return 'Widget Control';
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
}

/// A directory grouping several [ControlType]s together in the chooser.
@immutable
class ControlDirectory {
  final ControlKind kind;
  final List<ControlType> controls;

  const ControlDirectory({required this.kind, required this.controls});

  String get title => kind.title;
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
        ControlType(
          id: 'vertical_speed',
          label: 'Vertical Speed',
          icon: Icons.swap_vert,
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
