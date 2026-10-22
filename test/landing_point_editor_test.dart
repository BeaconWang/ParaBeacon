import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/landing_point_editor.dart';
import 'package:parabeacon/data/landing_point_store.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('saving a landing point disposes its text controllers safely', (
    tester,
  ) async {
    LandingPoint? savedPoint;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  savedPoint = await showLandingPointEditorDialog(
                    context,
                    latitude: 46.5,
                    longitude: 6.6,
                    altitudeM: 1200,
                  );
                },
                child: const Text('Add landing point'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add landing point'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ridge LZ');
    await tester.tap(find.text('Save landing point'));
    await tester.pumpAndSettle();

    expect(savedPoint?.name, 'Ridge LZ');
    expect(savedPoint?.altitudeM, 1200);
    expect(tester.takeException(), isNull);
  });
}
