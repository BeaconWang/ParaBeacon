import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_conversation_tile.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  testWidgets('shows online presence, recent chat time, and pin action', (
    tester,
  ) async {
    var opened = false;
    var pinToggled = false;
    final conversation = ChatConversation(
      account: const ChatAccount(
        pilotNumber: 234567,
        username: 'ridge_runner',
        displayName: 'Sky Pilot',
      ),
      online: true,
      pinned: false,
      lastChatAt: DateTime.utc(2026, 11, 19, 9, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatConversationTile(
            conversation: conversation,
            lastChatTime: '9:30 AM',
            pinning: false,
            onTap: () => opened = true,
            onTogglePin: () => pinToggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Sky Pilot'), findsOneWidget);
    expect(find.textContaining('Online'), findsOneWidget);
    expect(find.textContaining('Last chat 9:30 AM'), findsOneWidget);
    expect(find.byTooltip('Pin conversation'), findsOneWidget);

    await tester.tap(find.byTooltip('Pin conversation'));
    expect(pinToggled, isTrue);
    await tester.tap(find.text('Sky Pilot'));
    expect(opened, isTrue);
  });

  testWidgets('shows offline state and pinned conversation control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatConversationTile(
            conversation: const ChatConversation(
              account: ChatAccount(
                pilotNumber: 345678,
                username: 'cloud_pilot',
                displayName: '',
              ),
              online: false,
              pinned: true,
            ),
            lastChatTime: null,
            pinning: true,
            onTap: () {},
            onTogglePin: () {},
          ),
        ),
      ),
    );

    expect(find.text('cloud_pilot'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.byTooltip('Unpin conversation'), findsOneWidget);
    final pinButton = find.ancestor(
      of: find.byIcon(Icons.push_pin),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(pinButton).onPressed, isNull);
  });
}
