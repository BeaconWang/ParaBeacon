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
  });

  group('Flight statistics aircraft grouping', () {
    test('groups only by paraglider manufacturer and category', () {
      final stats = FlightStatistics.compute([
        _aircraftTrack(
          faiClass: '3',
          manufacturer: ' Ozone ',
          model: 'Zeno',
          category: 'EN-B',
          gliderName: 'Ozone Zeno',
        ),
        _aircraftTrack(
          faiClass: '3',
          manufacturer: 'Ozone',
          model: 'Mantra',
          category: 'EN-B',
          gliderName: 'Ozone Mantra',
        ),
        _aircraftTrack(
          faiClass: '11',
          manufacturer: 'Ozone',
          model: 'Paramotor',
          category: 'EN-C',
        ),
        _aircraftTrack(
          faiClass: '1',
          manufacturer: 'Wills Wing',
          model: 'Sport 2',
          category: 'Class 1',
        ),
        _aircraftTrack(faiClass: '3', manufacturer: 'Advance', model: 'Sigma'),
      ], includeDetailed: false);

      expect(stats.byAircraft.map((bucket) => bucket.label).toList(), [
        'Ozone · EN-B',
        'Ozone · EN-C',
      ]);
      expect(stats.byAircraft.first.count, 2);
    });
  });
}

FlightTrack _aircraftTrack({
  required String faiClass,
  required String manufacturer,
  required String model,
  String? category,
  String? gliderName,
}) {
  return FlightTrack(startTime: DateTime.utc(2026, 10, 20))
    ..aircraftFaiClass = faiClass
    ..aircraftManufacturer = manufacturer
    ..aircraftModel = model
    ..aircraftCategory = category
    ..gliderName = gliderName;
}

FlightTrack _track() {
  final start = DateTime.utc(2026, 10, 20, 10);
  final track = FlightTrack(startTime: start);
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
