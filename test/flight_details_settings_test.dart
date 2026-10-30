import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/other_settings_sheet.dart';
import 'package:parabeacon/data/flight_details_settings.dart';
import 'package:parabeacon/data/share_card_settings.dart';
import 'package:parabeacon/data/vertical_speed_settings.dart';
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

  test(
    'vertical-speed averaging window defaults and persists in tenths',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = VerticalSpeedSettings.instance;
      await settings.load();

      expect(settings.averageWindowSeconds, 2.0);
      expect(settings.verticalSpeedWindow, const Duration(seconds: 2));

      await settings.setAverageWindowSeconds(2.46);
      expect(settings.averageWindowSeconds, 2.5);
      expect(settings.verticalSpeedWindow, const Duration(milliseconds: 2500));

      await settings.setAverageWindowSeconds(0);
      expect(settings.averageWindowSeconds, 0.5);
      await settings.setAverageWindowSeconds(6);
      expect(settings.averageWindowSeconds, 3.0);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt('pb.verticalSpeed.averageWindowDeciseconds'),
        30,
      );
    },
  );

  testWidgets('Other Settings exposes the default-on filter and parameters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pb.language': 'en'});
    final settings = FlightDetailsSettings.instance;
    final verticalSpeedSettings = VerticalSpeedSettings.instance;
    final shareCardSettings = ShareCardSettings.instance;
    await shareCardSettings.load();
    expect(shareCardSettings.mapSourceId, 'none');
    expect(shareCardSettings.compactLayout, isTrue);
    await settings.setFilterVarioOutliers(true);
    await verticalSpeedSettings.setAverageWindowSeconds(2.0);

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
    expect(find.text('Vertical speed averaging window'), findsOneWidget);
    expect(find.text('Share card map source'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Compact share card layout'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(4));
    expect(settings.filterVarioOutliers, isTrue);

    await tester.tap(find.text('Compact share card layout'));
    await tester.pumpAndSettle();
    expect(shareCardSettings.compactLayout, isFalse);

    final mapSourceDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(mapSourceDropdown);
    await tester.tap(mapSourceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None (no basemap)').last);
    await tester.pumpAndSettle();
    expect(shareCardSettings.mapSourceId, 'none');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('pb.shareCardMapSource'), 'none');

    final averagingSlider = tester.widget<Slider>(find.byType(Slider).first);
    expect(averagingSlider.min, 0.5);
    expect(averagingSlider.max, 3);
    expect(averagingSlider.divisions, 25);
    averagingSlider.onChanged!(2.5);
    await tester.pumpAndSettle();
    expect(verticalSpeedSettings.averageWindowSeconds, 2.5);

    await tester.tap(find.text('Filter climb/sink outliers'));
    await tester.pumpAndSettle();

    expect(settings.filterVarioOutliers, isFalse);
    expect(find.byType(Slider), findsOneWidget);
  });
}
