import 'control_catalog.dart';
import 'control_settings.dart';

/// A control instance placed on the dashboard grid.
///
/// Position and size are stored in grid-cell units so the layout stays
/// consistent when the grid size changes, matching how XCTrack stores widget
/// bounds in grid coordinates.
class PlacedControl {
  final String instanceId;
  final ControlType type;

  /// Column (x) of the top-left corner, in grid cells.
  int col;

  /// Row (y) of the top-left corner, in grid cells.
  int row;

  /// Width in grid cells.
  int cols;

  /// Height in grid cells.
  int rows;

  /// Per-instance configurable settings (see [settingsSchemaFor]).
  final Map<String, dynamic> settings;

  PlacedControl({
    required this.instanceId,
    required this.type,
    required this.col,
    required this.row,
    required this.cols,
    required this.rows,
    Map<String, dynamic>? settings,
  }) : settings = settings ?? defaultSettingsFor(type.id);

  factory PlacedControl.fromType(
    ControlType type, {
    required String instanceId,
    int col = 0,
    int row = 0,
  }) {
    return PlacedControl(
      instanceId: instanceId,
      type: type,
      col: col,
      row: row,
      cols: type.defaultCols,
      rows: type.defaultRows,
    );
  }

  /// Reads a bool setting, falling back to [fallback] if missing.
  bool boolSetting(String key, {bool fallback = false}) {
    final v = settings[key];
    return v is bool ? v : fallback;
  }

  /// Reads a double setting, falling back to [fallback] if missing.
  double doubleSetting(String key, {double fallback = 0.0}) {
    final v = settings[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return fallback;
  }

  /// Reads a setting value as-is.
  Object? setting(String key) => settings[key];

  /// Creates a copy at a new position with a fresh instance id, preserving
  /// size and settings (used for duplication).
  PlacedControl copyAt({
    required String instanceId,
    required int col,
    required int row,
  }) {
    return PlacedControl(
      instanceId: instanceId,
      type: type,
      col: col,
      row: row,
      cols: cols,
      rows: rows,
      settings: Map<String, dynamic>.from(settings),
    );
  }
}
