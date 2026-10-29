import 'dart:convert';

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
  // Voice announcements are on by default and warm up the text-to-speech
  // engine at startup. Answer its channel immediately so no call is left
  // waiting on its timeout after the test ends. Mock preferences for each test
  // so startup layout state is isolated and deterministic.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

      await tester.pumpAndSettle();
      expect(
        find.text(
          'The interface is blank. Do you want to load a preset interface?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('No'));
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

  testWidgets('Yes loads the Default template on a blank single page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(384, 832);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The interface is blank. Do you want to load a preset interface?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      final preferences = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(preferences.getString('pb.layout.v1')!)
              as Map<String, dynamic>;
      final pages = saved['pages'] as List<dynamic>;
      expect(pages, hasLength(1));
      final controls =
          (pages.single as Map<String, dynamic>)['controls'] as List<dynamic>;
      expect(controls, hasLength(21));
      expect(
        controls.map((control) => (control as Map<String, dynamic>)['typeId']),
        containsAll(['map', 'vario', 'flight_button']),
      );
    });
  });

  testWidgets('multiple empty pages do not prompt for a preset', (
    WidgetTester tester,
  ) async {
    final layout = jsonEncode({
      'version': 1,
      'gridSize': 32.0,
      'currentPage': 0,
      'pages': [
        {'id': 'page_0', 'controls': <dynamic>[]},
        {'id': 'page_1', 'controls': <dynamic>[]},
      ],
    });
    SharedPreferences.setMockInitialValues({'pb.layout.v1': layout});

    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The interface is blank. Do you want to load a preset interface?',
        ),
        findsNothing,
      );
    });
  });

  testWidgets('Preferences exposes shared automatic flight settings', (
    WidgetTester tester,
  ) async {
    await runWithWindowsPlatform(() async {
      await tester.pumpWidget(const ParaBeaconApp());
      await tester.pumpAndSettle();
      await _declineBlankPromptIfVisible(tester);

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
      await tester.pumpAndSettle();
      await _declineBlankPromptIfVisible(tester);

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

  testWidgets(
    'Interface lock exposes a timed unlock page and action sequence',
    (WidgetTester tester) async {
      FlightState.instance.stop();
      FlightState.instance.setAutoDetect(true);

      await runWithWindowsPlatform(() async {
        await tester.pumpWidget(const ParaBeaconApp());
        await tester.pumpAndSettle();
        await _declineBlankPromptIfVisible(tester);

        await tester.drag(
          find.byType(GestureDetector).first,
          const Offset(0, 600),
        );
        await tester.pump();
        expect(find.text('Lock interface'), findsOneWidget);

        FlightState.instance.setAutoDetect(false);
        await tester.pump();
        expect(find.text('Lock interface'), findsNothing);
        FlightState.instance.setAutoDetect(true);
        await tester.pump();
        expect(find.text('Lock interface'), findsOneWidget);
        await tester.ensureVisible(find.text('Lock interface'));
        await tester.tap(find.text('Lock interface'));
        await tester.pumpAndSettle();

        final pageView = find.byType(PageView);
        await tester.drag(pageView, const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(find.text('Interface locked'), findsOneWidget);

        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('Interface locked'), findsNothing);
        expect(find.text('Lock interface'), findsNothing);

        await tester.drag(pageView, const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(find.text('Interface locked'), findsOneWidget);

        for (final step in ['1', '2', '3']) {
          await tester.tap(find.text(step));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Interface locked'), findsNothing);

        await tester.drag(
          find.byType(GestureDetector).first,
          const Offset(0, 600),
        );
        await tester.pump();
        expect(find.text('Lock interface'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
      });
    },
  );
}

Future<void> _declineBlankPromptIfVisible(WidgetTester tester) async {
  final prompt = find.text(
    'The interface is blank. Do you want to load a preset interface?',
  );
  if (prompt.evaluate().isEmpty) return;
  await tester.tap(find.text('No'));
  await tester.pumpAndSettle();
}
