import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/chat_service.dart';

void main() {
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
      ...?(recipient == null ? null : {'recipient_pilot_number': recipient}),
      'text': 'Hello, pilots',
      'created_at': '2026-11-18T10:00:00Z',
    };

    final public = ChatMessage.fromJson(payload());
    expect(public?.scope, 'public');
    expect(public?.senderPilotNumber, 123456);
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
  });

  test('rejects malformed identities and oversized messages', () {
    final invalidNumber = ChatMessage.fromJson({
      'id': 'message-id',
      'scope': 'public',
      'sender_pilot_number': 12345,
      'sender_name': 'pilot',
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
