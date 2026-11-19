import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:parabeacon/data/parabeacon_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('searches accounts by name with an authenticated paged request', () async {
    final accountClient = MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/login');
      return http.Response(
        jsonEncode({
          'access_token': 'chat-search-token',
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
          'refresh_token': 'chat-search-refresh-token-long-value',
          'refresh_expires_at': null,
          'user': {
            'id': 'current-user',
            'username': 'current_pilot',
            'pilot_number': 123456,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final account = ParaBeaconAccountService(
      client: accountClient,
      sessionStore: _SearchSessionStore(),
    );
    addTearDown(account.dispose);
    expect(
      await account.login(identifier: 'current_pilot', password: 'abc123'),
      isTrue,
    );

    final requests = <http.Request>[];
    final chatClient = MockClient((request) async {
      requests.add(request);
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/chat/accounts');
      expect(request.url.queryParameters['q'], 'Summit');
      expect(request.url.queryParameters['limit'], '20');
      expect(request.headers['authorization'], 'Bearer chat-search-token');
      return http.Response(
        jsonEncode({
          'accounts': [
            {
              'pilot_number': 234567,
              'username': 'ridge_runner',
              'display_name': 'Alice Summit',
              'avatar_id': 4,
              'profile_image_url':
                  '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            },
          ],
          'next_cursor': '234567',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final chat = ChatService(accountService: account, httpClient: chatClient);
    addTearDown(() {
      chat.dispose();
      chatClient.close();
      accountClient.close();
    });

    final page = await chat.searchAccounts(query: 'Summit', limit: 20);
    expect(requests, hasLength(1));
    expect(page.accounts, hasLength(1));
    expect(page.accounts.single.title, 'Alice Summit');
    expect(page.accounts.single.username, 'ridge_runner');
    expect(page.accounts.single.pilotNumber, 234567);
    expect(page.accounts.single.avatarId, 4);
    expect(
      page.accounts.single.profileImageUrl,
      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(page.nextCursor, '234567');
    expect(page.toString(), isNot(contains('email')));
  });

  test('loads server conversation ordering and persists pin changes', () async {
    final accountClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'conversation-token',
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
          'refresh_token': 'conversation-refresh-token-long-value',
          'refresh_expires_at': null,
          'user': {
            'id': 'current-user',
            'username': 'current_pilot',
            'pilot_number': 123456,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final account = ParaBeaconAccountService(
      client: accountClient,
      sessionStore: _SearchSessionStore(),
    );
    addTearDown(account.dispose);
    expect(
      await account.login(identifier: 'current_pilot', password: 'abc123'),
      isTrue,
    );

    final requests = <http.Request>[];
    final chatClient = MockClient((request) async {
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer conversation-token');
      if (request.url.path == '/api/v1/chat/conversations') {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['limit'], '20');
        return http.Response(
          jsonEncode({
            'conversations': [
              {
                'pilot_number': 234567,
                'username': 'ridge_runner',
                'display_name': 'Alice Summit',
                'avatar_id': 4,
                'profile_image_url':
                    '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                'online': true,
                'pinned': true,
                'last_chat_at': '2026-11-19T09:30:00Z',
              },
            ],
            'next_cursor': '20',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/api/v1/chat/conversations/234567/pin');
      expect(request.method, 'PUT');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {'pinned': false});
      return http.Response(jsonEncode({'pinned': false}), 200);
    });
    final chat = ChatService(accountService: account, httpClient: chatClient);
    addTearDown(() {
      chat.dispose();
      chatClient.close();
      accountClient.close();
    });

    final page = await chat.listConversations(limit: 20);
    expect(page.conversations, hasLength(1));
    final conversation = page.conversations.single;
    expect(conversation.account.title, 'Alice Summit');
    expect(conversation.account.avatarId, 4);
    expect(
      conversation.account.profileImageUrl,
      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(conversation.online, isTrue);
    expect(conversation.pinned, isTrue);
    expect(conversation.lastChatAt, DateTime.utc(2026, 11, 19, 9, 30));
    expect(page.nextCursor, '20');
    expect(
      await chat.setConversationPinned(pilotNumber: 234567, pinned: false),
      isFalse,
    );
    expect(requests, hasLength(2));
  });

  test('parses conversation state and rejects malformed online metadata', () {
    final conversation = ChatConversation.fromJson({
      'pilot_number': 234567,
      'username': 'sky_pilot',
      'avatar_id': 2,
      'online': false,
      'pinned': true,
    });
    expect(conversation?.account.pilotNumber, 234567);
    expect(conversation?.online, isFalse);
    expect(conversation?.pinned, isTrue);
    expect(
      ChatConversation.fromJson({'online': 'yes', 'pinned': false}),
      isNull,
    );
  });

  test(
    'parses private-message account results without using numbers as labels',
    () {
      final account = ChatAccount.fromJson({
        'pilot_number': 234567,
        'username': 'sky_pilot',
        'display_name': 'Sky Pilot',
        'avatar_id': 6,
      });
      expect(account?.title, 'Sky Pilot');
      expect(account?.avatarId, 6);
      expect(account?.username, 'sky_pilot');
      expect(account?.pilotNumber, 234567);

      final noDisplayName = ChatAccount.fromJson({
        'pilot_number': 234568,
        'username': 'cloud_pilot',
      });
      expect(noDisplayName?.title, 'cloud_pilot');
      expect(
        ChatAccount.fromJson({'pilot_number': 12345, 'username': 'bad'}),
        isNull,
      );
      expect(
        ChatAccount.fromJson({
          'pilot_number': 234569,
          'username': 'bad_avatar',
          'avatar_id': 999,
        }),
        isNull,
      );
    },
  );

  test('parses the partner live-location sharing status as a boolean only', () {
    expect(
      ChatService.parsePartnerLocationStatus({
        'actively_sharing_location': true,
      }),
      isTrue,
    );
    expect(
      ChatService.parsePartnerLocationStatus({
        'actively_sharing_location': false,
      }),
      isFalse,
    );
    expect(ChatService.parsePartnerLocationStatus({'latitude': 47.2}), isNull);
    expect(ChatService.parsePartnerLocationStatus(null), isNull);
  });

  test('parses world, channel and direct messages with pilot identities', () {
    Map<String, Object?> payload({
      String scope = 'public',
      int? channel,
      int? recipient,
    }) => {
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'scope': scope,
      ...?(channel == null ? null : {'channel_number': channel}),
      'sender_pilot_number': 123456,
      'sender_name': 'pilot_one',
      'sender_avatar_id': 3,
      'sender_profile_image_url':
          '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ...?(recipient == null ? null : {'recipient_pilot_number': recipient}),
      'text': 'Hello, pilots',
      'created_at': '2026-11-18T10:00:00Z',
    };

    final public = ChatMessage.fromJson(payload());
    expect(public?.scope, 'public');
    expect(public?.senderPilotNumber, 123456);
    expect(public?.senderAvatarId, 3);
    expect(
      public?.senderProfileImageUrl,
      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(public?.channelNumber, isNull);

    final channel = ChatMessage.fromJson(
      payload(scope: 'channel', channel: 456789),
    );
    expect(channel?.scope, 'channel');
    expect(channel?.channelNumber, 456789);

    final direct = ChatMessage.fromJson(
      payload(scope: 'direct', recipient: 654321),
    );
    expect(direct?.scope, 'direct');
    expect(direct?.recipientPilotNumber, 654321);
    expect(
      ChatMessage.fromJson({...payload(), 'sender_avatar_id': 99}),
      isNull,
    );
    expect(
      ChatMessage.fromJson({
        ...payload(),
        'sender_profile_image_url': 'https://attacker.example/image.jpg',
      }),
      isNull,
    );
  });

  test('rejects malformed identities and oversized messages', () {
    final invalidNumber = ChatMessage.fromJson({
      'id': 'message-id',
      'scope': 'public',
      'sender_pilot_number': 12345,
      'sender_name': 'pilot',
      'sender_avatar_id': 99,
      'text': 'Hello',
      'created_at': '2026-11-18T10:00:00Z',
    });
    expect(invalidNumber, isNull);

    final tooLong = ChatMessage.fromJson({
      'id': 'message-id',
      'scope': 'public',
      'sender_pilot_number': 123456,
      'sender_name': 'pilot',
      'text': List<String>.filled(1001, 'x').join(),
      'created_at': '2026-11-18T10:00:00Z',
    });
    expect(tooLong, isNull);
  });
}

class _SearchSessionStore implements AccountSessionStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
