import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/position_sharing_dialog.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('position sharing prompt times out without opting in', (
    tester,
  ) async {
    PositionSharingResult? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
            xcontestSignedIn: true,
            paraBeaconSignedIn: false,
            initialXContestSync: true,
            initialParaBeaconSync: false,
            timeout: const Duration(seconds: 5),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Position sharing'), findsOneWidget);
    expect(find.text('Share my position'), findsOneWidget);
    expect(find.text('This prompt closes in 5 sec'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(result?.choice, PositionSharingChoice.timedOut);
    expect(find.text('Position sharing'), findsNothing);
  });

  testWidgets('sharing starts only after explicit confirmation', (
    tester,
  ) async {
    PositionSharingResult? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
            xcontestSignedIn: true,
            paraBeaconSignedIn: false,
            initialXContestSync: true,
            initialParaBeaconSync: false,
            timeout: const Duration(seconds: 5),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share my position'));
    await tester.pumpAndSettle();

    expect(result?.choice, PositionSharingChoice.share);
    expect(result?.syncToXContest, isTrue);
    expect(result?.syncToParaBeacon, isFalse);
  });

  testWidgets('destination switches reflect account login status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          await showPositionSharingDialog(
            context,
            xcontestSignedIn: true,
            paraBeaconSignedIn: false,
            initialXContestSync: true,
            initialParaBeaconSync: false,
            timeout: const Duration(seconds: 30),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();

    final xcontestTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('positionSharingXContest')),
    );
    expect(xcontestTile.value, isTrue);
    expect(xcontestTile.onChanged, isNotNull);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final paraBeaconTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('positionSharingParaBeacon')),
    );
    expect(paraBeaconTile.value, isFalse);
    expect(paraBeaconTile.onChanged, isNull);
  });

  testWidgets('disable action returns a pause choice', (tester) async {
    PositionSharingResult? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
            xcontestSignedIn: true,
            paraBeaconSignedIn: false,
            initialXContestSync: true,
            initialParaBeaconSync: false,
            timeout: const Duration(seconds: 5),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable sharing'));
    await tester.pumpAndSettle();

    expect(result?.choice, PositionSharingChoice.disable);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.onOpen});

  final ValueChanged<BuildContext> onOpen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onOpen(context),
              child: const Text('Open prompt'),
            ),
          ),
        ),
      ),
    );
  }
}
