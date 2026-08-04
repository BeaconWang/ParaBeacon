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

class _DashGridPageState extends State<DashGridPage> {
  double _gridSize = 50.0; // default grid cell size in logical pixels

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen dash grid
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: CustomPaint(
                painter: DashGridPainter(gridSize: _gridSize),
                size: Size.infinite,
              ),
            ),
          ),

          // Slider bar at the bottom
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
                min: 10.0,
                max: 200.0,
                divisions: 38, // step ≈ 5
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
