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
///   timeout and other installed engines are tried. English announcements only
///   use English voices; Chinese announcements may fall back to English or the
///   engine default.
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

  /// User-facing speech speed range, as a multiple of the normal speed.
  static const minRate = 0.5;
  static const maxRate = 8.0;

  /// Maps a speed multiple (1.0 = normal) to flutter_tts' rate scale, where
  /// 0.5 is the normal speed on every platform.
  ///
  /// * Android (default): the plugin doubles the value into
  ///   `TextToSpeech.setSpeechRate`, which is linear, so `0.5 * multiple`
  ///   yields the exact multiple (8.0x -> 4.0).
  /// * Apple ([apple]): `AVSpeechUtterance.rate` is limited to 0..1 with the
  ///   normal speed at 0.5, so speeds above normal are spread over 0.5..1.0
  ///   (8.0x -> 1.0, the fastest voice).
  static double platformRateFor(double multiple, {bool apple = false}) {
    final m = multiple.isFinite ? multiple.clamp(minRate, maxRate) : 1.0;
    if (apple && m > 1.0) {
      return (0.5 + 0.5 * (m - 1.0) / (maxRate - 1.0)).clamp(0.5, 1.0);
    }
    return (0.5 * m).clamp(0.1, 4.0);
  }

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
  bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Plays an optional cue; a failing or hanging cue never blocks speech.
  static Future<void> _runPrelude(Future<void> Function()? prelude) async {
    if (prelude == null) return;
    try {
      await prelude().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

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
  /// [waitIfBusy] is set (e.g. for a user-initiated test or a takeoff /
  /// landing event), in which case the request waits up to [busyTimeout].
  ///
  /// [prelude] (e.g. a notification ding) is played right before the
  /// utterance, while [speaking] is already set so the vario is ducked.
  /// [canSpeak] is rechecked after asynchronous setup and before speaking.
  Future<bool> speak({
    required AnnouncementLanguage preferred,
    required String Function(AnnouncementLanguage language) phraseFor,
    bool waitIfBusy = false,
    Duration busyTimeout = const Duration(seconds: 45),
    double rate = 1.0,
    Future<void> Function()? prelude,
    bool Function()? canSpeak,
  }) async {
    if (canSpeak != null && !canSpeak()) return false;
    if (_busy) {
      if (!waitIfBusy) return false;
      final deadline = DateTime.now().add(busyTimeout);
      while (_busy) {
        if (canSpeak != null && !canSpeak()) return false;
        if (DateTime.now().isAfter(deadline)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    _busy = true;
    try {
      final language = await _prepare(preferred);
      if (canSpeak != null && !canSpeak()) return false;
      if (language == null) {
        // Still show the text (and play the cue) so the information is not
        // lost without voice.
        _showCaption(phraseFor(preferred));
        await _runPrelude(prelude);
        _setAvailability(SpeechAvailability.unavailable);
        return false;
      }
      if (_isIOS) await _configureIosSession();
      // Applied before every utterance: it is cheap, follows setting changes
      // immediately and survives Android engine switches (which reset it).
      await _call<dynamic>(
        () => _tts.setSpeechRate(platformRateFor(rate, apple: _isApple)),
      );
      if (canSpeak != null && !canSpeak()) return false;

      final text = phraseFor(language);
      _showCaption(text);
      speaking.value = true;
      await _runPrelude(prelude);
      if (canSpeak != null && !canSpeak()) return false;
      final result = await _call<dynamic>(
        () => _tts.speak(text),
        _speakTimeout,
      );
      speaking.value = false;
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
      speaking.value = false;
      _busy = false;
      _hideCaptionLater();
    }
  }

  /// `true` while an utterance is being spoken (used to duck the vario).
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// Text of the announcement currently being spoken (kept on screen briefly
  /// after it finishes), or `null` when nothing should be displayed.
  final ValueNotifier<String?> caption = ValueNotifier<String?>(null);
  Timer? _captionTimer;

  static const _captionLinger = Duration(seconds: 4);

  void _showCaption(String text) {
    _captionTimer?.cancel();
    _captionTimer = null;
    caption.value = text;
  }

  void _hideCaptionLater() {
    if (caption.value == null) return;
    _captionTimer?.cancel();
    _captionTimer = Timer(_captionLinger, () {
      _captionTimer = null;
      caption.value = null;
    });
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
      await _call<dynamic>(() => _tts.awaitSpeakCompletion(true), _initTimeout);
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

    // Never speak English text with an unverified engine-default voice: on
    // Android that default can be Chinese and numbers may then be misread.
    if (language == null && preferred == AnnouncementLanguage.english) {
      return null;
    }

    // For Chinese announcements, retain the engine-default fallback.
    language ??= AnnouncementLanguage.english;

    await _call<dynamic>(() => _tts.setSpeechRate(platformRateFor(1.0)));
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
        : _englishTags;

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
