import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/flight_data.dart';
import '../data/unit_settings.dart';
import '../theme/locale_controller.dart';
import 'altitude_announcement_settings.dart';
import 'altitude_announcement_speaker.dart';

/// Announces the current altitude once when climb rate enters the configured
/// range and remains there briefly. A sustained drop below the range rearms it.
class AltitudeAnnouncementBridge {
  AltitudeAnnouncementBridge({
    required this.source,
    AltitudeAnnouncementSpeaker? speaker,
    AltitudeAnnouncementSettings? settings,
  }) : _speaker = speaker ?? AltitudeAnnouncementSpeaker.instance,
       _settings = settings ?? AltitudeAnnouncementSettings.instance;

  final FlightDataView source;
  final AltitudeAnnouncementSpeaker _speaker;
  final AltitudeAnnouncementSettings _settings;

  static const _entryDelay = Duration(milliseconds: 900);
  static const _rearmDelay = Duration(seconds: 3);
  static const _rearmHysteresis = 0.2;

  Timer? _entryTimer;
  DateTime? _belowRangeSince;
  bool _armed = true;
  bool _attached = false;
  bool _speaking = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    _settings.load();
    _settings.addListener(_onSettingsChanged);
    source.addListener(_onData);
    _onData();
  }

  void _onSettingsChanged() {
    if (!_settings.enabled) {
      _entryTimer?.cancel();
      _entryTimer = null;
      _belowRangeSince = null;
      _armed = true;
      return;
    }
    // Bind the engine and pick a voice before the first announcement is due.
    unawaited(_speaker.warmUp(preferredAnnouncementLanguage()));
    _onData();
  }

  void _onData() {
    if (!_settings.enabled) return;

    final data = source.data;
    final speed = data.verticalSpeed;
    if (!speed.isFinite) return;

    final now = DateTime.now();
    final rearmBelow = _settings.minimumLiftSpeed - _rearmHysteresis;
    if (speed < rearmBelow) {
      _entryTimer?.cancel();
      _entryTimer = null;
      _belowRangeSince ??= now;
      if (now.difference(_belowRangeSince!) >= _rearmDelay) {
        _armed = true;
      }
      return;
    }

    _belowRangeSince = null;
    final inRange =
        speed >= _settings.minimumLiftSpeed &&
        speed <= _settings.maximumLiftSpeed;
    if (!inRange) {
      _entryTimer?.cancel();
      _entryTimer = null;
      return;
    }
    if (!_armed || _entryTimer != null) return;

    _entryTimer = Timer(_entryDelay, () {
      _entryTimer = null;
      if (!_settings.enabled || !_armed) return;
      final latest = source.data;
      final latestSpeed = latest.verticalSpeed;
      if (!latestSpeed.isFinite ||
          latestSpeed < _settings.minimumLiftSpeed ||
          latestSpeed > _settings.maximumLiftSpeed) {
        return;
      }
      _armed = false;
      unawaited(_speakAltitude(latest));
    });
  }

  Future<void> _speakAltitude(FlightData data) async {
    if (_speaking || !data.altitude.isFinite) return;
    _speaking = true;
    try {
      final spoken = await _speaker.speak(
        preferred: preferredAnnouncementLanguage(),
        phraseFor: (language) => _altitudePhrase(language, data.altitude),
      );
      // A failed attempt (engine still binding, busy, transient error) is
      // retried while lift persists, unless speech is known to be unavailable.
      if (!spoken &&
          _attached &&
          _speaker.availability != SpeechAvailability.unavailable) {
        _armed = true;
      }
    } catch (_) {
      // Never let speech problems interrupt flight-data processing.
    } finally {
      _speaking = false;
    }
  }

  static String _altitudePhrase(
    AnnouncementLanguage language,
    double altitudeMeters,
  ) {
    final unit = UnitSettings.instance.defaultUnit(UnitDimension.altitude);
    final isFeet = unit == 'ft';
    final altitude = UnitValues.convert(
      altitudeMeters,
      UnitDimension.altitude,
      unit,
    ).round();
    return language == AnnouncementLanguage.chinese
        ? '当前高度，$altitude${isFeet ? '英尺' : '米'}'
        : 'Altitude $altitude ${isFeet ? 'feet' : 'meters'}';
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _entryTimer?.cancel();
    _entryTimer = null;
    source.removeListener(_onData);
    _settings.removeListener(_onSettingsChanged);
    unawaited(_speaker.stop());
  }
}

/// Speech language matching the selected UI locale (or the system locale).
AnnouncementLanguage preferredAnnouncementLanguage() {
  final selectedLocale = LocaleController.instance.current.locale;
  final locale =
      selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
  return locale.languageCode.toLowerCase() == 'zh'
      ? AnnouncementLanguage.chinese
      : AnnouncementLanguage.english;
}

/// Speaks a short sample so the user can verify announcements work.
Future<bool> speakAltitudeAnnouncementTest() {
  return AltitudeAnnouncementSpeaker.instance.speak(
    preferred: preferredAnnouncementLanguage(),
    waitIfBusy: true,
    phraseFor: (language) => language == AnnouncementLanguage.chinese
        ? '语音播报测试，${AltitudeAnnouncementBridge._altitudePhrase(language, 1000)}'
        : 'Voice announcement test. '
              '${AltitudeAnnouncementBridge._altitudePhrase(language, 1000)}',
  );
}
