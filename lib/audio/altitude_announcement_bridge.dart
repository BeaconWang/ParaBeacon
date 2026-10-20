import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/flight_data.dart';
import '../theme/locale_controller.dart';
import 'altitude_announcement_settings.dart';
import 'altitude_announcement_speaker.dart';
import 'announcement_template.dart';

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
    unawaited(_speaker.warmUp(announcementLanguageFor(_settings.template)));
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
      final spoken = await speakAnnouncement(
        AnnouncementValues(
          altitudeMeters: data.altitude,
          climbMetersPerSecond: data.verticalSpeed,
          groundSpeedKmh: data.hasGroundSpeed ? data.groundSpeed : double.nan,
        ),
        speaker: _speaker,
        settings: _settings,
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

/// Language a template should be spoken in: a custom template picks its voice
/// from its own text, the built-in default follows the UI language.
AnnouncementLanguage announcementLanguageFor(String? customTemplate) {
  final uiLanguage = preferredAnnouncementLanguage();
  return customTemplate == null
      ? uiLanguage
      : AnnouncementTemplate.languageOf(customTemplate, uiLanguage);
}

/// Renders the announcement text the way it will be spoken for [template]
/// (`null` = built-in default) and [language].
String renderAnnouncement(
  String? template,
  AnnouncementLanguage language,
  AnnouncementValues values,
) {
  return AnnouncementTemplate.render(
    template ?? AnnouncementTemplate.defaultFor(language),
    language,
    values,
  );
}

/// Speaks [values] using the configured template.
Future<bool> speakAnnouncement(
  AnnouncementValues values, {
  AltitudeAnnouncementSpeaker? speaker,
  AltitudeAnnouncementSettings? settings,
  bool waitIfBusy = false,
}) {
  final template = (settings ?? AltitudeAnnouncementSettings.instance).template;
  return (speaker ?? AltitudeAnnouncementSpeaker.instance).speak(
    preferred: announcementLanguageFor(template),
    waitIfBusy: waitIfBusy,
    phraseFor: (language) => renderAnnouncement(template, language, values),
  );
}

/// Speaks the configured template with sample values so the user can verify
/// that announcements work and hear how the template sounds.
Future<bool> speakAltitudeAnnouncementTest() {
  return speakAnnouncement(AnnouncementValues.sample, waitIfBusy: true);
}
