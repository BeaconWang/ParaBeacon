import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/main.dart';

void main() {
  testWidgets('Defaults to edit mode, grid and slider visible', (WidgetTester tester) async {
    await tester.pumpWidget(const ParaBeaconApp());

    // Slider and grid should be visible in default (edit) mode since panel has no controls
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('Menu contains Edit Mode toggle', (WidgetTester tester) async {
    await tester.pumpWidget(const ParaBeaconApp());

    // Open the menu by dragging down
    await tester.fling(find.byType(GestureDetector).first, const Offset(0, 200), 500);
    await tester.pumpAndSettle();

    // Edit Mode switch should be visible in the menu
    expect(find.text('Edit Mode'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
