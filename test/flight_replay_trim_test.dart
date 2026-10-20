import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parabeacon/controls/flight_replay_sheet.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_store.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlightRecorder.instance.clearTracks();
  });

  testWidgets('replay progress bar can select and apply a trim range', (
    tester,
  ) async {
    final track = _track();
    FlightRecorder.instance.importTracks([track]);
    await FlightStore.instance.flush(FlightRecorder.instance.tracks);
    await tester.pumpWidget(_testApp(track));
    await tester.tap(find.text('Open replay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Trim flight log'));
    await tester.pump();
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Keep 5 samples · remove 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Restore data monitor'));
    await tester.pump();

    final sliderRect = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(
      Offset(sliderRect.left + 12, sliderRect.center.dy),
      Offset(sliderRect.width * 0.22, 0),
    );
    await tester.pump();
    expect(find.text('Keep 4 samples · remove 1'), findsOneWidget);
    final cursorTime = DateTime.utc(2026, 10, 1, 9, 0, 15).toLocal();
    final expectedCursorTime =
        '${cursorTime.hour.toString().padLeft(2, '0')}:'
        '${cursorTime.minute.toString().padLeft(2, '0')}:'
        '${cursorTime.second.toString().padLeft(2, '0')}';
    expect(find.text(expectedCursorTime), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Trim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(track.samples, hasLength(4));
    expect(track.firstRecordedTime, DateTime.utc(2026, 10, 1, 9, 0, 15));
    expect(track.lastRecordedTime, DateTime.utc(2026, 10, 1, 9, 1));
    expect(find.byType(RangeSlider), findsNothing);
    await FlightStore.instance.flush(FlightRecorder.instance.tracks);
  });
}

Widget _testApp(FlightTrack track) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showFlightReplaySheet(context, track),
            child: const Text('Open replay'),
          ),
        ),
      ),
    ),
  );
}

FlightTrack _track() {
  final start = DateTime.utc(2026, 10, 1, 9);
  final track = FlightTrack(startTime: start)
    ..endTime = start.add(const Duration(minutes: 1));
  for (var i = 0; i < 5; i++) {
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: i * 15)),
        data: FlightData(
          altitude: 500 + i * 10,
          gpsAltitude: 500 + i * 10,
          latitude: 46.5 + i * 0.001,
          longitude: 6.6 + i * 0.001,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}
