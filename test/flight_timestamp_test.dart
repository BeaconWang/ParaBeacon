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
    final start = DateTime.utc(2026, 10, 21, 9, 30, 12);
    final end = start.add(const Duration(minutes: 1));

    test('writes flight bounds and samples as Unix epoch seconds', () {
      final track = FlightTrack(startTime: start)
        ..endTime = end
        ..add(
          FlightSample(
            time: start,
            data: FlightData(timestamp: start, gpsTimestamp: end),
          ),
        );

      final json = track.toJson();
      final sample = (json['samples'] as List).single as Map<String, dynamic>;
      final data = sample['d'] as Map<String, dynamic>;

      expect(json['startTime'], start.millisecondsSinceEpoch ~/ 1000);
      expect(json['endTime'], end.millisecondsSinceEpoch ~/ 1000);
      expect(sample['t'], start.millisecondsSinceEpoch ~/ 1000);
      expect(data['ts'], start.millisecondsSinceEpoch ~/ 1000);
      expect(data['gpsTs'], end.millisecondsSinceEpoch ~/ 1000);
      expect(json['startTime'], isA<int>());

      final restored = FlightTrack.fromJson(json)!;
      expect(restored.startTime, start);
      expect(restored.endTime, start);
      expect(restored.samples.single.time.isUtc, isTrue);
      expect(restored.samples.single.data.timestamp, start);
      expect(restored.samples.single.data.gpsTimestamp, end);
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

    test('reads zone-less legacy values in local time and numeric seconds', () {
      final localTime = DateTime(2026, 10, 21, 9, 30, 12);

      expect(
        parseFlightTimestamp(localTime.toIso8601String()),
        localTime.toUtc(),
      );
      expect(parseFlightTimestamp(start.millisecondsSinceEpoch ~/ 1000), start);
    });

    test(
      'serializes data timestamps as seconds in compact and full records',
      () {
        final data = FlightData(timestamp: start, gpsTimestamp: end);

        for (final compact in [false, true]) {
          final json = data.toJson(compact: compact);
          expect(json['ts'], start.millisecondsSinceEpoch ~/ 1000);
          expect(json['gpsTs'], end.millisecondsSinceEpoch ~/ 1000);
          expect(FlightData.fromJson(json).gpsTimestamp, end);
        }

        final legacy = FlightData.fromJson({
          'ts': start.toIso8601String(),
          'gpsTs': end.toIso8601String(),
        });
        expect(legacy.timestamp, start);
        expect(legacy.gpsTimestamp, end);
      },
    );

    test('migrates legacy stored records to Unix seconds', () async {
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
      final sample = (legacy['samples'] as List).single as Map<String, dynamic>;
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
      expect(saved['version'], 3);
      expect(savedTrack['startTime'], start.millisecondsSinceEpoch ~/ 1000);
      expect(savedSample['t'], start.millisecondsSinceEpoch ~/ 1000);
      expect(savedData['ts'], start.millisecondsSinceEpoch ~/ 1000);
      expect(savedData['gpsTs'], end.millisecondsSinceEpoch ~/ 1000);
    });
  });
}
