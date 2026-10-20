import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Language actually used for a spoken announcement.
enum AnnouncementLanguage { chinese, english }

/// Whether the platform text-to-speech stack can currently produce speech.
enum SpeechAvailability { unknown, available, unavailable }

/// Shared, fault-tolerant wrapper around the platform text-to-speech engine.
///
/// Platform engines are unreliable in ways that silently break speech:
/// * Android: the engine may be missing, still binding, lack voice data for
///   the requested language, or never answer `speak` (flutter_tts then keeps
///   the call pending forever). Every platform call is therefore bounded by a
///   timeout, other installed engines are tried, and the language falls back
///   (preferred -> other supported language -> engine default).
/// * iOS: the audio session is owned by the vario engine (miniaudio), which
///   sets PlayAndRecord without mixing. The session is re-asserted before each
///   utterance so speech is routed to the speaker, ignores the silent switch,
///   mixes with the vario tone and works in the background.
class AltitudeAnnouncementSpeaker extends ChangeNotifier {
  AltitudeAnnouncementSpeaker({FlutterTts? tts}) : _ttsOverride = tts;

  static final AltitudeAnnouncementSpeaker instance =
      AltitudeAnnouncementSpeaker();

  static const _callTimeout = Duration(seconds: 3);
  static const _initTimeout = Duration(seconds: 8);
  static const _speakTimeout = Duration(seconds: 12);
  static const _maxFailuresBeforeUnavailable = 2;

  static const _chineseTags = ['zh-CN', 'zh-TW', 'zh-HK', 'zh'];
  static const _englishTags = ['en-US', 'en-GB', 'en-AU', 'en-IN', 'en'];

  final FlutterTts? _ttsOverride;
  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= _ttsOverride ?? FlutterTts();

  SpeechAvailability _availability = SpeechAvailability.unknown;
  SpeechAvailability get availability => _availability;

  bool _busy = false;
  bool _baseConfigured = false;
  AnnouncementLanguage? _preparedFor;
  AnnouncementLanguage? _activeLanguage;
  String? _currentEngine;
  int _failures = 0;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Prepares the engine ahead of time so the first in-flight announcement
  /// does not pay for engine binding / voice selection.
  Future<void> warmUp(AnnouncementLanguage preferred) async {
    if (_busy) return;
    _busy = true;
    try {
      await _prepare(preferred);
    } catch (_) {
      // Best effort only.
    } finally {
      _busy = false;
    }
  }

