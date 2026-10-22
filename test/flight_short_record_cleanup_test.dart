import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:parabeacon/data/recording_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('short completed flight cleanup defaults to two minutes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = RecordingSettings.instance;
    await settings.load();
    expect(settings.autoDeleteShortFlights, isTrue);
    expect(
      settings.shortFlightThresholdSeconds,
      const Duration(minutes: 2).inSeconds,
    );

    final recorder = FlightRecorder.instance;
    final flightState = FlightState.instance;
    recorder.clearTracks();
    if (flightState.isFlying) flightState.stop();
    recorder.bind(_EmptyFlightDataView(), flightState: flightState);

    flightState.start();
    flightState.stop();
    expect(recorder.tracks, isEmpty);

    settings.setAutoDeleteShortFlights(false);
    flightState.start();
    flightState.stop();
    expect(recorder.tracks, hasLength(1));
    final retainedTrack = recorder.tracks.single;

    settings.setShortFlightThresholdSeconds(30);
    settings.setAutoDeleteShortFlights(true);
    flightState.start();
    flightState.stop();

    expect(recorder.tracks, [retainedTrack]);
    expect(recorder.lastCompletedTrack, retainedTrack);
    expect(settings.shortFlightThresholdSeconds, 30);
    settings.setShortFlightThresholdSeconds(
      RecordingSettings.defaultShortFlightThresholdSeconds,
    );
  });

  test('existing short records can be counted and deleted in one batch', () {
    final recorder = FlightRecorder.instance;
    recorder.clearTracks();
    final start = DateTime.utc(2026, 10, 1, 9);
    FlightTrack track(Duration length, int hourOffset) {
      final begin = start.add(Duration(hours: hourOffset));
      return FlightTrack(startTime: begin)..endTime = begin.add(length);
    }

    final short = track(const Duration(seconds: 20), 0);
    final atThreshold = track(const Duration(minutes: 1), 1);
    final long = track(const Duration(minutes: 30), 2);
    recorder.importTracks([short, atThreshold, long]);

    final matches = recorder.tracksShorterThan(const Duration(minutes: 1));
    expect(matches, [short]);
    expect(recorder.deleteTracks(matches), 1);
    expect(recorder.tracks, [long, atThreshold]);
    recorder.clearTracks();
  });
}

class _EmptyFlightDataView extends ChangeNotifier implements FlightDataView {
  @override
  FlightData get data => FlightData.empty;
}
