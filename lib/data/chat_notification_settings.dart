import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_service.dart';

class ChatNotificationSettings extends ChangeNotifier {
  ChatNotificationSettings();

  static final ChatNotificationSettings instance = ChatNotificationSettings();
  static const _worldwideKey = 'pb.chat.notifications.worldwide';
  static const _channelKey = 'pb.chat.notifications.channel';
  static const _directKey = 'pb.chat.notifications.direct';

  bool _loaded = false;
  bool _worldwide = false;
  bool _channel = true;
  bool _direct = true;

  bool get worldwide => _worldwide;
  bool get channel => _channel;
  bool get direct => _direct;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _worldwide = preferences.getBool(_worldwideKey) ?? false;
      _channel = preferences.getBool(_channelKey) ?? true;
      _direct = preferences.getBool(_directKey) ?? true;
    } on Object {
      // Keep the configured defaults if local preferences are unavailable.
    }
    notifyListeners();
  }

  bool allows(ChatMessage message) => switch (message.scope) {
    'public' => _worldwide,
    'channel' => _channel,
    'direct' => _direct,
    _ => false,
  };

  Future<void> setWorldwide(bool enabled) async {
    _worldwide = enabled;
    notifyListeners();
    await _persist(_worldwideKey, enabled);
  }

  Future<void> setChannel(bool enabled) async {
    _channel = enabled;
    notifyListeners();
    await _persist(_channelKey, enabled);
  }

  Future<void> setDirect(bool enabled) async {
    _direct = enabled;
    notifyListeners();
    await _persist(_directKey, enabled);
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } on Object {
      // The current selection remains active for this session.
    }
  }
}
