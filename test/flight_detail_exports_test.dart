import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_details_settings.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_report_service.dart';
import 'package:parabeacon/data/flight_share_card_service.dart';
import 'package:parabeacon/data/flight_statistics.dart';
import 'package:parabeacon/data/flight_statistics_share_card_service.dart';
import 'package:parabeacon/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en'));

  group('Flight detail exports', () {
    test('builds a PDF report with a full grouped flight record', () async {
      final track = _completeTrack();
      final l10n = AppLocalizationsEn();
      final bytes = await FlightReportService.instance.buildPdf(track, l10n);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
      final text = _decodePdfStreams(bytes);
      for (final field in [
        l10n.flightDetailFlight,
        l10n.flightDetailStart,
        l10n.flightDetailEnd,
        l10n.flightDetailDuration,
        l10n.flightDetailSamples,
        l10n.flightDetailPilot,
        l10n.flightDetailRoute,
        l10n.flightDetailDistance,
        l10n.flightDetailTakeoff,
        l10n.flightDetailTakeoffAltitude,
        l10n.flightDetailLanding,
        l10n.flightDetailLandingAltitude,
        l10n.flightDetailAltitude,
        l10n.flightDetailMaxAltitude,
        l10n.flightDetailMinAltitude,
        l10n.flightDetailMaxClimb,
        l10n.flightDetailMaxSink,
        l10n.flightDetailAircraft,
        l10n.flightDetailAircraftName,
        l10n.flightDetailAircraftManufacturer,
        l10n.flightDetailAircraftModel,
        l10n.flightDetailAircraftClass,
        l10n.flightDetailAircraftTandem,
        l10n.flightDetailAircraftEngine,
        l10n.flightDetailAircraftTrimSpeed,
        l10n.flightDetailAircraftGlideRatio,
        l10n.flightDetailPerformance,
        l10n.flightDetailRouteMetrics,
        l10n.flightDetailStraightDistance,
        l10n.flightDetailMaxFromStart,
        l10n.flightDetailTrackEfficiency,
        l10n.flightDetailSpeedGlide,
        l10n.flightDetailAvgGroundSpeed,
        l10n.flightDetailAvgCruiseSpeed,
        l10n.flightDetailMaxSpeed,
        l10n.flightDetailAvgGlideRatio,
        l10n.flightDetailClimbAltitude,
        l10n.flightDetailAvgClimb,
        l10n.flightDetailAvgSink,
        l10n.flightDetailThermals,
        l10n.flightDetailAltGained,
        l10n.flightDetailAltLost,
        l10n.flightDetailMaxAltGain,
        l10n.flightDetailElevationDrop,
        l10n.flightDetailTimeBreakdown,
        l10n.flightDetailClimbTime,
        l10n.flightDetailGlideTime,
        l10n.flightDetailSinkTime,
        l10n.flightDetailMovingTime,
      ]) {
        expect(text, contains(field), reason: 'PDF should include $field');
      }
      expect(text, contains('397 m'));
      expect(text, contains('445 m'));
      expect(text, contains('Test Aircraft'));
      expect(text, contains('Paraglider'));
      expect(text, isNot(contains('Category only in export')));
    });

    test(
      'share card and PDF use the current flight-detail outlier setting',
      () async {
        final settings = FlightDetailsSettings.instance;
        final track = _outlierTrack();
        final l10n = AppLocalizationsEn();

        await settings.setFilterVarioOutliers(true);
        final filteredPdf = await FlightReportService.instance.buildPdf(
          track,
          l10n,
        );
        final filteredPdfText = _decodePdfStreams(filteredPdf);
        expect(filteredPdfText, contains('1.0 m/s'));
        expect(filteredPdfText, isNot(contains('6.4 m/s')));
        final filteredCard = await FlightShareCardService.instance.renderPng(
          track,
          l10n,
          colorScheme: ColorScheme.dark(),
        );

        await settings.setFilterVarioOutliers(false);
        final unfilteredPdf = await FlightReportService.instance.buildPdf(
          track,
          l10n,
        );
        final unfilteredPdfText = _decodePdfStreams(unfilteredPdf);
        expect(unfilteredPdfText, contains('6.4 m/s'));
        final unfilteredCard = await FlightShareCardService.instance.renderPng(
          track,
          l10n,
          colorScheme: ColorScheme.dark(),
        );
        expect(unfilteredCard, isNot(equals(filteredCard)));

        await settings.setFilterVarioOutliers(true);
      },
    );

    test('renders a content-sized grouped share card', () async {
      final bytes = await FlightShareCardService.instance.renderPng(
        _completeTrack(),
        AppLocalizationsEn(),
        colorScheme: ColorScheme.dark(),
      );
      final lightBytes = await FlightShareCardService.instance.renderPng(
        _completeTrack(),
        AppLocalizationsEn(),
        colorScheme: ColorScheme.light(),
      );
      expect(lightBytes, isNot(equals(bytes)));
      final data = ByteData.sublistView(Uint8List.fromList(bytes));

      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(data.getUint32(16), 1080);
      expect(data.getUint32(20), greaterThan(1920));
    });

    test('renders a detailed statistics share image', () async {
      final stats = FlightStatistics.compute([_completeTrack()]);
      final bytes = await FlightStatisticsShareCardService.instance.renderPng(
        stats,
        AppLocalizationsEn(),
        selected: false,
        locale: 'en',
        colorScheme: ColorScheme.dark(),
      );
      final lightBytes = await FlightStatisticsShareCardService.instance
          .renderPng(
            stats,
            AppLocalizationsEn(),
            selected: false,
            locale: 'en',
            colorScheme: ColorScheme.light(),
          );
      expect(lightBytes, isNot(equals(bytes)));
      final data = ByteData.sublistView(Uint8List.fromList(bytes));

      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(data.getUint32(16), 1080);
      expect(data.getUint32(20), greaterThan(1920));
    });
  });
}

