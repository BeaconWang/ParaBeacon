import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_page.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:parabeacon/data/pilot_avatar.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  Widget buildTile(ChatMessage message) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ChatMessageTile(message: message, mine: false)),
  );

  testWidgets('Direct message shows profile image and content without title', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTile(
        ChatMessage(
          id: 'direct-1',
          scope: 'direct',
          senderPilotNumber: 234567,
          recipientPilotNumber: 123456,
          senderName: 'Sky Pilot',
          senderAvatarId: 2,
          text: 'Landing in ten minutes',
          createdAt: DateTime.utc(2026, 11, 20, 12),
        ),
      ),
    );

    expect(find.byType(PilotAvatarPicture), findsOneWidget);
    expect(find.text('Landing in ten minutes'), findsOneWidget);
    expect(find.text('Sky Pilot'), findsNothing);
  });

  testWidgets('public chat continues to show the sender title', (tester) async {
    await tester.pumpWidget(
      buildTile(
        ChatMessage(
          id: 'public-1',
          scope: 'public',
          senderPilotNumber: 234567,
          senderName: 'Sky Pilot',
          text: 'Thermals near launch',
          createdAt: DateTime.utc(2026, 11, 20, 12),
        ),
      ),
    );

    expect(find.byType(PilotAvatarPicture), findsOneWidget);
    expect(find.text('Sky Pilot'), findsOneWidget);
    expect(find.text('Thermals near launch'), findsOneWidget);
  });
}
