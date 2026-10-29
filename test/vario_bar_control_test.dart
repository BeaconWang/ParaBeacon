import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_settings.dart';
import 'package:parabeacon/controls/vario_control.dart';
import 'package:parabeacon/data/debug_settings.dart';
import 'package:parabeacon/data/flight_data_provider.dart';
import 'package:parabeacon/data/flight_data_transformer.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';

void _expectRectClose(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-9));
  expect(actual.top, closeTo(expected.top, 1e-9));
  expect(actual.right, closeTo(expected.right, 1e-9));
  expect(actual.bottom, closeTo(expected.bottom, 1e-9));
}

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
  group('varioGradientColorFor', () {
    test('maps the requested lift and sink key points', () {
      expect(varioGradientColorFor(-7), const Color(0xFF1E3A8A));
      expect(varioGradientColorFor(-3), const Color(0xFF2563EB));
      expect(varioGradientColorFor(0), const Color(0xFFFFFFFF));
      expect(varioGradientColorFor(3), const Color(0xFF16A34A));
      expect(varioGradientColorFor(7), const Color(0xFFDC2626));
      expect(varioGradientColorFor(double.nan), const Color(0xFFFFFFFF));
    });

    test('interpolates smoothly between palette anchors and clamps', () {
      final midpoint = varioGradientColorFor(-5);
      expect(midpoint, isNot(const Color(0xFF1E3A8A)));
      expect(midpoint, isNot(const Color(0xFF2563EB)));
      expect(varioGradientColorFor(-100), varioGradientColorFor(-7));
      expect(varioGradientColorFor(100), varioGradientColorFor(7));
    });
  });

  group('varioBarYFor', () {
    const size = Size(100, 600);

    test('maps signed values into a configurable scale', () {
      expect(varioBarYFor(size, 0), 300);
      expect(varioBarYFor(size, 10), 0);
      expect(varioBarYFor(size, -10), 600);
      expect(varioBarYFor(size, 2, minVarioValue: -4, maxVarioValue: 6), 240);
      expect(varioBarZeroReferenceYFor(size), 300);
      expect(
        varioBarZeroReferenceYFor(size, minVarioValue: -4, maxVarioValue: 6),
        360,
      );
      expect(
        varioBarZeroReferenceYFor(size, minVarioValue: 1, maxVarioValue: 6),
        isNull,
      );
    });

    test('clamps values and falls back for invalid scale bounds', () {
      expect(varioBarYFor(size, 100), 0);
      expect(varioBarYFor(size, -100), 600);
      expect(varioBarYFor(size, 10, minVarioValue: 10, maxVarioValue: -10), 0);
    });
  });

  group('varioBarFillRectFor', () {
    const size = Size(100, 600);

    test('fills between the zero baseline and instantaneous vario', () {
      _expectRectClose(
        varioBarFillRectFor(size, 4),
        const Rect.fromLTRB(0, 180, 100, 300),
      );
      _expectRectClose(
        varioBarFillRectFor(size, -4),
        const Rect.fromLTRB(0, 300, 100, 420),
      );
    });
  });

  group('varioBarMarkerRectFor', () {
    const size = Size(100, 600);

    test('positions a compact marker at the requested value', () {
      _expectRectClose(
        varioBarMarkerRectFor(size, 4),
        const Rect.fromLTRB(0, 169.5, 100, 190.5),
      );
      _expectRectClose(
        varioBarMarkerRectFor(size, -4),
        const Rect.fromLTRB(0, 409.5, 100, 430.5),
      );
    });

    test('keeps markers within the frame at and beyond both limits', () {
      _expectRectClose(
        varioBarMarkerRectFor(size, 10),
        const Rect.fromLTRB(0, 0, 100, 21),
      );
      _expectRectClose(
        varioBarMarkerRectFor(size, -100),
        const Rect.fromLTRB(0, 579, 100, 600),
      );
    });
  });

  group('average marker geometry', () {
    const size = Size(100, 600);

    test('average indicator is larger than the instantaneous slider', () {
      final live = varioBarMarkerRectFor(size, 3);
      final average = varioBarAverageMarkerRectFor(size, 3);
      expect(average.height, closeTo(size.height * 0.12, 1e-9));
      expect(average.height, greaterThan(live.height));
      expect(average.center.dy, live.center.dy);
    });

    test('average marker follows its own rolling value', () {
      expect(
        varioBarAverageMarkerRectFor(size, 6).center.dy,
        lessThan(varioBarMarkerRectFor(size, -1).center.dy),
      );
    });

    test('connecting line spans most of the bar between the arrows', () {
      final marker = varioBarAverageMarkerRectFor(const Size(100, 600), 2.0);
      expect(
        varioBarAverageConnectorWidthFor(marker),
        closeTo(marker.width * 0.76, 1e-9),
      );
    });
  });

  group('dual-indicator flight states', () {
    const size = Size(100, 600);

    test('weak vario stays close to the zero reference', () {
      final liveFill = varioBarFillRectFor(size, 0.2);
      final thermalMarker = varioBarMarkerRectFor(size, 0.1);
      expect(liveFill.height, lessThan(10));
      expect(thermalMarker.center.dy, closeTo(size.height / 2, 3));
    });

    test('sustained climb merges average marker into live fill', () {
      final liveFill = varioBarFillRectFor(size, 6.0);
      final thermalMarker = varioBarMarkerRectFor(size, 5.5);
      expect(liveFill.overlaps(thermalMarker), isTrue);
    });

    test('thermal boundary keeps high average separate from sinking vario', () {
      final liveFill = varioBarFillRectFor(size, -1.0);
      final thermalMarker = varioBarMarkerRectFor(size, 6.0);
      expect(liveFill.overlaps(thermalMarker), isFalse);
      expect(liveFill.top - thermalMarker.bottom, greaterThan(100));
    });
  });

  test(
    'vario settings expose scale limits and a configurable average window',
    () {
      final settings = defaultSettingsFor('vario');
      expect(settings['minScale'], -10.0);
      expect(settings['maxScale'], 10.0);
      expect(settings['avgDuration'], 30.0);
      expect(settings['showAverage'], isTrue);

      final averageToggle = settingsSchemaFor(
        'vario',
      ).singleWhere((setting) => setting.key == 'showAverage');
      expect(averageToggle.kind, SettingKind.toggle);
      expect(averageToggle.defaultValue, isTrue);

      final averageSetting = settingsSchemaFor(
        'vario',
      ).singleWhere((setting) => setting.key == 'avgDuration');
      expect(averageSetting.min, 5.0);
      expect(averageSetting.max, 60.0);
      expect(averageSetting.unit, 's');
    },
  );

  test('VarioAverageWindow honors a user-selected duration', () {
    final window = VarioAverageWindow(const Duration(seconds: 5));
    final start = DateTime.utc(2026, 1, 1);
    window.add(1, time: start);
    window.add(4, time: start.add(const Duration(seconds: 4)));

    expect(window.averageAt(start.add(const Duration(seconds: 6))), 4);
  });

  test('VarioAverageWindow computes a rolling 30-second average', () {
    final window = VarioAverageWindow(const Duration(seconds: 30));
    final start = DateTime.utc(2026, 1, 1);
    window.add(2, time: start);
    window.add(4, time: start.add(const Duration(seconds: 15)));

    expect(window.averageAt(start.add(const Duration(seconds: 15))), 3);
    expect(window.averageAt(start.add(const Duration(seconds: 30))), 4);
    window.add(10, time: start.add(const Duration(seconds: 30)));
    expect(window.averageAt(start.add(const Duration(seconds: 30))), 7);
    expect(
      window.averageAt(start.add(const Duration(seconds: 61)), fallback: 1.5),
      1.5,
    );
  });

  testWidgets(
    'samples live flight data for its instantaneous and average values',
    (tester) async {
      final source = BluetoothSensorFlightDataSource(
        debugSettings: DebugSettings.instance,
      );
      final transformer = FlightDataTransformer(rawSource: source);
      addTearDown(() {
        transformer.dispose();
        source.dispose();
      });

      source.ingestVerticalSpeed(0.2);
      await tester.pumpWidget(
        MaterialApp(
          home: FlightDataProvider(
            transformer: transformer,
            child: const Scaffold(
              body: SizedBox(width: 72, height: 240, child: VarioBarControl()),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      source.ingestVerticalSpeed(4.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.descendant(
          of: find.byType(VarioBarControl),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('paints the glass housing in light and dark themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: SizedBox(
              width: 36,
              height: 180,
              child: VarioBarControl(varioValue: -4.2, avgVarioValue: 2.8),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('glass column shows backgrounds through its transparent well', (
    tester,
  ) async {
    const boundaryKey = ValueKey('transparent-vario');

    Future<Color> renderOver(Color background, Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: background,
                  child: const SizedBox(
                    width: 100,
                    height: 400,
                    child: VarioBarControl(varioValue: 0, showAverage: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return _pixelAt(tester, boundaryKey, 50, 40);
    }

    for (final brightness in Brightness.values) {
      final overRed = await renderOver(Colors.red, brightness);
      final overBlue = await renderOver(Colors.blue, brightness);
      expect(overRed, isNot(overBlue));
    }
  });

  testWidgets('can hide the average-speed indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            height: 240,
            child: VarioBarControl(
              varioValue: 3.2,
              avgVarioValue: 2.4,
              showAverage: false,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<VarioBarControl>(find.byType(VarioBarControl)).showAverage,
      isFalse,
    );
  });

  testWidgets('renders dual indicator inputs without numeric labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            height: 240,
            child: VarioBarControl(varioValue: 3.2, avgVarioValue: 2.4),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(VarioBarControl),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(VarioBarControl),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });
}
