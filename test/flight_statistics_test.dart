import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/flight_statistics_sheet.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_statistics.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flight statistics detail priority', () {
    test('summary can be computed and later filled with detailed metrics', () {
      final track = _track();
      final summary = FlightStatistics.compute([track], includeDetailed: false);
      final full = FlightStatistics.compute([track]);

      expect(summary.flightCount, 1);
      expect(summary.flightsWithSamples, 1);
      expect(summary.totalTrackDistanceM, greaterThan(0));
      expect(summary.totalStraightDistanceM, 0);
      expect(summary.maxSpeedKph, isNull);

      summary.addDetailedTrackStats(track, FlightDerivedStats.compute(track));
      expect(summary.totalStraightDistanceM, full.totalStraightDistanceM);
      expect(summary.totalAltitudeGainedM, full.totalAltitudeGainedM);
      expect(summary.avgSpeedKph, full.avgSpeedKph);
      expect(summary.maxSpeedKph?.value, full.maxSpeedKph?.value);
    });

    testWidgets(
      'detailed priority computes flight metrics off the UI isolate',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showFlightStatisticsSheet(
                      context,
                      tracks: [track],
                      selected: false,
                    ),
                    child: const Text('Open stats'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open stats'));
        await tester.pumpAndSettle();
        expect(find.text('Summary first'), findsOneWidget);
        expect(find.byTooltip('Share card'), findsOneWidget);
        expect(find.text('0.0 km'), findsOneWidget);

        await tester.tap(find.text('Detailed stats'));
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 20));

        expect(find.text('1.1 km'), findsWidgets);
      },
    );

    testWidgets('shows manufacturer and model on one line on phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final track = _aircraftTrack(manufacturer: 'Ozone', model: 'Zeno');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showFlightStatisticsSheet(
                    context,
                    tracks: [track],
                    selected: false,
                  ),
                  child: const Text('Open stats'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open stats'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ozone Zeno'),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Ozone Zeno'), findsOneWidget);
      expect(find.text('Ozone'), findsNothing);
      expect(find.text('Zeno'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Flight statistics aircraft grouping', () {
    test('groups by manufacturer/model with missing-data fallbacks', () {
      final stats = FlightStatistics.compute([
        _aircraftTrack(manufacturer: ' Ozone ', model: 'Zeno'),
        _aircraftTrack(manufacturer: 'Ozone', model: 'Mantra'),
        _aircraftTrack(manufacturer: 'Ozone'),
        _aircraftTrack(manufacturer: ' Ozone '),
        _aircraftTrack(),
        _aircraftTrack(manufacturer: ' ', model: ' '),
        _aircraftTrack(model: 'Solo model'),
      ], includeDetailed: false);

      final buckets = stats.byAircraft;
      final manufacturerOnly = buckets.singleWhere(
        (bucket) => bucket.label == 'Ozone' && bucket.subtitle == null,
      );
      final zeno = buckets.singleWhere((bucket) => bucket.subtitle == 'Zeno');
      final mantra = buckets.singleWhere(
        (bucket) => bucket.subtitle == 'Mantra',
      );
      final modelOnly = buckets.singleWhere(
        (bucket) => bucket.label == 'Solo model',
      );
      final unknown = buckets.singleWhere((bucket) => bucket.isUnknownType);

      expect(manufacturerOnly.count, 2);
      expect(zeno.label, 'Ozone');
      expect(mantra.label, 'Ozone');
      expect(modelOnly.subtitle, isNull);
      expect(unknown.label, 'Unknown type');
      expect(unknown.count, 2);
    });
  });
}

FlightTrack _aircraftTrack({String? manufacturer, String? model}) {
  return FlightTrack(startTime: DateTime.utc(2026, 10, 20))
    ..aircraftManufacturer = manufacturer
    ..aircraftModel = model;
}

FlightTrack _track() {
  final start = DateTime.utc(2026, 10, 20, 10);
  final track = FlightTrack(startTime: start)
    ..aircraftManufacturer = 'Ozone'
    ..aircraftModel = 'Zeno';
  track.add(
    FlightSample(
      time: start,
      data: const FlightData(
        latitude: 46.0,
        longitude: 7.0,
        altitude: 1000,
        gpsAltitude: 1000,
        groundSpeed: 36,
        hasFix: true,
      ),
    ),
  );
  track.add(
    FlightSample(
      time: start.add(const Duration(minutes: 1)),
      data: const FlightData(
        latitude: 46.0,
        longitude: 7.014,
        altitude: 1100,
        gpsAltitude: 1100,
        groundSpeed: 40,
        hasFix: true,
      ),
    ),
  );
  track.endTime = start.add(const Duration(minutes: 1));
  return track;
}
