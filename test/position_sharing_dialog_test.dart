import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/position_sharing_dialog.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('position sharing prompt times out without opting in', (
    tester,
  ) async {
    PositionSharingChoice? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
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
    expect(result, PositionSharingChoice.timedOut);
    expect(find.text('Position sharing'), findsNothing);
  });

  testWidgets('sharing starts only after explicit confirmation', (
    tester,
  ) async {
    PositionSharingChoice? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
            timeout: const Duration(seconds: 5),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share my position'));
    await tester.pumpAndSettle();

    expect(result, PositionSharingChoice.share);
  });

  testWidgets('disable action returns a pause choice', (tester) async {
    PositionSharingChoice? result;
    await tester.pumpWidget(
      _TestApp(
        onOpen: (context) async {
          result = await showPositionSharingDialog(
            context,
            timeout: const Duration(seconds: 5),
          );
        },
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable sharing'));
    await tester.pumpAndSettle();

    expect(result, PositionSharingChoice.disable);
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