  /// Speaks the phrase produced by [phraseFor] for the language that could be
  /// prepared. Returns `true` once the utterance completed successfully.
  /// Concurrent requests are dropped (a stale altitude is useless) unless
  /// [waitIfBusy] is set, e.g. for a user-initiated test.
  Future<bool> speak({
    required AnnouncementLanguage preferred,
    required String Function(AnnouncementLanguage language) phraseFor,
    bool waitIfBusy = false,
  }) async {
    if (_busy) {
      if (!waitIfBusy) return false;
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (_busy) {
        if (DateTime.now().isAfter(deadline)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    _busy = true;
    try {
      final language = await _prepare(preferred);
      if (language == null) {
        _setAvailability(SpeechAvailability.unavailable);
        return false;
      }
      if (_isIOS) await _configureIosSession();

      final result = await _call<dynamic>(
        () => _tts.speak(phraseFor(language)),
        _speakTimeout,
      );
      if (_isSuccess(result)) {
        _failures = 0;
        _setAvailability(SpeechAvailability.available);
        return true;
      }
      await _onSpeakFailure();
      return false;
    } catch (_) {
      await _onSpeakFailure();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    final tts = _ttsInstance;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {}
  }

  Future<void> _onSpeakFailure() async {
    // Reset the plugin's pending speak state and force a full re-preparation
    // (possibly with another engine / language) on the next attempt.
    await _call<dynamic>(() => _tts.stop());
    _preparedFor = null;
    _activeLanguage = null;
    _failures++;
    if (_failures >= _maxFailuresBeforeUnavailable) {
      _setAvailability(SpeechAvailability.unavailable);
    }
  }

  Future<AnnouncementLanguage?> _prepare(AnnouncementLanguage preferred) async {
    if (_preparedFor == preferred && _activeLanguage != null) {
      return _activeLanguage;
    }

    if (!_baseConfigured) {
      // On Android the first call is queued until the engine has bound, so
      // allow for a slower start.
      await _call<dynamic>(
        () => _tts.awaitSpeakCompletion(true),
        _initTimeout,
      );
      if (_isIOS) {
        await _call<dynamic>(() => _tts.autoStopSharedSession(false));
      }
      _baseConfigured = true;
    }

    AnnouncementLanguage? language;
    if (_isAndroid) {
      final engines = await _androidEngines();
      if (engines.isEmpty) {
        // No text-to-speech engine installed at all.
        return null;
      }
      if (_currentEngine == null) {
        final defaultEngine = await _call<dynamic>(() => _tts.getDefaultEngine);
        if (defaultEngine is String) _currentEngine = defaultEngine;
      }
      await _applyAndroidAudioAttributes();
      language = await _selectLanguage(preferred);
      if (language == null) {
        for (final engine in engines) {
          if (engine == _currentEngine) continue;
          if (!await _switchAndroidEngine(engine)) continue;
          language = await _selectLanguage(preferred);
          if (language != null) break;
        }
      }
    } else {
      language = await _selectLanguage(preferred);
    }

    // Last resort: the engine's default voice. Numbers are still intelligible
    // and an unsuitable voice is better than silence in flight.
    language ??= AnnouncementLanguage.english;

    await _call<dynamic>(() => _tts.setSpeechRate(0.5));
    await _call<dynamic>(() => _tts.setPitch(1.0));
    await _call<dynamic>(() => _tts.setVolume(1.0));

    _preparedFor = preferred;
    _activeLanguage = language;
    return language;
  }

  /// Picks the first available voice language, preferring locally installed
  /// voices (Android) so announcements also work offline.
  Future<AnnouncementLanguage?> _selectLanguage(
    AnnouncementLanguage preferred,
  ) async {
    final candidates = preferred == AnnouncementLanguage.chinese
        ? [..._chineseTags, ..._englishTags]
        : [..._englishTags, ..._chineseTags];

    final available = <String>[];
    for (final tag in candidates) {
      final ok = await _call<dynamic>(() => _tts.isLanguageAvailable(tag));
      if (ok == true) available.add(tag);
    }
    if (available.isEmpty) return null;

    var ordered = available;
    if (_isAndroid) {
      final installed = <String>[];
      for (final tag in available) {
        final ok = await _call<dynamic>(() => _tts.isLanguageInstalled(tag));
        if (ok == true) installed.add(tag);
      }
      ordered = [
        ...installed,
        ...available.where((tag) => !installed.contains(tag)),
      ];
    }

    for (final tag in ordered) {
      final result = await _call<dynamic>(() => _tts.setLanguage(tag));
      if (_isSuccess(result)) {
        return tag.startsWith('zh')
            ? AnnouncementLanguage.chinese
            : AnnouncementLanguage.english;
      }
    }
    return null;
  }

  Future<List<String>> _androidEngines() async {
    final engines = await _call<dynamic>(() => _tts.getEngines, _initTimeout);
    if (engines is! List) return const [];
    return engines.whereType<String>().toList();
  }

  Future<bool> _switchAndroidEngine(String engine) async {
    try {
      await _tts.setEngine(engine).timeout(_initTimeout);
    } catch (_) {
      return false;
    }
    _currentEngine = engine;
    // A new engine instance loses the previous audio attributes.
    await _applyAndroidAudioAttributes();
    return true;
  }

  Future<void> _applyAndroidAudioAttributes() async {
    // Navigation-guidance usage plays over media/AAudio output (the vario
    // tone) instead of being treated as competing media playback.
    await _call<void>(() => _tts.setAudioAttributesForNavigation());
  }

  Future<void> _configureIosSession() async {
    await _call<dynamic>(
      () => _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        const [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      ),
    );
    await _call<dynamic>(() => _tts.setSharedInstance(true));
  }

  static bool _isSuccess(dynamic result) => result == 1 || result == true;

  void _setAvailability(SpeechAvailability value) {
    if (_availability == value) return;
    _availability = value;
    notifyListeners();
  }

  /// Runs a platform call with a timeout; platform errors and timeouts yield
  /// `null` so a misbehaving engine can never stall flight-data processing.
  static Future<T?> _call<T>(
    Future<T> Function() operation, [
    Duration timeout = _callTimeout,
  ]) async {
    try {
      return await operation().timeout(timeout);
    } catch (_) {
      return null;
    }
  }
}
