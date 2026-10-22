import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parabeacon/data/auto_flight_detector.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:parabeacon/main.dart';

void main() {
  // In widget tests the SharedPreferences platform channel never answers,
  // which would leave the async layout load (and the edit-mode bootstrap)
  // hanging forever. Mock in-memory values instead.
  SharedPreferences.setMockInitialValues({});

  // Voice announcements are on by default and warm up the text-to-speech
  // engine at startup. Answer its channel immediately so no call is left
  // waiting on its timeout after the test ends.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => call.method == 'getEngines' ? <String>[] : 1,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

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

  testWidgets('Empty dashboard bootstraps edit mode; menu carries the slider', (
    WidgetTester tester,
  ) async {
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
        find.byType(GestureDetector).first,
        const Offset(0, 600),
      );
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  testWidgets('Preferences exposes shared automatic flight settings', (
    WidgetTester tester,
  ) async {
    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(GestureDetector).first,
        const Offset(0, 600),
      );
      await tester.pump();
      final preferences = find.text('Preferences');
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pump();
      await tester.ensureVisible(preferences);
      await tester.tap(preferences);
      await tester.pumpAndSettle();

      final autoFlightSettings = find.text('Auto take-off / landing');
      await tester.ensureVisible(autoFlightSettings);
      await tester.tap(autoFlightSettings);
      await tester.pumpAndSettle();

      final parameterSliders = find.byWidgetPredicate(
        (widget) => widget is Slider && widget.onChangeEnd != null,
      );
      expect(parameterSliders, findsNWidgets(3));
      await tester.tap(find.text('Manual confirmation'));
      await tester.pump();
      expect(FlightState.instance.landingMode, LandingDetectionMode.manual);

      FlightState.instance.setAutoDetect(false);
      await tester.drag(parameterSliders.first, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(FlightState.instance.takeoffSpeedKph, greaterThan(6));

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(FlightState.instance.autoDetect, isTrue);
      expect(FlightState.instance.landingMode, FlightState.defaultLandingMode);
      expect(
        FlightState.instance.takeoffSpeedKph,
        FlightState.defaultTakeoffSpeedKph,
      );
      expect(
        FlightState.instance.minimumLandingFlightSeconds,
        FlightState.defaultMinimumLandingFlightSeconds,
      );
      expect(
        FlightState.instance.landingSpeedSensitivity,
        FlightState.defaultLandingSpeedSensitivity,
      );
    });
  });

  testWidgets('Menu opens only after being pulled fully down', (
    WidgetTester tester,
  ) async {
    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());

      // A partial pull is released without opening the menu.
      final gestureTarget = find.byType(GestureDetector).first;
      final editModeMenuLabel = find.descendant(
        of: find.byType(SwitchListTile),
        matching: find.text('Edit Mode'),
      );
      await tester.drag(gestureTarget, const Offset(0, 100));
      await tester.pump();
      expect(tester.getTopLeft(editModeMenuLabel).dy, lessThan(0));

      // Pulling past the panel height clamps at the fully-open position and
      // keeps the menu open without a snap animation.
      await tester.drag(gestureTarget, const Offset(0, 600));
      await tester.pump();

      expect(tester.getTopLeft(editModeMenuLabel).dy, greaterThanOrEqualTo(0));
      expect(editModeMenuLabel, findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });
}
