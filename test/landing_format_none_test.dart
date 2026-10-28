import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/data_value_control.dart';
import 'package:parabeacon/controls/landing_waypoint_control.dart';
import 'package:parabeacon/data/flight_data_provider.dart';
import 'package:parabeacon/data/flight_data_transformer.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('None format hides readout but keeps compass dial', (
    tester,
  ) async {
    final source = BluetoothSensorFlightDataSource();
    final transformer = FlightDataTransformer(rawSource: source);
    addTearDown(() {
      transformer.dispose();
      source.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlightDataProvider(
          transformer: transformer,
          child: const SizedBox(
            width: 240,
            height: 140,
            child: LandingWaypointControl(
              reference: LandingReference.defaultPoint,
              showDistance: false,
              showBearingString: false,
              showElevation: false,
              showGlide: false,
              showEta: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BRG'), findsOneWidget);
    expect(find.text('--'), findsNothing);
  });
}
