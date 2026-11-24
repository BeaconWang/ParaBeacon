import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_page.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:parabeacon/data/pilot_avatar.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  Widget buildTile(
    ChatMessage message, {
    bool mine = false,
    bool groupedWithPrevious = false,
    bool groupedWithNext = false,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatMessageTile(
        message: message,
        mine: mine,
        groupedWithPrevious: groupedWithPrevious,
        groupedWithNext: groupedWithNext,
      ),
    ),
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

  testWidgets('own Direct message shows whether the recipient has read it', (
    tester,
  ) async {
    for (final hasRead in [true, false]) {
      await tester.pumpWidget(
        buildTile(
          ChatMessage(
            id: 'direct-read-$hasRead',
            scope: 'direct',
            senderPilotNumber: 123456,
            recipientPilotNumber: 234567,
            senderName: 'Current Pilot',
            text: 'Meet at launch',
            createdAt: DateTime.utc(2026, 11, 20, 12),
            recipientHasRead: hasRead,
          ),
          mine: true,
        ),
      );
      expect(find.text(hasRead ? 'Read' : 'Not read'), findsOneWidget);
    }
  });

  testWidgets('Worldwide and Channel messages show reader counts', (
    tester,
  ) async {
    for (final scope in ['public', 'channel']) {
      await tester.pumpWidget(
        buildTile(
          ChatMessage(
            id: '$scope-read-count',
            scope: scope,
            senderPilotNumber: 234567,
            channelNumber: scope == 'channel' ? 456789 : null,
            senderName: 'Sky Pilot',
            text: 'Conditions look good',
            createdAt: DateTime.utc(2026, 11, 20, 12),
            readerCount: 7,
          ),
        ),
      );
      expect(find.text('Read by 7'), findsOneWidget);
    }
  });

  testWidgets('grouped public messages omit repeated sender header', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTile(
        ChatMessage(
          id: 'public-grouped',
          scope: 'public',
          senderPilotNumber: 234567,
          senderName: 'Sky Pilot',
          text: 'Another update',
          createdAt: DateTime.utc(2026, 11, 20, 12, 1),
        ),
        groupedWithPrevious: true,
        groupedWithNext: true,
      ),
    );

    expect(find.text('Sky Pilot'), findsNothing);
    expect(find.text('Another update'), findsOneWidget);
  });

  testWidgets('location messages show coordinates and optional caption', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTile(
        ChatMessage(
          id: 'location-1',
          scope: 'direct',
          senderPilotNumber: 234567,
          senderName: 'Sky Pilot',
          text: 'At launch',
          kind: 'location',
          latitude: 37.4219999,
          longitude: -122.0840575,
          createdAt: DateTime.utc(2026, 11, 20, 12),
        ),
      ),
    );

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('37.42200, -122.08406'), findsOneWidget);
    expect(find.byTooltip('Open location in maps'), findsOneWidget);
    expect(find.text('At launch'), findsOneWidget);
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
