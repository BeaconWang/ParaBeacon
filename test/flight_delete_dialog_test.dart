import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/flights_sheet.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_store.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlightRecorder.instance.clearTracks();
  });

  tearDown(() async {
    FlightRecorder.instance.clearTracks();
    await FlightStore.instance.flush(FlightRecorder.instance.tracks);
  });

  testWidgets('single delete dialog names the flight record', (tester) async {
    final keep = _track(DateTime.utc(2026, 9, 18, 9));
    final target = _track(DateTime.utc(2026, 9, 19, 10, 30))
      ..takeoffSite = 'Mount Test Launch';
    FlightRecorder.instance.importTracks([keep, target]);

    await _openFlights(tester);
    // Newest first: the first delete button belongs to [target].
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Delete flight?')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(_label(target))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Mount Test Launch')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(_label(keep))),
      findsNothing,
    );

    // Cancelling keeps the record.
    await tester.tap(find.descendant(of: dialog, matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(FlightRecorder.instance.tracks, contains(target));

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(FlightRecorder.instance.tracks, [keep]);
  });

  testWidgets('bulk delete dialog lists every selected flight record', (
    tester,
  ) async {
    final a = _track(DateTime.utc(2026, 9, 17, 8));
    final b = _track(DateTime.utc(2026, 9, 18, 9));
    final c = _track(DateTime.utc(2026, 9, 19, 10));
    FlightRecorder.instance.importTracks([a, b, c]);

    await _openFlights(tester);
    await tester.longPress(find.text(_label(c)));
    await tester.pump();
    await tester.tap(find.text(_label(a)));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text(_label(c))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(_label(a))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(_label(b))),
      findsNothing,
    );
  });
}

Future<void> _openFlights(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showFlightsSheet(context),
              child: const Text('Open flights'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open flights'));
  await tester.pumpAndSettle();
}

/// Same format as the Flights list title.
String _label(FlightTrack track) {
  final t = track.startTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

FlightTrack _track(DateTime start) {
  final track = FlightTrack(startTime: start);
  for (var i = 0; i < 3; i++) {
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: i * 20)),
        data: FlightData(
          altitude: 900 - i * 10,
          gpsAltitude: 900 - i * 10,
          latitude: 46.5 + i * 0.001,
          longitude: 6.6,
          hasFix: true,
        ),
      ),
    );
  }
  track.endTime = track.samples.last.time;
  return track;
}
