import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_report_service.dart';
import 'package:parabeacon/data/flight_share_card_service.dart';
import 'package:parabeacon/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flight detail exports', () {
    test('builds a PDF report with a full grouped flight record', () async {
      final bytes = await FlightReportService.instance.buildPdf(
        _completeTrack(),
        AppLocalizationsEn(),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
    });

    test('renders a compact grouped share card', () async {
      final bytes = await FlightShareCardService.instance.renderPng(
        _completeTrack(),
        AppLocalizationsEn(),
      );
      final data = ByteData.sublistView(Uint8List.fromList(bytes));

      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(data.getUint32(16), 1080);
      expect(data.getUint32(20), lessThan(3000));
    });

    test('trims unused space from sparse flight cards', () async {
      final bytes = await FlightShareCardService.instance.renderPng(
        FlightTrack(startTime: DateTime.utc(2026, 10, 1, 9)),
        AppLocalizationsEn(),
      );
      final data = ByteData.sublistView(Uint8List.fromList(bytes));

      expect(data.getUint32(16), 1080);
      expect(data.getUint32(20), greaterThan(800));
      expect(data.getUint32(20), lessThan(1200));
    });
  });
}

FlightTrack _completeTrack() {
  final start = DateTime.utc(2026, 10, 1, 9);
  final track = FlightTrack(startTime: start)
    ..endTime = start.add(const Duration(minutes: 2))
    ..pilotName = 'Test Pilot'
    ..takeoffSite = 'Launch Site'
    ..landingSite = 'Landing Site'
    ..gliderName = 'Test Glider'
    ..harnessName = 'Test Harness'
    ..helmetName = 'Test Helmet'
    ..aircraftName = 'Test Aircraft'
    ..aircraftManufacturer = 'Test Manufacturer'
    ..aircraftModel = 'Model A'
    ..aircraftFaiClass = 'CCC'
    ..aircraftCategory = 'Paraglider'
    ..aircraftTandem = false
    ..aircraftEngineType = 'Electric'
    ..aircraftTrimSpeedKmh = 38.5
    ..aircraftGoalGlideRatio = 9.25;

  for (var i = 0; i < 7; i++) {
    final altitude = 400 + i * 8.0;
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: i * 20)),
        data: FlightData(
          altitude: altitude,
          gpsAltitude: altitude,
          baroAltitude: altitude - 3,
          verticalSpeed: 0.4,
          groundSpeed: 27 + i.toDouble(),
          latitude: 22.8 + i * 0.002,
          longitude: 114.7 + i * 0.003,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}
