import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_incoming_message_overlay.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('shows incoming pilot message and plays one alert', (
    tester,
  ) async {
    final messages = StreamController<ChatMessage>.broadcast(sync: true);
    var alertCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatIncomingMessageOverlay(
          messages: messages.stream,
          onAlert: () => alertCount++,
          child: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );

    messages.add(
      ChatMessage(
        id: 'incoming-1',
        scope: 'direct',
        senderPilotNumber: 234567,
        recipientPilotNumber: 123456,
        senderName: 'Sky Pilot',
        text: 'Landing in ten minutes',
        createdAt: DateTime.utc(2026, 11, 20),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('New message from Sky Pilot'), findsOneWidget);
    expect(find.text('Landing in ten minutes'), findsOneWidget);
    expect(alertCount, 1);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('New message from Sky Pilot'), findsNothing);
    await messages.close();
  });
}
