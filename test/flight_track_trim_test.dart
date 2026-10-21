import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_export_service.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  group('FlightTrack trimming', () {
    final start = DateTime.utc(2026, 9, 19, 12);

    test('trims both ends and rebuilds persisted summary and endpoints', () {
      final track = _track(start);
      track
        ..takeoffSite = 'Old launch'
        ..landingSite = 'Old landing';

      expect(track.trimSamples(startIndex: 1, endIndex: 3), isTrue);

      expect(track.samples, hasLength(3));
      expect(track.pointCount, 3);
      expect(track.firstRecordedTime, start.add(const Duration(seconds: 10)));
      expect(track.lastRecordedTime, start.add(const Duration(seconds: 30)));
      expect(track.endTime, start.add(const Duration(seconds: 30)));
      expect(track.duration, const Duration(seconds: 20));
      expect(track.maxAltitude, 160);
      expect(track.minAltitude, 120);
      expect(track.maxAltGainM, 40);
      expect(track.elevationDropM, -10);
      expect(track.takeoffLongitude, closeTo(0.001, 1e-9));
      expect(track.landingLongitude, closeTo(0.003, 1e-9));
      expect(track.distanceM, closeTo(157.25, 1));
      expect(track.takeoffSite, isNull);
      expect(track.landingSite, isNull);

      final restored = FlightTrack.fromJson(track.toJson())!;
      expect(restored.samples, hasLength(3));
      expect(restored.pointCount, 3);
      expect(restored.distanceM, closeTo(track.distanceM, 1e-9));
      expect(restored.takeoffLongitude, closeTo(0.001, 1e-9));
      expect(restored.landingLongitude, closeTo(0.003, 1e-9));
    });

    test('trims only the beginning or end when requested', () {
      final beginningTrimmed = _track(start)
        ..takeoffSite = 'Old launch'
        ..landingSite = 'Landing';
      final originalEndTime = start.add(const Duration(seconds: 55));
      beginningTrimmed.endTime = originalEndTime;
      expect(beginningTrimmed.trimSamples(startIndex: 2, endIndex: 4), isTrue);
      expect(beginningTrimmed.takeoffSite, isNull);
      expect(beginningTrimmed.landingSite, 'Landing');
      expect(
        beginningTrimmed.startTime,
        start.add(const Duration(seconds: 20)),
      );
      expect(beginningTrimmed.endTime, start.add(const Duration(seconds: 40)));
      expect(beginningTrimmed.endTime, isNot(originalEndTime));
      expect(
        beginningTrimmed.firstRecordedTime,
        start.add(const Duration(seconds: 20)),
      );
      expect(
        beginningTrimmed.lastRecordedTime,
        start.add(const Duration(seconds: 40)),
      );
      expect(beginningTrimmed.samples, hasLength(3));

      final endTrimmed = _track(start)
        ..takeoffSite = 'Launch'
        ..landingSite = 'Old landing';
      expect(endTrimmed.trimSamples(startIndex: 0, endIndex: 2), isTrue);
      expect(endTrimmed.takeoffSite, 'Launch');
      expect(endTrimmed.landingSite, isNull);
      expect(endTrimmed.endTime, start.add(const Duration(seconds: 20)));
      expect(endTrimmed.firstRecordedTime, start);
      expect(
        endTrimmed.lastRecordedTime,
        start.add(const Duration(seconds: 20)),
      );
      expect(endTrimmed.samples, hasLength(3));
    });

    test(
      'restores bounds from recorded points instead of stale session times',
      () {
        final track = _track(start)
          ..startTime = start.subtract(const Duration(minutes: 5))
          ..endTime = start.add(const Duration(minutes: 5));

        final restored = FlightTrack.fromJson(track.toJson())!;

        expect(restored.startTime, restored.samples.first.time);
        expect(restored.endTime, restored.samples.last.time);
        expect(restored.startTime.isUtc, isTrue);
        expect(restored.endTime!.isUtc, isTrue);
      },
    );

    test('exports dates from the first retained sample', () {
      final track = _track(DateTime.utc(2026, 9, 19, 23, 59, 50, 123));
      expect(track.trimSamples(startIndex: 1, endIndex: 3), isTrue);

      final gpx = FlightExportService.instance.buildGpx(track);
      final igc = FlightExportService.instance.buildIgc(track);

      expect(gpx, contains('<time>2026-09-20T00:00:00.123Z</time>'));
      expect(igc, startsWith('AXXXParaBeacon\nHFDTE200926\n'));
    });

    test('rejects trims that would leave fewer than two samples', () {
      final track = _track(start);
      expect(track.trimSamples(startIndex: 2, endIndex: 2), isFalse);
      expect(track.trimSamples(startIndex: -1, endIndex: 2), isFalse);
      expect(track.trimSamples(startIndex: 0, endIndex: 5), isFalse);
      expect(track.samples, hasLength(5));
      expect(track.pointCount, 5);
    });
  });
}

FlightTrack _track(DateTime start) {
  const altitudes = [100.0, 120.0, 160.0, 130.0, 90.0];
  final track = FlightTrack(startTime: start)
    ..endTime = start.add(const Duration(seconds: 40));
  for (var i = 0; i < altitudes.length; i++) {
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: i * 10)),
        data: FlightData(
          altitude: altitudes[i],
          gpsAltitude: altitudes[i],
          baroAltitude: altitudes[i],
          latitude: 45,
          longitude: i * 0.001,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}