String _decodePdfStreams(List<int> bytes) {
  final source = String.fromCharCodes(bytes);
  final decoded = StringBuffer();
  var offset = 0;
  while (true) {
    final marker = source.indexOf('stream', offset);
    if (marker < 0) break;
    var start = marker + 'stream'.length;
    if (source.startsWith('\r\n', start)) {
      start += 2;
    } else if (source.startsWith('\n', start) ||
        source.startsWith('\r', start)) {
      start++;
    }
    final end = source.indexOf('endstream', start);
    if (end < 0) break;
    var dataEnd = end;
    while (dataEnd > start &&
        (bytes[dataEnd - 1] == 10 || bytes[dataEnd - 1] == 13)) {
      dataEnd--;
    }
    final stream = Uint8List.fromList(bytes.sublist(start, dataEnd));
    try {
      decoded.write(latin1.decode(ZLibDecoder().convert(stream)));
    } on FormatException {
      try {
        decoded.write(latin1.decode(ZLibDecoder(raw: true).convert(stream)));
      } on FormatException {
        decoded.write(latin1.decode(stream, allowInvalid: true));
      }
    }
    offset = end + 'endstream'.length;
  }
  return RegExp(
    r'\(([^()]*)\)',
  ).allMatches(decoded.toString()).map((match) => match.group(1)!).join(' ');
}

FlightTrack _outlierTrack() {
  final start = DateTime.utc(2026, 10, 1, 9);
  final rates = [0.0, 1.0, 1.0, 1.0, 1.0, 50.0, 1.0, 1.0, 1.0, 1.0];
  final track = FlightTrack(startTime: start);
  for (var index = 0; index < rates.length; index++) {
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: index)),
        data: FlightData(
          verticalSpeed: rates[index],
          altitude: 500,
          baroAltitude: 500,
          gpsAltitude: 500,
          latitude: 22.8 + index * 0.0001,
          longitude: 114.7 + index * 0.0001,
          groundSpeed: 36,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}

FlightTrack _completeTrack() {
  final start = DateTime.utc(2026, 10, 1, 9, 0, 0, 321);
  final track = FlightTrack(startTime: start)
    ..endTime = start.add(const Duration(minutes: 2))
    ..pilotName = 'Test Pilot'
    ..takeoffSite = 'Launch Site'
    ..landingSite = 'Landing Site'
    ..aircraftName = 'Test Aircraft'
    ..aircraftManufacturer = 'Test Manufacturer'
    ..aircraftModel = 'Model A'
    ..aircraftFaiClass = '3'
    ..aircraftCategory = 'Category only in export'
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
          windSpeed: 12 + i.toDouble(),
          gpsAccuracy: 3.2,
          satellites: 8 + i,
          pressure: 1012 - i.toDouble(),
          temperature: 19 + i * 0.2,
          battery: 90 - i,
          heartRate: 120 + i,
          latitude: 22.8 + i * 0.002,
          longitude: 114.7 + i * 0.003,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}
