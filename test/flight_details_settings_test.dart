import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/other_settings_sheet.dart';
import 'package:parabeacon/data/flight_details_settings.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('outlier filter defaults on and persists its parameters', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = FlightDetailsSettings.instance;
    await settings.load();

    expect(settings.filterVarioOutliers, isTrue);
    expect(settings.madMultiplier, 4);
    expect(settings.windowSeconds, 30);
    expect(settings.maximumVerticalSpeedMs, 20);

    await settings.setFilterVarioOutliers(false);
    await settings.setMadMultiplier(5.5);
    await settings.setWindowSeconds(50);
    await settings.setMaximumVerticalSpeedMs(25);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('pb.flightDetails.filterVarioOutliers'),
      isFalse,
    );
    expect(preferences.getDouble('pb.flightDetails.outlierMadMultiplier'), 5.5);
    expect(preferences.getInt('pb.flightDetails.outlierWindowSeconds'), 50);
    expect(preferences.getDouble('pb.flightDetails.maximumVerticalSpeed'), 25);
  });

  testWidgets('Other Settings exposes the default-on filter and parameters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = FlightDetailsSettings.instance;
    await settings.setFilterVarioOutliers(true);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showOtherSettingsSheet(context),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Filter climb/sink outliers'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(settings.filterVarioOutliers, isTrue);

    await tester.tap(find.text('Filter climb/sink outliers'));
    await tester.pumpAndSettle();

    expect(settings.filterVarioOutliers, isFalse);
    expect(find.byType(Slider), findsNothing);
  });
}
