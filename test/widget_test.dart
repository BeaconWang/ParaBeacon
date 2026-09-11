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

  testWidgets('Menu opens only after being pulled fully down',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ParaBeaconApp());

    // A partial pull is released without opening the menu.
    final gestureTarget = find.byType(GestureDetector).first;
    await tester.drag(gestureTarget, const Offset(0, 100));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Edit Mode')).dy, lessThan(0));

    // Pulling past the panel height clamps at the fully-open position and
    // keeps the menu open without a snap animation.
    await tester.drag(gestureTarget, const Offset(0, 600));
    await tester.pump();

    expect(tester.getTopLeft(find.text('Edit Mode')).dy, greaterThanOrEqualTo(0));
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
