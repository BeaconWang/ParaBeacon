import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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

  testWidgets(
    'editing a landing point preserves its identity and creation time',
    (tester) async {
      final createdAt = DateTime.utc(2026, 10, 22);
      final originalPoint = LandingPoint(
        id: 'stable-id',
        name: 'Old LZ',
        latitude: 46.5,
        longitude: 6.6,
        altitudeM: 1200,
        createdAt: createdAt,
        notes: 'Old notes',
      );
      LandingPoint? editedPoint;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    editedPoint = await showLandingPointEditorDialog(
                      context,
                      latitude: originalPoint.latitude,
                      longitude: originalPoint.longitude,
                      point: originalPoint,
                      onPickLocation: (context, initialPosition) async {
                        expect(
                          initialPosition.latitude,
                          originalPoint.latitude,
                        );
                        expect(
                          initialPosition.longitude,
                          originalPoint.longitude,
                        );
                        return const LatLng(47.1, 7.2);
                      },
                    );
                  },
                  child: const Text('Edit landing point'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edit landing point'));
      await tester.pumpAndSettle();
      expect(
        find.text('Edit landing point', skipOffstage: false),
        findsWidgets,
      );
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.tap(find.text('Change location on map'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'New LZ');
      await tester.enterText(find.byType(TextFormField).at(1), '1350');
      await tester.enterText(find.byType(TextField).last, 'New access notes');
      await tester.tap(find.text('Save landing point'));
      await tester.pumpAndSettle();

      expect(editedPoint?.id, originalPoint.id);
      expect(editedPoint?.createdAt, createdAt);
      expect(editedPoint?.name, 'New LZ');
      expect(editedPoint?.latitude, 47.1);
      expect(editedPoint?.longitude, 7.2);
      expect(editedPoint?.altitudeM, 1350);
      expect(editedPoint?.notes, 'New access notes');
      expect(tester.takeException(), isNull);
    },
  );
}
