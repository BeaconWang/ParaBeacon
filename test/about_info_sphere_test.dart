import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/about_info_sphere.dart';

void main() {
  testWidgets('sphere drag does not scroll its parent About content', (
    tester,
  ) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 80),
                const AboutInfoSphere(
                  labels: ['APP', 'VARIO', 'SENSORS'],
                  semanticsLabel: 'Information sphere',
                  dragHint: 'Drag to rotate',
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(AboutInfoSphere), const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 50));
    expect(scrollController.offset, 0);

    await tester.dragFrom(const Offset(400, 40), const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 50));
    expect(scrollController.offset, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    scrollController.dispose();
  });
}
