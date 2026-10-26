import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/flight_replay_sheet.dart';
import 'package:parabeacon/controls/replay_gaps.dart';
import 'package:parabeacon/controls/track_3d_sheet.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_merge.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_store.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ~111 m per 0.001° of latitude.
const double _degPerKm = 1 / 111.32;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final base = DateTime.utc(2026, 9, 19, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlightRecorder.instance.clearTracks();
  });

  group('FlightMergeValidator', () {
    test('accepts consecutive flights within time and distance limits', () {
      final a = _track(base, lat: 46.5);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 20)),
        lat: 46.5 + 4 * 0.001 + 2 * _degPerKm,
      );
      // Selection order must not matter.
      final check = FlightMergeValidator.check([b, a]);
      expect(check.issues, isEmpty);
      expect(check.canMerge, isTrue);
      expect(check.ordered, [a, b]);
    });

    test('requires at least two flights', () {
      final check = FlightMergeValidator.check([_track(base)]);
      expect(check.issues.single.kind, FlightMergeIssueKind.tooFewFlights);
    });

    test('rejects a gap longer than 30 minutes and reports it', () {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 31)),
        lat: 46.5 + 4 * 0.001,
      );
      final issue = FlightMergeValidator.check([a, b]).issues.single;
      expect(issue.kind, FlightMergeIssueKind.gapTooLong);
      expect(issue.duration, const Duration(minutes: 31));
      expect(issue.track, a);
      expect(issue.next, b);
    });

    test('accepts a gap of exactly 30 minutes', () {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(FlightMergeValidator.maxGap),
        lat: 46.5 + 4 * 0.001,
      );
      expect(FlightMergeValidator.check([a, b]).canMerge, isTrue);
    });

    test('rejects overlapping flights', () {
      final a = _track(base);
      final b = _track(base.add(const Duration(seconds: 30)));
      final issue = FlightMergeValidator.check([a, b]).issues.single;
      expect(issue.kind, FlightMergeIssueKind.overlap);
      expect(issue.duration, const Duration(seconds: 30));
    });

    test('rejects a landing more than 3 km from the next takeoff', () {
      final a = _track(base, lat: 46.5);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 5)),
        lat: 46.5 + 4 * 0.001 + 3.5 * _degPerKm,
      );
      final issue = FlightMergeValidator.check([a, b]).issues.single;
      expect(issue.kind, FlightMergeIssueKind.tooFar);
      expect(issue.distanceM, closeTo(3500, 5));
    });

    test('uses valid fixes for the distance check', () {
      final a = _track(base, lat: 46.5)
        ..add(
          FlightSample(
            time: base.add(const Duration(minutes: 2)),
            data: const FlightData(latitude: 0, longitude: 0),
          ),
        );
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 5)),
        lat: 46.5 + 4 * 0.001,
      );
      expect(FlightMergeValidator.check([a, b]).canMerge, isTrue);
    });

    test('rejects different wings and pilots, ignores missing values', () {
      final a = _track(base)
        ..gliderName = 'Ozone Rush 6'
        ..pilotName = 'Alice';
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 5)),
        lat: 46.5 + 4 * 0.001,
      )
        ..gliderName = 'Advance Iota 2'
        ..pilotName = 'Bob';
      final kinds = FlightMergeValidator.check([
        a,
        b,
      ]).issues.map((i) => i.kind);
      expect(
        kinds,
        unorderedEquals([
          FlightMergeIssueKind.aircraftMismatch,
          FlightMergeIssueKind.pilotMismatch,
        ]),
      );

      b
        ..gliderName = ' ozone  rush 6 '
        ..pilotName = null;
      expect(FlightMergeValidator.check([a, b]).canMerge, isTrue);
    });

    test('reports summary-only and recording flights', () {
      final a = _track(base);
      final summaryOnly = _track(
        a.lastRecordedTime.add(const Duration(minutes: 5)),
      )..clearSamples();
      final recording = _track(base.add(const Duration(hours: 1)));
      final check = FlightMergeValidator.check([
        a,
        summaryOnly,
        recording,
      ], recording: recording);
      expect(
        check.issues.map((i) => i.kind),
        unorderedEquals([
          FlightMergeIssueKind.noSamples,
          FlightMergeIssueKind.recording,
        ]),
      );
    });

    test('checks every consecutive pair and reports all failures', () {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 10)),
        lat: 46.5 + 4 * 0.001,
      );
      final c = _track(
        b.lastRecordedTime.add(const Duration(minutes: 45)),
        lat: 46.6,
      );
      final issues = FlightMergeValidator.check([a, b, c]).issues;
      expect(
        issues.map((i) => i.kind),
        unorderedEquals([
          FlightMergeIssueKind.gapTooLong,
          FlightMergeIssueKind.tooFar,
        ]),
      );
      expect(issues.every((i) => i.track == b && i.next == c), isTrue);
    });
  });

  group('FlightTrack.merge', () {
    test('records the gap and keeps statistics out of it', () {
      final a = _track(base, lat: 46.5, alt: 1000)
        ..takeoffSite = 'Launch A'
        ..landingSite = 'Landing A'
        ..startedAutomatically = true
        ..gliderName = 'Rush 6';
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 20)),
        lat: 46.5 + 4 * 0.001 + 2 * _degPerKm,
        alt: 600,
      )
        ..takeoffSite = 'Launch B'
        ..landingSite = 'Landing B'
        ..endedAutomatically = true
        ..harnessName = 'Lightness 3';

      final merged = FlightTrack.merge([a, b]);
      expect(merged.samples, hasLength(10));
      expect(merged.startTime, a.firstRecordedTime);
      expect(merged.endTime, b.lastRecordedTime);
      expect(merged.dataGaps, [
        FlightDataGap(start: a.lastRecordedTime, end: b.firstRecordedTime),
      ]);
      // The 2 km ground transfer is not part of the flown distance.
      expect(merged.distanceM, closeTo(a.distanceM + b.distanceM, 1e-6));
      expect(merged.takeoffSite, 'Launch A');
      expect(merged.landingSite, 'Landing B');
      expect(merged.startedAutomatically, isTrue);
      expect(merged.endedAutomatically, isTrue);
      expect(merged.gliderName, 'Rush 6');
      expect(merged.harnessName, 'Lightness 3');
      expect(merged.maxAltitude, a.maxAltitude);
      expect(merged.minAltitude, b.minAltitude);

      final derived = FlightDerivedStats.compute(merged);
      expect(
        derived.trackDistanceM,
        closeTo(a.distanceM + b.distanceM, 1e-6),
      );

      final restored = FlightTrack.fromJson(merged.toJson())!;
      expect(restored.dataGaps, merged.dataGaps);
      expect(restored.distanceM, closeTo(merged.distanceM, 1e-9));
      final summary = FlightTrack.fromSummaryJson(merged.toSummaryJson())!;
      expect(summary.dataGaps, merged.dataGaps);
    });

    test('trimming drops gaps outside the kept range', () {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 10)),
        lat: 46.5 + 4 * 0.001,
      );
      final merged = FlightTrack.merge([a, b]);
      expect(merged.trimSamples(startIndex: 5, endIndex: 9), isTrue);
      expect(merged.hasDataGaps, isFalse);
    });

    test('maps gaps onto replay samples', () {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 10)),
        lat: 46.5 + 4 * 0.001,
      );
      final merged = FlightTrack.merge([a, b]);
      final gaps = replayGapsFor(merged, merged.samples);
      expect(gaps, hasLength(1));
      expect(gaps.single.afterIndex, 5);
      expect(gaps.single.startMs, 60000);
      expect(gaps.single.endMs, 60000 + 600000);
      expect(replayGapAt(gaps, 300000), gaps.single);
      expect(replayGapAt(gaps, 30000), isNull);
      // The gap is crossed quickly instead of in real time.
      expect(replaySpeedAt(gaps, 300000, 1), greaterThan(100));
      expect(replaySpeedAt(gaps, 30000, 2), 2);
    });
  });

  group('FlightRecorder.mergeTracks', () {
    test('replaces the originals with one record', () async {
      final a = _track(base);
      final b = _track(
        a.lastRecordedTime.add(const Duration(minutes: 10)),
        lat: 46.5 + 4 * 0.001,
      );
      final other = _track(base.add(const Duration(days: 1)));
      final recorder = FlightRecorder.instance..importTracks([a, b, other]);

      final result = recorder.mergeTracks([a, b]);
      expect(result.succeeded, isTrue);
      expect(recorder.tracks, hasLength(2));
      expect(recorder.tracks, contains(result.merged));
      expect(recorder.tracks, isNot(contains(a)));
      expect(recorder.tracks, isNot(contains(b)));
      await FlightStore.instance.flush(recorder.tracks);

      final loaded = await FlightStore.instance.load();
      final restored = loaded.firstWhere((t) => t.hasDataGaps);
      expect(restored.samples, hasLength(10));
    });

    test('leaves the log untouched when validation fails', () {
      final a = _track(base);
      final b = _track(a.lastRecordedTime.add(const Duration(hours: 2)));
      final recorder = FlightRecorder.instance..importTracks([a, b]);

      final result = recorder.mergeTracks([a, b]);
      expect(result.succeeded, isFalse);
      expect(result.check.issues, isNotEmpty);
      expect(recorder.tracks, unorderedEquals([a, b]));
    });
  });

  group('replay UI', () {
    testWidgets('2D replay marks and announces the missing-data period', (
      tester,
    ) async {
      final merged = _mergedTrack(base);
      await tester.pumpWidget(
        _testApp((context) => showFlightReplaySheet(context, merged)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('1 missing-data period · 10m 00s'), findsOneWidget);
      expect(find.byKey(const ValueKey('replay-gap-banner')), findsNothing);

      await _seekToFraction(tester, 0.5);
      expect(find.byKey(const ValueKey('replay-gap-banner')), findsOneWidget);
      expect(find.textContaining('No data'), findsOneWidget);

      await _seekToFraction(tester, 0.02);
      expect(find.byKey(const ValueKey('replay-gap-banner')), findsNothing);
    });

    testWidgets('3D replay marks the missing-data period', (tester) async {
      final merged = _mergedTrack(base);
      await tester.pumpWidget(
        _testApp((context) => showTrack3DSheet(context, merged)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('1 missing-data period · 10m 00s'), findsOneWidget);
      await _seekToFraction(tester, 0.5);
      expect(find.byKey(const ValueKey('replay-gap-banner')), findsOneWidget);
      // Readouts show "No data" for altitude, speed and vario.
      expect(find.text('No data'), findsNWidgets(3));
    });
  });
}

Future<void> _seekToFraction(WidgetTester tester, double fraction) async {
  final slider = tester.widget<Slider>(find.byType(Slider));
  slider.onChanged!(slider.max * fraction);
  await tester.pump();
}

FlightTrack _mergedTrack(DateTime base) {
  final a = _track(base);
  final b = _track(
    a.lastRecordedTime.add(const Duration(minutes: 10)),
    lat: 46.5 + 4 * 0.001,
  );
  return FlightTrack.merge([a, b]);
}

Widget _testApp(void Function(BuildContext context) open) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// Five fixes, 15 s apart, moving 0.001° north per step from [lat].
FlightTrack _track(DateTime start, {double lat = 46.5, double alt = 800}) {
  final track = FlightTrack(startTime: start);
  for (var i = 0; i < 5; i++) {
    final t = start.add(Duration(seconds: i * 15));
    track.add(
      FlightSample(
        time: t,
        data: FlightData(
          altitude: alt - i * 10,
          gpsAltitude: alt - i * 10,
          latitude: lat + i * 0.001,
          longitude: 6.6,
          hasFix: true,
        ),
      ),
    );
  }
  track.endTime = track.samples.last.time;
  return track;
}
