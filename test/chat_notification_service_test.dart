import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/chat_notification_service.dart';
import 'package:parabeacon/data/chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.beacon.parabeacon/chat_notifications');

  test('requests Android notification permission only once', () async {
    var requests = 0;
    final service = ChatNotificationService(
      isAndroid: true,
      channel: channel,
      requestPermission: () async {
        requests++;
        return true;
      },
    );

    expect(await service.requestPermission(), isTrue);
    expect(await service.requestPermission(), isFalse);
    expect(requests, 1);
  });

  test(
    'sends direct message content to Android notification channel',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = ChatNotificationService(
        isAndroid: true,
        channel: channel,
      );
      final message = ChatMessage(
        id: 'message-123',
        scope: 'direct',
        senderPilotNumber: 234567,
        recipientPilotNumber: 123456,
        senderName: 'Sky Pilot',
        text: 'Landing in ten minutes',
        createdAt: DateTime.utc(2026, 11, 20),
      );

      expect(
        await service.showIncomingMessage(
          message: message,
          title: 'New message from Sky Pilot',
          channelName: 'Pilot Chat messages',
          channelDescription: 'Direct-message alerts',
        ),
        isTrue,
      );
      expect(calls, hasLength(1));
      expect(calls.single.method, 'showIncomingMessage');
      expect(calls.single.arguments, {
        'id': 'message-123',
        'title': 'New message from Sky Pilot',
        'body': 'Landing in ten minutes',
        'channelName': 'Pilot Chat messages',
        'channelDescription': 'Direct-message alerts',
        'senderPilotNumber': 234567,
      });
    },
  );

  test('does not invoke Android APIs on other platforms', () async {
    var requests = 0;
    final service = ChatNotificationService(
      isAndroid: false,
      channel: channel,
      requestPermission: () async {
        requests++;
        return true;
      },
    );
    expect(await service.requestPermission(), isFalse);
    expect(requests, 0);
    expect(
      await service.showIncomingMessage(
        message: ChatMessage(
          id: 'message-1',
          scope: 'direct',
          senderPilotNumber: 234567,
          recipientPilotNumber: 123456,
          senderName: 'Sky Pilot',
          text: 'Hello',
          createdAt: DateTime.utc(2026, 11, 20),
        ),
        title: 'New message',
        channelName: 'Pilot Chat',
        channelDescription: 'Direct messages',
      ),
      isFalse,
    );
  });
}
