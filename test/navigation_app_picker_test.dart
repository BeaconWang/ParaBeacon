import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:parabeacon/controls/navigation_app_picker.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('shows compatible navigation apps and launches selection', (
    tester,
  ) async {
    var launched = false;
    final googleMaps = SupportedMap.launchable(
      map: MapApp.google,
      isInstalled: true,
      launcher: () async {
        launched = true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showNavigationAppPicker(
                context,
                latitude: 37.422,
                longitude: -122.084,
                loadMaps: (latitude, longitude) async {
                  expect(latitude, 37.422);
                  expect(longitude, -122.084);
                  return [googleMaps];
                },
              ),
              child: const Text('Show map apps'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show map apps'));
    await tester.pumpAndSettle();
    expect(find.text('Navigate with'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('navigation-app-google')));
    await tester.pumpAndSettle();
    expect(launched, isTrue);
  });

  testWidgets('rejects invalid coordinates without searching installed apps', (
    tester,
  ) async {
    var loaderCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showNavigationAppPicker(
                context,
                latitude: 91,
                longitude: 0,
                loadMaps: (_, _) async {
                  loaderCalled = true;
                  return const [];
                },
              ),
              child: const Text('Invalid target'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Invalid target'));
    await tester.pumpAndSettle();

    expect(loaderCalled, isFalse);
    expect(find.text('Navigate with'), findsNothing);
  });
}
