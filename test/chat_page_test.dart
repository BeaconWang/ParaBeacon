import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_page.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('voice recording controls support pause, resume and send', (
    tester,
  ) async {
    var paused = false;
    var cancelCount = 0;
    var sendCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: ChatVoiceRecordingControls(
                elapsed: const Duration(seconds: 12),
                maximumDuration: chatMaximumVoiceDuration,
                paused: paused,
                sending: false,
                cancelling: false,
                onCancel: () => cancelCount++,
                onTogglePause: () => setState(() => paused = !paused),
                onSend: () => sendCount++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Recording voice message'), findsOneWidget);
    expect(find.text('00:12 / 01:30'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause recording'));
    await tester.pump();
    expect(find.text('Recording paused'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume recording'));
    await tester.pump();
    expect(find.text('Recording voice message'), findsOneWidget);
    await tester.tap(find.byTooltip('Send voice message'));
    expect(sendCount, 1);
    await tester.tap(find.byTooltip('Discard voice recording'));
    expect(cancelCount, 1);
  });

  testWidgets('voice recording controls show upload progress state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatVoiceRecordingControls(
            elapsed: const Duration(seconds: 12),
            maximumDuration: chatMaximumVoiceDuration,
            paused: false,
            sending: true,
            cancelling: false,
            onCancel: null,
            onTogglePause: null,
            onSend: null,
          ),
        ),
      ),
    );

    expect(find.text('Sending voice message…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

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
