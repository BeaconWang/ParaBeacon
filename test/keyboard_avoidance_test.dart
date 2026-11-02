import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/keyboard_avoidance.dart';

void main() {
  testWidgets('scrolls a focused field above the keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fieldKey = GlobalKey();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 700),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: KeyboardFocusScroller(
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 520),
                    TextField(key: fieldKey, focusNode: focusNode),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(find.byKey(fieldKey));
    expect(fieldRect.bottom, lessThanOrEqualTo(420));
  });
}
