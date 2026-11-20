import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/chat_notification_settings.dart';
import 'package:parabeacon/data/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ChatMessage message(String scope) => ChatMessage(
    id: 'message-$scope',
    scope: scope,
    senderPilotNumber: 234567,
    recipientPilotNumber: scope == 'direct' ? 123456 : null,
    channelNumber: scope == 'channel' ? 483920 : null,
    senderName: 'Sky Pilot',
    text: 'Hello',
    createdAt: DateTime.utc(2026, 11, 20),
  );

  test(
    'defaults Worldwide off and Channel and Direct on, persisting switches',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = ChatNotificationSettings();
      await settings.load();

      expect(settings.worldwide, isFalse);
      expect(settings.channel, isTrue);
      expect(settings.direct, isTrue);
      expect(settings.allows(message('public')), isFalse);
      expect(settings.allows(message('channel')), isTrue);
      expect(settings.allows(message('direct')), isTrue);

      await settings.setWorldwide(false);
      await settings.setChannel(false);
      expect(settings.allows(message('public')), isFalse);
      expect(settings.allows(message('channel')), isFalse);
      expect(settings.allows(message('direct')), isTrue);

      final restored = ChatNotificationSettings();
      await restored.load();
      expect(restored.worldwide, isFalse);
      expect(restored.channel, isFalse);
      expect(restored.direct, isTrue);

      SharedPreferences.setMockInitialValues({
        'pb.chat.notifications.worldwide': true,
      });
      final optedIn = ChatNotificationSettings();
      await optedIn.load();
      expect(optedIn.worldwide, isTrue);
      expect(optedIn.channel, isTrue);
      expect(optedIn.direct, isTrue);
    },
  );
}
