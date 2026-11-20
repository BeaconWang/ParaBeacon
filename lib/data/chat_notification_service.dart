import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat_service.dart';

class ChatNotificationService {
  ChatNotificationService({
    required this.isAndroid,
    MethodChannel? channel,
    Future<bool> Function()? requestPermission,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _requestPermission = requestPermission ?? _requestAndroidPermission;

  static const String _channelName = 'com.beacon.parabeacon/chat_notifications';
  static final ChatNotificationService instance = ChatNotificationService(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );

  final bool isAndroid;
  final MethodChannel _channel;
  final Future<bool> Function() _requestPermission;
  bool _permissionPromptAttempted = false;

  Future<bool> requestPermission() async {
    if (!isAndroid) return false;
    if (_permissionPromptAttempted) return false;
    _permissionPromptAttempted = true;
    try {
      return await _requestPermission();
    } on Object {
      return false;
    }
  }

  Future<bool> showIncomingMessage({
    required ChatMessage message,
    required String title,
    required String sourceLabel,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('showIncomingMessage', {
            'id': message.id,
            'title': title,
            'sourceLabel': sourceLabel,
            'body': message.text,
            'channelName': channelName,
            'channelDescription': channelDescription,
            'senderPilotNumber': message.senderPilotNumber,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _requestAndroidPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) status = await Permission.notification.request();
    return status.isGranted;
  }
}
