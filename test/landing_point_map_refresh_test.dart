import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap, MarkerLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parabeacon/controls/map_control.dart';
import 'package:parabeacon/data/flight_data_transformer.dart';
import 'package:parabeacon/data/flight_data_provider.dart';
import 'package:parabeacon/data/landing_point_store.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('map setting changes update the mounted camera zoom', (
    tester,
  ) async {
    final source = BluetoothSensorFlightDataSource();
    final transformer = FlightDataTransformer(rawSource: source);
    addTearDown(() {
      transformer.dispose();
      source.dispose();
    });
    source.ingestGpsSnapshot(
      latitude: 46.5,
      longitude: 6.6,
      heading: 0,
      groundSpeedKmh: 0,
    );

    await tester.pumpWidget(_zoomHarness(transformer, 8));
    await tester.pumpAndSettle();
    _expectCameraZoom(tester, 8);
    expect(find.textContaining('Z 8'), findsOneWidget);

    await tester.pumpWidget(_zoomHarness(transformer, 12));
    await tester.pumpAndSettle();
    _expectCameraZoom(tester, 12);
    expect(find.textContaining('Z 8'), findsNothing);
    expect(find.textContaining('Z 12'), findsOneWidget);
  });

  testWidgets('all mounted map controls reflect landing point mutations', (
    tester,
  ) async {
    final store = LandingPointStore.instance;
    await store.load();
    for (final point in store.points) {
      await store.remove(point.id);
    }
    await store.setDefault(null);

    final source = BluetoothSensorFlightDataSource();
    final transformer = FlightDataTransformer(rawSource: source);
    addTearDown(() {
      transformer.dispose();
      source.dispose();
    });
    source.ingestGpsSnapshot(
      latitude: 46.5,
      longitude: 6.6,
      heading: 0,
      groundSpeedKmh: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlightDataProvider(
            transformer: transformer,
            child: Row(
              children: [
                Expanded(child: _map()),
                Expanded(child: _map()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    _expectMapMarkers(tester, const []);

    final point = LandingPoint(
      id: 'refresh-test-lz',
      name: 'Original LZ',
      latitude: 46.5,
      longitude: 6.6,
      createdAt: DateTime.utc(2026, 10, 29),
    );
    expect(await store.add(point), isTrue);
    await tester.pump();
    _expectMapMarkers(tester, const [LatLng(46.5, 6.6)]);
    expect(find.text('Original LZ'), findsNWidgets(2));

    final updatedPoint = LandingPoint(
      id: point.id,
      name: 'Updated LZ',
      latitude: 46.5001,
      longitude: 6.6001,
      altitudeM: 1250,
      createdAt: point.createdAt,
    );
    expect(await store.update(updatedPoint), isTrue);
    await tester.pump();
    _expectMapMarkers(tester, const [LatLng(46.5001, 6.6001)]);
    expect(find.text('Original LZ'), findsNothing);
    expect(find.text('Updated LZ'), findsNWidgets(2));

    await store.remove(point.id);
    await tester.pump();
    _expectMapMarkers(tester, const []);
    expect(find.text('Updated LZ'), findsNothing);
  });
}

Widget _zoomHarness(FlightDataTransformer transformer, double zoom) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlightDataProvider(
          transformer: transformer,
          child: MapControl(
            key: const ValueKey('zoom-test-map'),
            initialCenter: const LatLng(46.5, 6.6),
            initialZoom: zoom,
            follow: false,
            tileSource: 'none',
            showTrack: false,
            showThermal: false,
            showAirspace: false,
            showWind: false,
            showNorth: false,
            showScale: false,
            showLegend: false,
            showZoomLevel: true,
            showAttribution: false,
            showStatus: false,
            showOtherPilots: false,
          ),
        ),
      ),
    );

void _expectCameraZoom(WidgetTester tester, double zoom) {
  final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
  expect(map.mapController!.camera.zoom, closeTo(zoom, 0.01));
}

MapControl _map() => const MapControl(
  initialCenter: LatLng(46.5, 6.6),
  initialZoom: 16,
  follow: false,
  tileSource: 'none',
  showTrack: false,
  showThermal: false,
  showAirspace: false,
  showNearestLandingPoint: true,
  showDefaultLandingPoint: false,
  showDefaultLandingLine: false,
  showNearestLandingLine: false,
  showWind: false,
  showNorth: false,
  showScale: false,
  showLegend: false,
  showZoomLevel: false,
  showAttribution: false,
  showStatus: false,
);

void _expectMapMarkers(WidgetTester tester, Iterable<LatLng> points) {
  final expected = points.toList();
  final layers = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer));
  if (expected.isEmpty) {
    expect(layers, isEmpty);
    return;
  }
  expect(layers, hasLength(2));
  for (final layer in layers) {
    expect(layer.markers, hasLength(expected.length));
    for (var index = 0; index < expected.length; index++) {
      expect(layer.markers[index].point.latitude, expected[index].latitude);
      expect(layer.markers[index].point.longitude, expected[index].longitude);
    }
  }
}
