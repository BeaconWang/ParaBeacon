import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_page.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('opens pilot chat as a full-screen page route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showChatPage(context),
                child: const Text('Open chat'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(find.text('Pilot Chat'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.text('Sign in to send and receive pilot chat messages.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open chat'), findsOneWidget);
  });
}
