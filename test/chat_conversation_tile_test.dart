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
      unreadCount: 3,
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
    expect(
      find.byKey(const ValueKey('chat-unread-count-234567')),
      findsOneWidget,
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('3 unread messages'), findsOneWidget);
    expect(find.byTooltip('Pin conversation'), findsOneWidget);

    await tester.tap(find.byTooltip('Pin conversation'));
    expect(pinToggled, isTrue);
    await tester.tap(find.text('Sky Pilot'));
    expect(opened, isTrue);
  });

  testWidgets('hides unread badge when there are no unread messages', (
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
                pilotNumber: 456789,
                username: 'clear_sky',
                displayName: '',
              ),
              online: false,
              pinned: false,
              unreadCount: 0,
            ),
            lastChatTime: null,
            pinning: false,
            onTap: () {},
            onTogglePin: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-unread-count-456789')),
      findsNothing,
    );
    expect(find.byTooltip('0 unread messages'), findsNothing);
  });

  testWidgets('shows the latest message preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatConversationTile(
            conversation: const ChatConversation(
              account: ChatAccount(
                pilotNumber: 567890,
                username: 'summit_pilot',
                displayName: 'Summit Pilot',
              ),
              online: false,
              pinned: false,
              lastMessageText: 'Wind is picking up',
            ),
            lastChatTime: null,
            pinning: false,
            onTap: () {},
            onTogglePin: () {},
          ),
        ),
      ),
    );

    expect(find.text('Wind is picking up'), findsOneWidget);
  });

  testWidgets('shows a localized attachment preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatConversationTile(
            conversation: const ChatConversation(
              account: ChatAccount(
                pilotNumber: 678901,
                username: 'glider',
                displayName: '',
              ),
              online: false,
              pinned: false,
              lastMessageKind: 'image',
            ),
            lastChatTime: null,
            pinning: false,
            onTap: () {},
            onTogglePin: () {},
          ),
        ),
      ),
    );

    expect(find.text('Image'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('chat-unread-count-345678')),
      findsNothing,
    );
    expect(find.text('0'), findsNothing);
    expect(find.byTooltip('0 unread messages'), findsNothing);
    expect(find.byTooltip('Unpin conversation'), findsOneWidget);
    final pinButton = find.ancestor(
      of: find.byIcon(Icons.push_pin),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(pinButton).onPressed, isNull);
  });
}
