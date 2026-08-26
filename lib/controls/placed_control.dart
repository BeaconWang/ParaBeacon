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

  /// Serializes this control to a JSON-safe map for layout persistence.
  ///
  /// Only the [ControlType.id] is stored (not the whole type); on load it is
  /// resolved back via [ControlCatalog.byId]. Settings are stored as-is, so
  /// they must contain only JSON-encodable values (bool/num/String), which the
  /// settings schema guarantees.
  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'typeId': type.id,
        'col': col,
        'row': row,
        'cols': cols,
        'rows': rows,
        'settings': settings,
      };

  /// Rebuilds a control from [toJson] output. Returns null if the type id is
  /// no longer known (e.g. a control removed from the catalog).
  static PlacedControl? fromJson(Map<String, dynamic> json) {
    final typeId = json['typeId'] as String?;
    if (typeId == null) return null;
    final type = ControlCatalog.byId(typeId);
    if (type == null) return null;

    // Start from the type defaults, then overlay any persisted settings so a
    // layout saved before a new setting existed still gets sensible defaults.
    final settings = defaultSettingsFor(typeId);
    final saved = json['settings'];
    if (saved is Map) {
      saved.forEach((k, v) => settings[k.toString()] = v);
    }

    return PlacedControl(
      instanceId: (json['instanceId'] as String?) ?? 'ctrl',
      type: type,
      col: (json['col'] as num?)?.toInt() ?? 0,
      row: (json['row'] as num?)?.toInt() ?? 0,
      cols: (json['cols'] as num?)?.toInt() ?? type.defaultCols,
      rows: (json['rows'] as num?)?.toInt() ?? type.defaultRows,
      settings: settings,
    );
  }
}
