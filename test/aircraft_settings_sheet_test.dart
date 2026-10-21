import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/aircraft_settings_sheet.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'pb.aircraft.name': 'Custom name'});
  });

  testWidgets('saving aircraft settings preserves the stored aircraft name', (
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

    final saveButton = find.text('Save aircraft');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('pb.aircraft.name'), 'Custom name');
  });
}
