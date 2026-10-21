import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_store.dart';
import 'package:parabeacon/data/flight_timestamp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('flight timestamp serialization', () {
    final start = DateTime.utc(2026, 10, 21, 9, 30, 12, 345);
    final end = start.add(const Duration(minutes: 1, milliseconds: 678));

    test('writes flight bounds and samples as Unix epoch milliseconds', () {
      final track = FlightTrack(startTime: start)..endTime = end;
      track.add(
        FlightSample(
          time: start,
          data: FlightData(
            timestamp: start.add(const Duration(milliseconds: 12)),
            gpsTimestamp: start.add(const Duration(milliseconds: 34)),
          ),
        ),
      );
      track.add(
        FlightSample(
          time: end,
          data: FlightData(
            timestamp: end.add(const Duration(milliseconds: 56)),
            gpsTimestamp: end.add(const Duration(milliseconds: 78)),
          ),
        ),
      );

      final json = track.toJson();
      final samples = json['samples'] as List;
      final firstSample = samples.first as Map<String, dynamic>;
      final firstData = firstSample['d'] as Map<String, dynamic>;
      final lastSample = samples.last as Map<String, dynamic>;

      expect(json['startTime'], start.millisecondsSinceEpoch);
      expect(json['endTime'], end.millisecondsSinceEpoch);
      expect(firstSample['t'], start.millisecondsSinceEpoch);
      expect(firstData['ts'], start.millisecondsSinceEpoch + 12);
      expect(firstData['gpsTs'], start.millisecondsSinceEpoch + 34);
      expect(lastSample['t'], end.millisecondsSinceEpoch);
      expect(json['startTime'], isA<int>());

      final restored = FlightTrack.fromJson(json)!;
      expect(restored.startTime, start);
      expect(restored.endTime, end);
      expect(
        restored.samples.first.data.timestamp,
        start.add(const Duration(milliseconds: 12)),
      );
      expect(
        restored.samples.first.data.gpsTimestamp,
        start.add(const Duration(milliseconds: 34)),
      );
      expect(restored.samples.last.time, end);
    });

    test('continues to read legacy ISO timestamps as instants', () {
      final track = FlightTrack(startTime: start)
        ..endTime = end
        ..add(FlightSample(time: start, data: FlightData.empty));
      final legacy = track.toJson();
      final sample = (legacy['samples'] as List).single as Map<String, dynamic>;
      sample['t'] = start.toIso8601String();
      legacy['startTime'] = start.toIso8601String();
      legacy['endTime'] = end.toIso8601String();

      final restored = FlightTrack.fromJson(legacy)!;

      expect(restored.startTime, start);
      expect(restored.endTime, start);
      expect(restored.startTime.isUtc, isTrue);
      expect(restored.samples.single.time.isUtc, isTrue);
    });

    test('reads legacy seconds and current milliseconds', () {
      final localTime = DateTime(2026, 10, 21, 9, 30, 12, 345);
      final legacySeconds = start.millisecondsSinceEpoch ~/ 1000;
      final legacyInstant = DateTime.fromMillisecondsSinceEpoch(
        legacySeconds * 1000,
        isUtc: true,
      );

      expect(
        parseFlightTimestamp(localTime.toIso8601String()),
        localTime.toUtc(),
      );
      expect(parseFlightTimestamp(legacySeconds), legacyInstant);
      expect(parseFlightTimestamp(start.millisecondsSinceEpoch), start);
    });

    test(
      'serializes data timestamps as milliseconds in compact and full records',
      () {
        final data = FlightData(
          timestamp: start.add(const Duration(milliseconds: 123)),
          gpsTimestamp: end.add(const Duration(milliseconds: 456)),
        );

        for (final compact in [false, true]) {
          final json = data.toJson(compact: compact);
          expect(json['ts'], start.millisecondsSinceEpoch + 123);
          expect(json['gpsTs'], end.millisecondsSinceEpoch + 456);
          expect(
            FlightData.fromJson(json).gpsTimestamp,
            end.add(const Duration(milliseconds: 456)),
          );
        }

        final legacy = FlightData.fromJson({
          'ts': start.toIso8601String(),
          'gpsTs': end.toIso8601String(),
        });
        expect(legacy.timestamp, start);
        expect(legacy.gpsTimestamp, end);
      },
    );

    test(
      'flushes millisecond timestamps to and from the flight database',
      () async {
        final track = FlightTrack(startTime: start);
        track.add(
          FlightSample(
            time: start,
            data: FlightData(
              timestamp: start.add(const Duration(milliseconds: 12)),
              gpsTimestamp: start.add(const Duration(milliseconds: 34)),
            ),
          ),
        );
        track.add(
          FlightSample(
            time: end,
            data: FlightData(timestamp: end, gpsTimestamp: end),
          ),
        );
        await FlightStore.instance.flush([track]);

        final preferences = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(preferences.getString('pb.tracks.v1')!)
                as Map<String, dynamic>;
        final savedTrack =
            (saved['tracks'] as List).single as Map<String, dynamic>;
        final firstSample =
            (savedTrack['samples'] as List).first as Map<String, dynamic>;
        final savedData = firstSample['d'] as Map<String, dynamic>;
        final loaded = await FlightStore.instance.load();

        expect(saved['version'], 4);
        expect(savedTrack['startTime'], start.millisecondsSinceEpoch);
        expect(firstSample['t'], start.millisecondsSinceEpoch);
        expect(savedData['ts'], start.millisecondsSinceEpoch + 12);
        expect(savedData['gpsTs'], start.millisecondsSinceEpoch + 34);
        expect(loaded.single.startTime, start);
        expect(loaded.single.endTime, end);
        expect(
          loaded.single.samples.first.data.gpsTimestamp,
          start.add(const Duration(milliseconds: 34)),
        );
      },
    );

    test(
      'migrates legacy ISO timestamp records to Unix milliseconds',
      () async {
        final track = FlightTrack(startTime: start)
          ..endTime = end
          ..add(
            FlightSample(
              time: start,
              data: FlightData(timestamp: start, gpsTimestamp: end),
            ),
          );
        final legacy = track.toJson();
        legacy['startTime'] = start.toIso8601String();
        legacy['endTime'] = end.toIso8601String();
        final sample =
            (legacy['samples'] as List).single as Map<String, dynamic>;
        sample['t'] = start.toIso8601String();
        final data = sample['d'] as Map<String, dynamic>;
        data['ts'] = start.toIso8601String();
        data['gpsTs'] = end.toIso8601String();
        SharedPreferences.setMockInitialValues({
          'pb.tracks.v1': jsonEncode({
            'version': 2,
            'tracks': [legacy],
          }),
        });

        final loaded = await FlightStore.instance.load();
        final preferences = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(preferences.getString('pb.tracks.v1')!)
                as Map<String, dynamic>;
        final savedTrack =
            (saved['tracks'] as List).single as Map<String, dynamic>;
        final savedSample =
            (savedTrack['samples'] as List).single as Map<String, dynamic>;
        final savedData = savedSample['d'] as Map<String, dynamic>;

        expect(loaded, hasLength(1));
        expect(saved['version'], 4);
        expect(savedTrack['startTime'], start.millisecondsSinceEpoch);
        expect(savedSample['t'], start.millisecondsSinceEpoch);
        expect(savedData['ts'], start.millisecondsSinceEpoch);
        expect(savedData['gpsTs'], end.millisecondsSinceEpoch);
      },
    );

    test(
      'migrates legacy numeric seconds to millisecond database values',
      () async {
        final startSeconds = start.millisecondsSinceEpoch ~/ 1000;
        final endSeconds = end.millisecondsSinceEpoch ~/ 1000;
        final legacyTrack = <String, dynamic>{
          'startTime': startSeconds,
          'endTime': endSeconds,
          'pointCount': 1,
          'samples': [
            {
              't': startSeconds,
              'd': {'ts': startSeconds, 'gpsTs': endSeconds},
            },
          ],
        };
        SharedPreferences.setMockInitialValues({
          'pb.tracks.v1': jsonEncode({
            'version': 3,
            'tracks': [legacyTrack],
          }),
        });

        final loaded = await FlightStore.instance.load();
        final preferences = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(preferences.getString('pb.tracks.v1')!)
                as Map<String, dynamic>;
        final savedTrack =
            (saved['tracks'] as List).single as Map<String, dynamic>;
        final savedSample =
            (savedTrack['samples'] as List).single as Map<String, dynamic>;
        final savedData = savedSample['d'] as Map<String, dynamic>;

        expect(loaded, hasLength(1));
        expect(
          loaded.single.startTime.millisecondsSinceEpoch,
          startSeconds * 1000,
        );
        expect(saved['version'], 4);
        expect(savedTrack['startTime'], startSeconds * 1000);
        expect(savedSample['t'], startSeconds * 1000);
        expect(savedData['ts'], startSeconds * 1000);
        expect(savedData['gpsTs'], endSeconds * 1000);
      },
    );
  });
}
