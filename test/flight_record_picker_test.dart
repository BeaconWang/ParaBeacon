import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/flights_sheet.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/landing_point_flight_import.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlightRecorder.instance.clearTracks();
  });

  tearDown(() {
    FlightRecorder.instance.clearTracks();
  });

  testWidgets('picker returns the selected flight record', (tester) async {
    final first = _track(DateTime.utc(2026, 10, 19, 10), 'First Launch', 46.1);
    final target = _track(
      DateTime.utc(2026, 10, 20, 11),
      'Selected Launch',
      47.2,
    );
    FlightRecorder.instance.importTracks([first, target]);
    FlightTrack? selected;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showFlightRecordPicker(context);
              },
              child: const Text('Choose flight'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose flight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Launch'));
    await tester.pumpAndSettle();

    expect(selected, same(target));
    final location = LandingPointFlightLocation.fromTrack(selected!);
    expect(location?.latitude, closeTo(47.22, 0.000001));
    expect(location?.longitude, 6.6);
    expect(location?.capturedAt, target.samples.last.time);
  });

  testWidgets('records without a landing fix cannot be selected', (
    tester,
  ) async {
    final noFix = FlightTrack(startTime: DateTime.utc(2026, 10, 20))
      ..endTime = DateTime.utc(2026, 10, 20, 1);
    FlightRecorder.instance.importTracks([noFix]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFlightRecordPicker(context),
              child: const Text('Choose flight'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose flight'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No recorded landing location'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile).last).onTap, isNull);
  });
}

FlightTrack _track(DateTime start, String takeoffSite, double latitude) {
  final track = FlightTrack(startTime: start)..takeoffSite = takeoffSite;
  for (var index = 0; index < 3; index++) {
    track.add(
      FlightSample(
        time: start.add(Duration(minutes: index)),
        data: FlightData(
          latitude: latitude + index * 0.01,
          longitude: 6.6,
          gpsAltitude: 1200.0 + index,
          hasFix: true,
        ),
      ),
    );
  }
  track.endTime = track.samples.last.time;
  return track;
}
