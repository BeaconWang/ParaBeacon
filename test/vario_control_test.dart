import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/vario_control.dart';

Future<Color> _pixelAt(
  WidgetTester tester,
  Key boundaryKey,
  int x,
  int y,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await boundary.toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final pixel = (y * image.width + x) * 4;
  final color = Color.fromARGB(
    bytes.getUint8(pixel + 3),
    bytes.getUint8(pixel),
    bytes.getUint8(pixel + 1),
    bytes.getUint8(pixel + 2),
  );
  image.dispose();
  return color;
}

void main() {
  group('varioColorFor', () {
    test('uses the requested colors at each speed key point', () {
      expect(varioColorFor(-10), const Color(0xFF000B1E));
      expect(varioColorFor(-7), const Color(0xFF0D47A1));
      expect(varioColorFor(-3), const Color(0xFF00BCD4));
      expect(varioColorFor(0), const Color(0xFF9E9E9E));
      expect(varioColorFor(3), const Color(0xFF4CAF50));
      expect(varioColorFor(7), const Color(0xFFF44336));
      expect(varioColorFor(10), const Color(0xFF4A0033));
    });

    test('interpolates between adjacent stops and clamps extremes', () {
      final midpoint = varioColorFor(-8.5);
      expect(midpoint, isNot(const Color(0xFF000B1E)));
      expect(midpoint, isNot(const Color(0xFF0D47A1)));
      expect(varioColorFor(-100), varioColorFor(-10));
      expect(varioColorFor(100), varioColorFor(10));
    });

    test('uses neutral gray for NaN', () {
      expect(varioColorFor(double.nan), const Color(0xFF9E9E9E));
    });
  });

  testWidgets('paints the active fill with a vertical gradient', (
    tester,
  ) async {
    const boundaryKey = ValueKey<String>('vario-gradient');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const SizedBox(
                width: 100,
                height: 200,
                child: VarioControl(verticalSpeed: 10, maxScale: 10),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final redRegion = await _pixelAt(tester, boundaryKey, 50, 29);
    final greenRegion = await _pixelAt(tester, boundaryKey, 50, 69);
    expect(redRegion, isNot(greenRegion));
  });
}
