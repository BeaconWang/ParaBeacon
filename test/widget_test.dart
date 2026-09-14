import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parabeacon/main.dart';

void main() {
  // In widget tests the SharedPreferences platform channel never answers,
  // which would leave the async layout load (and the edit-mode bootstrap)
  // hanging forever. Mock in-memory values instead.
  SharedPreferences.setMockInitialValues({});

  /// Overrides the target platform to Windows for the duration of a test.
  ///
  /// flutter_test reports the target platform as "android", which makes the
  /// BLE init path run and throw (flutter_blue_plus has no test binding).
  /// The test host is really Windows, where BLE is a guarded no-op — mirror
  /// that so startup stays deterministic. Reset in a finally block because
  /// the test binding verifies debug-variable invariants before package
  /// tearDowns run.
  Future<void> runWithWindowsPlatform(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('Empty dashboard bootstraps edit mode; menu carries the slider',
      (WidgetTester tester) async {
    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());

      // The async layout load completes and, finding no controls, flips the
      // dashboard into edit mode so the grid is painted.
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DashGridPainter,
        ),
        findsOneWidget,
      );

      // The grid-size slider lives in the swipe-down top menu.
      await tester.drag(
          find.byType(GestureDetector).first, const Offset(0, 600));
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  testWidgets('Menu opens only after being pulled fully down',
      (WidgetTester tester) async {
    await runWithWindowsPlatform(() async {
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

      expect(tester.getTopLeft(find.text('Edit Mode')).dy,
          greaterThanOrEqualTo(0));
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });
}
