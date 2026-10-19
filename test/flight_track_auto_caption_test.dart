import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  group('FlightTrack automatic caption', () {
    final start = DateTime.utc(2026, 6, 1, 10);
    final end = start.add(const Duration(minutes: 20));

    test('requires automatic take-off and automatic landing', () {
      final track = FlightTrack(startTime: start)
        ..startedAutomatically = true
        ..endedAutomatically = true;
      expect(track.isAutoFlight, isTrue);

      final manualTakeoff = FlightTrack(startTime: start)
        ..startedAutomatically = false
        ..endedAutomatically = true;
      final manualLanding = FlightTrack(startTime: start)
        ..startedAutomatically = true
        ..endedAutomatically = false;
      expect(manualTakeoff.isAutoFlight, isFalse);
      expect(manualLanding.isAutoFlight, isFalse);
    });

    test(
      'persists both automatic transition flags in full and summary records',
      () {
        final track = FlightTrack(startTime: start)
          ..endTime = end
          ..startedAutomatically = true
          ..endedAutomatically = true
          ..add(FlightSample(time: start, data: FlightData.empty));

        final fromFullRecord = FlightTrack.fromJson(track.toJson());
        final fromSummary = FlightTrack.fromSummaryJson(track.toSummaryJson());

        expect(fromFullRecord?.isAutoFlight, isTrue);
        expect(fromSummary?.isAutoFlight, isTrue);
      },
    );

    test('tracks and persists altitude gain and elevation drop', () {
      final track = FlightTrack(startTime: start)..endTime = end;
      const altitudes = [1000.0, 900.0, 1300.0, 1050.0];
      for (var i = 0; i < altitudes.length; i++) {
        track.add(
          FlightSample(
            time: start.add(Duration(seconds: i)),
            data: FlightData(altitude: altitudes[i]),
          ),
        );
      }

      expect(track.maxAltGainM, 400.0);
      expect(track.elevationDropM, -50.0);
      final stats = FlightDerivedStats.compute(track);
      expect(stats.maxAltGainM, 400.0);
      expect(stats.elevationDropM, -50.0);

      final fullRestore = FlightTrack.fromJson(track.toJson());
      expect(fullRestore?.maxAltGainM, 400.0);
      expect(fullRestore?.elevationDropM, -50.0);

      track.clearSamples();
      final summaryRestore = FlightTrack.fromJson(track.toJson());
      expect(summaryRestore?.hasSamples, isFalse);
      expect(summaryRestore?.maxAltGainM, 400.0);
      expect(summaryRestore?.elevationDropM, -50.0);
    });

    test('random markers stay unspecified in persisted records', () {
      final randomSample = FlightTrack(startTime: start)
        ..startedAutomatically = null
        ..endedAutomatically = null
        ..endTime = end;

      final restored = FlightTrack.fromSummaryJson(
        randomSample.toSummaryJson(),
      );

      expect(restored?.startedAutomatically, isNull);
      expect(restored?.endedAutomatically, isNull);
      expect(restored?.isAutoFlight, isFalse);
    });

    test('legacy records without automatic flags are not labeled AUTO', () {
      final legacy = FlightTrack.fromSummaryJson({
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
      });

      expect(legacy?.isAutoFlight, isFalse);
    });
  });
}
