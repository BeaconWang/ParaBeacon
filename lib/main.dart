import 'package:flutter/material.dart';
import 'dart:ui' as ui;

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
  bool _isEditMode = false;

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
                if (_menuOpen) _closeMenu();
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
                onToggleEditMode: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
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

  const _MenuContent({
    required this.isEditMode,
    required this.onToggleEditMode,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      (_Icons.mode, 'Edit Mode', true),
      (_Icons.grid, 'Grid Settings', false),
      (_Icons.palette, 'Theme', false),
      (_Icons.layers, 'Layers', false),
      (_Icons.save, 'Save Project', false),
      (_Icons.folder, 'Open Project', false),
      (_Icons.settings, 'Preferences', false),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: menuItems.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final (icon, label, isToggle) = menuItems[index];
        if (isToggle) {
          return SwitchListTile(
            secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(label),
            value: isEditMode,
            onChanged: (_) => onToggleEditMode(),
          );
        }
        return ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () {
            // Placeholder: menu item tap
          },
        );
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
