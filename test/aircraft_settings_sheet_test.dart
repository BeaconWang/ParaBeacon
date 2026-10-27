import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/aircraft_settings_sheet.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'pb.aircraft.name': 'Custom name'});
  });

  testWidgets('aircraft settings accept custom manufacturer and model values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAircraftSettingsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final manufacturerField = find.widgetWithText(
      TextFormField,
      'Manufacturer',
    );
    await tester.ensureVisible(manufacturerField);
    await tester.enterText(manufacturerField, 'Custom manufacturer');
    await tester.pump();

    final modelField = find.widgetWithText(TextFormField, 'Model');
    await tester.ensureVisible(modelField);
    await tester.enterText(modelField, 'Custom model');
    await tester.pump();

    final saveButton = find.text('Save aircraft');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('pb.aircraft.name'), 'Custom name');
    expect(
      preferences.getString('pb.aircraft.manufacturer'),
      'Custom manufacturer',
    );
    expect(preferences.getString('pb.aircraft.model'), 'Custom model');
  });
}
