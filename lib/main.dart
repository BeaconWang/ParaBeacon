import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'controls/add_control_sheet.dart';
import 'controls/control_catalog.dart';
import 'controls/control_widget.dart';
import 'controls/placed_control.dart';

void main() {
  runApp(const ParaBeaconApp());
}

class ParaBeaconApp extends StatelessWidget {
  const ParaBeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParaBeacon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashGridPage(),
    );
  }
}

class DashGridPage extends StatefulWidget {
  const DashGridPage({super.key});

  @override
  State<DashGridPage> createState() => _DashGridPageState();
}

class _DashGridPageState extends State<DashGridPage>
    with SingleTickerProviderStateMixin {
  double _gridSize = 48.0;
  bool _menuOpen = false;
  bool _isEditMode = true;

  // Controls placed on the dashboard grid.
  final List<PlacedControl> _controls = [];
  String? _selectedControlId;
  int _controlSeq = 0;

  // Accumulated pixel offset during a control drag (before grid snapping).
  Offset _dragAccum = Offset.zero;
  int _dragStartCol = 0;
  int _dragStartRow = 0;

  late final AnimationController _menuController;
  late final Animation<double> _menuAnimation;

  // Drag state
  double _dragOffset = 0.0;
  double _menuHeight = 300.0; // will be sized in build

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _menuController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _openMenu() {
    _menuOpen = true;
    _menuController.value = (_dragOffset / _menuHeight).clamp(0.0, 1.0);
    _menuController.forward();
  }

  void _closeMenu() {
    _menuOpen = false;
    _menuController.value = (_dragOffset / _menuHeight).clamp(0.0, 1.0);
    _menuController.reverse();
  }

  void _onDragStart(DragStartDetails details) {
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _menuHeight);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > _menuHeight * 0.4) {
      // Snap open
      _openMenu();
    } else {
      // Snap closed
      _closeMenu();
    }
    _dragOffset = 0.0;
  }

  double get _effectiveMenuOffset {
    if (_menuController.isAnimating || _menuOpen) {
      return _menuHeight * _menuAnimation.value;
    }
    return _dragOffset;
  }

  /// Handles a tap on a menu item.
  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'add_control':
        _closeMenu();
        await _addControlFromMenu();
        break;
      case 'toggle_edit':
        setState(() {
          _isEditMode = !_isEditMode;
          if (!_isEditMode) _selectedControlId = null;
        });
        break;
    }
  }

  /// Opens the control chooser and, on selection, places the new control on
  /// the grid at the first free spot.
  Future<void> _addControlFromMenu() async {
    final ControlType? type = await showAddControlSheet(context);
    if (type == null || !mounted) return;

    final position = _findFreeCell(type.defaultCols, type.defaultRows);
    setState(() {
      final control = PlacedControl.fromType(
        type,
        instanceId: 'ctrl_${_controlSeq++}',
        col: position.$1,
        row: position.$2,
      );
      _controls.add(control);
      _selectedControlId = control.instanceId;
      // Adding a control implies we want to see/edit it.
      _isEditMode = true;
    });
  }

  /// Finds a grid cell (col, row) where a control of the given size does not
  /// overlap an existing one. Falls back to (0, 0) if the grid is full.
  (int, int) _findFreeCell(int cols, int rows) {
    final size = MediaQuery.of(context).size;
    final maxCols = (size.width / _gridSize).floor();
    final maxRows = (size.height / _gridSize).floor();

    for (int row = 0; row + rows <= maxRows; row++) {
      for (int col = 0; col + cols <= maxCols; col++) {
        if (!_overlapsExisting(col, row, cols, rows)) {
          return (col, row);
        }
      }
    }
    return (0, 0);
  }

  bool _overlapsExisting(int col, int row, int cols, int rows) {
    for (final c in _controls) {
      final overlapX = col < c.col + c.cols && col + cols > c.col;
      final overlapY = row < c.row + c.rows && row + rows > c.row;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  void _deleteControl(String instanceId) {
    setState(() {
      _controls.removeWhere((c) => c.instanceId == instanceId);
      if (_selectedControlId == instanceId) _selectedControlId = null;
    });
  }

  void _onControlDragStart(PlacedControl control) {
    _dragAccum = Offset.zero;
    _dragStartCol = control.col;
    _dragStartRow = control.row;
    setState(() => _selectedControlId = control.instanceId);
  }

  void _onControlDragUpdate(PlacedControl control, Offset delta) {
    _dragAccum += delta;
    setState(() {
      final size = MediaQuery.of(context).size;
      final maxCols = (size.width / _gridSize).floor();
      final maxRows = (size.height / _gridSize).floor();

      final colDelta = (_dragAccum.dx / _gridSize).round();
      final rowDelta = (_dragAccum.dy / _gridSize).round();

      control.col = (_dragStartCol + colDelta)
          .clamp(0, (maxCols - control.cols).clamp(0, maxCols));
      control.row = (_dragStartRow + rowDelta)
          .clamp(0, (maxRows - control.rows).clamp(0, maxRows));
    });
  }


  @override
  Widget build(BuildContext context) {
    _menuHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen main panel (drag down anywhere to open menu, tap to dismiss)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_menuOpen) {
                  _closeMenu();
                } else if (_selectedControlId != null) {
                  setState(() => _selectedControlId = null);
                }
              },
              onVerticalDragStart: _menuOpen ? null : _onDragStart,
              onVerticalDragUpdate: _menuOpen ? null : _onDragUpdate,
              onVerticalDragEnd: _menuOpen ? null : _onDragEnd,
              child: _isEditMode
                  ? CustomPaint(
                      painter: DashGridPainter(gridSize: _gridSize),
                      size: Size.infinite,
                    )
                  : const SizedBox.expand(),
            ),
          ),

          // Placed controls layer.
          ..._buildPlacedControls(),


          // Dim overlay when menu is open
          if (_effectiveMenuOffset > 0 || _menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                child: Container(color: Colors.black.withAlpha(80)),
              ),
            ),

          // Top swipe menu panel
          Positioned(
            left: 0,
            right: 0,
            top: _effectiveMenuOffset - _menuHeight,
            child: _buildMenuPanel(),
          ),

          // Slider bar at the bottom (only in edit mode)
          if (_isEditMode)
            Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSliderPanel(),
          ),
        ],
      ),
    );
  }

  /// Builds the positioned control widgets, laid out by grid cell.
  List<Widget> _buildPlacedControls() {
    return _controls.map((control) {
      final left = control.col * _gridSize;
      final top = control.row * _gridSize;
      final width = control.cols * _gridSize;
      final height = control.rows * _gridSize;
      final isSelected = _selectedControlId == control.instanceId;

      final child = ControlWidget(
        control: control,
        isEditMode: _isEditMode,
        isSelected: isSelected,
        onTap: _isEditMode
            ? () => setState(() => _selectedControlId = control.instanceId)
            : null,
        onDelete: () => _deleteControl(control.instanceId),
      );

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: _isEditMode
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _onControlDragStart(control),
                onPanUpdate: (details) =>
                    _onControlDragUpdate(control, details.delta),
                child: child,
              )
            : child,
      );
    }).toList();
  }

  Widget _buildMenuPanel() {
    return Container(
      height: _menuHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Drag handle inside menu
            SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Dismiss gesture on the handle
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 300) {
                  _closeMenu();
                }
              },
              child: const SizedBox(height: 0),
            ),
            // Menu items
            Expanded(
              child: _MenuContent(
                isEditMode: _isEditMode,
                onToggleEditMode: () => _onMenuAction('toggle_edit'),
                onAddControl: () => _onMenuAction('add_control'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.grid_on, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: _gridSize,
                min: 16.0,
                max: 120.0,
                divisions: 26, // step = 4px
                label: '${_gridSize.round()} px',
                onChanged: (value) {
                  setState(() {
                    _gridSize = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${_gridSize.round()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onToggleEditMode;
  final VoidCallback onAddControl;

  const _MenuContent({
    required this.isEditMode,
    required this.onToggleEditMode,
    required this.onAddControl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        SwitchListTile(
          secondary: Icon(_Icons.mode, color: theme.colorScheme.primary),
          title: const Text('Edit Mode'),
          value: isEditMode,
          onChanged: (_) => onToggleEditMode(),
        ),
        // "Add Control" is only meaningful in edit mode.
        if (isEditMode) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.add_box_outlined, color: theme.colorScheme.primary),
            title: const Text('Add Control'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddControl,
          ),
        ],
        const Divider(height: 1),
        _staticItem(context, _Icons.grid, 'Grid Settings'),
        const Divider(height: 1),
        _staticItem(context, _Icons.palette, 'Theme'),
        const Divider(height: 1),
        _staticItem(context, _Icons.layers, 'Layers'),
        const Divider(height: 1),
        _staticItem(context, _Icons.save, 'Save Project'),
        const Divider(height: 1),
        _staticItem(context, _Icons.folder, 'Open Project'),
        const Divider(height: 1),
        _staticItem(context, _Icons.settings, 'Preferences'),
      ],
    );
  }

  Widget _staticItem(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        // Placeholder: menu item tap
      },
    );
  }
}

// Icon aliases for cleaner table definition
const _Icons = (
  mode: Icons.edit_outlined,
  grid: Icons.grid_4x4,
  palette: Icons.palette_outlined,
  layers: Icons.layers_outlined,
  save: Icons.save_outlined,
  folder: Icons.folder_open_outlined,
  settings: Icons.settings_outlined,
);

class DashGridPainter extends CustomPainter {
  final double gridSize;

  DashGridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..strokeWidth = 0.5;

    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(25)
      ..strokeWidth = 0.5;

    // Draw solid grid lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw dashed sub-grid lines at half intervals
    if (gridSize >= 30) {
      final half = gridSize / 2;
      for (double x = half; x <= size.width; x += gridSize) {
        _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), dashPaint);
      }
      for (double y = half; y <= size.height; y += gridSize) {
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), dashPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashGap = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = dx == 0 ? dy.abs() : dx.abs();
    final dirX = dx == 0 ? 0.0 : dx.sign;
    final dirY = dy == 0 ? 0.0 : dy.sign;

    double drawn = 0;
    while (drawn < len) {
      final segment = (drawn + dashWidth > len) ? len - drawn : dashWidth;
      final from = Offset(start.dx + drawn * dirX, start.dy + drawn * dirY);
      final to = Offset(
        from.dx + segment * dirX,
        from.dy + segment * dirY,
      );
      canvas.drawLine(from, to, paint);
      drawn += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(DashGridPainter oldDelegate) {
    return gridSize != oldDelegate.gridSize;
  }
}
