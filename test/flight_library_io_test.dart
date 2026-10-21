import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_library_io.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  test('flight library exports use the compound ZIP extension', () {
    expect(FlightLibraryIO.extension, 'pbflights.zip');
  });

  test('flight bundle records preserve millisecond timestamps', () {
    final start = DateTime.utc(2026, 10, 21, 9, 30, 12, 345);
    final sampleTime = start.add(const Duration(milliseconds: 123));
    final track = FlightTrack(startTime: start)..endTime = sampleTime;
    track.add(
      FlightSample(
        time: start,
        data: FlightData(
          timestamp: start.add(const Duration(milliseconds: 1)),
          gpsTimestamp: start.add(const Duration(milliseconds: 2)),
        ),
      ),
    );
    track.add(
      FlightSample(
        time: sampleTime,
        data: FlightData(
          timestamp: sampleTime.add(const Duration(milliseconds: 1)),
          gpsTimestamp: sampleTime.add(const Duration(milliseconds: 2)),
        ),
      ),
    );

    final archive = ZipDecoder().decodeBytes(
      FlightLibraryIO.instance.buildBundle([track]),
    );
    final manifest =
        jsonDecode(
              utf8.decode(
                archive.findFile('manifest.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    final flightJson =
        jsonDecode(
              utf8.decode(
                archive.findFile('flights/${flightId(track)}.json')!.content
                    as List<int>,
              ),
            )
            as Map<String, dynamic>;
    final samples = flightJson['samples'] as List;
    final firstSample = samples.first as Map<String, dynamic>;
    final firstData = firstSample['d'] as Map<String, dynamic>;
    final lastSample = samples.last as Map<String, dynamic>;
    final lastData = lastSample['d'] as Map<String, dynamic>;

    expect(manifest['version'], 3);
    expect(manifest['exportedAt'], greaterThan(100000000000));
    expect(flightJson['startTime'], start.millisecondsSinceEpoch);
    expect(flightJson['endTime'], sampleTime.millisecondsSinceEpoch);
    expect(firstSample['t'], start.millisecondsSinceEpoch);
    expect(firstData['ts'], start.millisecondsSinceEpoch + 1);
    expect(firstData['gpsTs'], start.millisecondsSinceEpoch + 2);
    expect(lastSample['t'], sampleTime.millisecondsSinceEpoch);
    expect(lastData['ts'], sampleTime.millisecondsSinceEpoch + 1);
    expect(lastData['gpsTs'], sampleTime.millisecondsSinceEpoch + 2);

    final restored = FlightTrack.fromJson(flightJson)!;
    expect(restored.startTime, start);
    expect(restored.endTime, sampleTime);
    expect(
      restored.samples.last.data.gpsTimestamp,
      sampleTime.add(const Duration(milliseconds: 2)),
    );
  });
}
