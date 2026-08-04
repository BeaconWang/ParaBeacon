import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/main.dart';

void main() {
  testWidgets('Defaults to non-edit mode, no grid or slider', (WidgetTester tester) async {
    await tester.pumpWidget(const ParaBeaconApp());

    // Slider should NOT be visible in default (non-edit) mode
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(CustomPaint), findsNothing);
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
