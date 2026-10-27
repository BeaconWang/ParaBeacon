import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/ble/ble_sensor_service.dart';
import 'altitude_announcement_bridge.dart' show preferredAnnouncementLanguage;
import 'altitude_announcement_settings.dart';
import 'altitude_announcement_speaker.dart';

/// Speaks a Bluetooth sensor connection phrase as a preview.
Future<bool> speakBleSensorAnnouncementTest(
  BleSensorAnnouncementEvent event, {
  AltitudeAnnouncementSpeaker? speaker,
  AltitudeAnnouncementSettings? settings,
}) {
  final resolvedSettings = settings ?? AltitudeAnnouncementSettings.instance;
  return (speaker ?? AltitudeAnnouncementSpeaker.instance).speak(
    preferred: preferredAnnouncementLanguage(),
    waitIfBusy: true,
    rate: resolvedSettings.speechRate,
    volume: resolvedSettings.volume,
    phraseFor: (language) =>
        resolvedSettings.bleSensorAnnouncementText(event, language),
  );
}

/// Announces Bluetooth sensor connection transitions through the shared speaker.
class BleSensorAnnouncementBridge {
  BleSensorAnnouncementBridge({
    BleSensorService? service,
    Listenable? connectionChanges,
    bool Function()? isConnected,
    AltitudeAnnouncementSpeaker? speaker,
    AltitudeAnnouncementSettings? settings,
  }) : _connectionChanges =
           connectionChanges ?? service ?? BleSensorService.instance,
       _isConnected =
           isConnected ??
           (() => (service ?? BleSensorService.instance).isConnected),
       _speaker = speaker ?? AltitudeAnnouncementSpeaker.instance,
       _settings = settings ?? AltitudeAnnouncementSettings.instance;

  final Listenable _connectionChanges;
  final bool Function() _isConnected;
  final AltitudeAnnouncementSpeaker _speaker;
  final AltitudeAnnouncementSettings _settings;

  bool _attached = false;
  bool _wasConnected = false;
  Future<void> _settingsReady = Future<void>.value();

  void attach() {
    if (_attached) return;
    _attached = true;
    _wasConnected = _isConnected();
    _settingsReady = _settings.load();
    _connectionChanges.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    final connected = _isConnected();
    if (connected == _wasConnected) return;
    _wasConnected = connected;
    unawaited(_announce(connected));
  }

  Future<void> _announce(bool connected) async {
    await _settingsReady;
    if (!_attached ||
        !_settings.announcementsEnabled ||
        !_settings.bleSensorAnnouncementsEnabled ||
        _isConnected() != connected) {
      return;
    }

    final event = connected
        ? BleSensorAnnouncementEvent.connected
        : BleSensorAnnouncementEvent.disconnected;
    await _speaker.speak(
      preferred: preferredAnnouncementLanguage(),
      waitIfBusy: true,
      busyTimeout: const Duration(seconds: 8),
      rate: _settings.speechRate,
      volume: _settings.volume,
      canSpeak: () =>
          _attached &&
          _settings.announcementsEnabled &&
          _settings.bleSensorAnnouncementsEnabled &&
          _isConnected() == connected,
      phraseFor: (language) =>
          _settings.bleSensorAnnouncementText(event, language),
    );
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _connectionChanges.removeListener(_onServiceChanged);
  }
}
