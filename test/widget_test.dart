import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/main.dart';

void main() {
  testWidgets('Dash grid renders with slider', (WidgetTester tester) async {
    await tester.pumpWidget(const ParaBeaconApp());

    // Should find the grid icon in the slider panel
    expect(find.byIcon(Icons.grid_on), findsOneWidget);

    // Should find a Slider widget
    expect(find.byType(Slider), findsOneWidget);

    // Default grid size is 50
    expect(find.text('50'), findsOneWidget);
  });
}
