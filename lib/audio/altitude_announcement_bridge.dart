import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/widgets.dart';

import '../data/flight_data.dart';
import '../data/unit_settings.dart';
import '../theme/locale_controller.dart';
import 'altitude_announcement_settings.dart';

/// Announces the current altitude once when climb rate enters the configured
/// range and remains there briefly. A sustained drop below the range rearms it.
class AltitudeAnnouncementBridge {
  AltitudeAnnouncementBridge({
    required this.source,
    FlutterTts? speech,
    AltitudeAnnouncementSettings? settings,
  }) : _speech = speech ?? FlutterTts(),
       _settings = settings ?? AltitudeAnnouncementSettings.instance;

  final FlightDataView source;
  final FlutterTts _speech;
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
      var language = _usesChineseSpeech ? 'zh-CN' : 'en-US';
      if (language == 'zh-CN') {
        try {
          if (await _speech.isLanguageAvailable(language) != true) {
            language = 'en-US';
          }
        } catch (_) {
          language = 'en-US';
        }
      }
      try {
        await _speech.setLanguage(language);
      } catch (_) {
        language = 'en-US';
        await _speech.setLanguage(language);
      }
      await _speech.setSpeechRate(0.48);
      await _speech.setPitch(1.0);
      await _speech.awaitSpeakCompletion(true);

      final unit = UnitSettings.instance.defaultUnit(UnitDimension.altitude);
      final isFeet = unit == 'ft';
      final altitude = UnitValues.convert(
        data.altitude,
        UnitDimension.altitude,
        unit,
      ).round();
      final phrase = language == 'zh-CN'
          ? '当前高度，$altitude${isFeet ? '英尺' : '米'}'
          : 'Altitude $altitude ${isFeet ? 'feet' : 'meters'}';
      await _speech.speak(phrase);
    } catch (_) {
      // Speech engines and voices are platform-dependent; fail silently so
      // unavailable TTS never interrupts flight-data processing.
    } finally {
      _speaking = false;
    }
  }

  bool get _usesChineseSpeech {
    final selectedLocale = LocaleController.instance.current.locale;
    final locale =
        selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode.toLowerCase() == 'zh';
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _entryTimer?.cancel();
    _entryTimer = null;
    source.removeListener(_onData);
    _settings.removeListener(_onSettingsChanged);
    unawaited(_speech.stop().catchError((_) {}));
  }
}
