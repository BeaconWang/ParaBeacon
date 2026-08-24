import 'control_catalog.dart';

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

  PlacedControl({
    required this.instanceId,
    required this.type,
    required this.col,
    required this.row,
    required this.cols,
    required this.rows,
  });

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
}
