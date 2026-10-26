import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../data/flight_state.dart';
import '../data/takeoff_reference.dart';
import '../theme/locale_controller.dart';
import 'altitude_announcement_settings.dart';
import 'altitude_announcement_speaker.dart';
import 'announcement_template.dart';
import 'announcement_triggers.dart';
import 'custom_announcement_rule.dart';
import 'vario_audio_service.dart';
import 'vario_ducking.dart';

/// Turns flight events into voice announcements:
///
///  * **Takeoff / continue flight / landing** — spoken after a notification
///    ding when the corresponding flight transition occurs. Landing is allowed
///    to speak after the flight state has switched off.
///  * **Glide dead zone** — during a flight, spoken after the vertical speed
///    has stayed in the (silent) dead zone for the configured delay, then
///    repeated at the configured interval while it stays there.
///  * **Altitude record** — during a flight, spoken immediately when the
///    altitude exceeds the highest altitude recorded so far; consecutive
///    records are spaced by at least the configured interval.
class AltitudeAnnouncementBridge {
  AltitudeAnnouncementBridge({
    required this.source,
    AltitudeAnnouncementSpeaker? speaker,
    AltitudeAnnouncementSettings? settings,
    VarioDuckingController? ducking,
    FlightState? flightState,
    FlightRecorder? recorder,
    Future<void> Function()? chime,
  }) : _speaker = speaker ?? AltitudeAnnouncementSpeaker.instance,
       _settings = settings ?? AltitudeAnnouncementSettings.instance,
       _ducking = ducking ?? VarioDuckingController(),
       _flightState = flightState ?? FlightState.instance,
       _recorder = recorder ?? FlightRecorder.instance,
       _chime = chime ?? playAnnouncementChime;

  final FlightDataView source;
  final AltitudeAnnouncementSpeaker _speaker;
  final AltitudeAnnouncementSettings _settings;
  final VarioDuckingController _ducking;
  final FlightState _flightState;
  final FlightRecorder _recorder;
  final Future<void> Function() _chime;

  /// How long a takeoff / continue announcement may wait for a running one.
  static const _transitionBusyTimeout = Duration(seconds: 10);

  final DwellTrigger _glide = DwellTrigger();
  final AltitudeRecordTrigger _record = AltitudeRecordTrigger();
  final Map<AnnouncementEvent, Timer> _timers = {};
  final Set<AnnouncementEvent> _inProgress = {};
  final Map<int, _CustomAnnouncementState> _customStates = {};
  final Map<int, Timer> _customTimers = {};
  final Set<int> _customInProgress = {};
  StreamSubscription<FlightTransition>? _transitionSubscription;

  /// Highest altitude of the current (or just completed) flight.
  double _flightMaxAltitude = double.nan;
  bool _attached = false;
  bool _wasFlying = false;
  bool? _wasEnabled;
  bool? _wasRecordEnabled;
  AltitudeRecordScope? _lastRecordScope;

  void attach() {
    if (_attached) return;
    _attached = true;
    _settings.load();
    _settings.addListener(_onSettingsChanged);
    _wasFlying = _flightState.isFlying;
    _flightState.addListener(_onFlightStateChanged);
    source.addListener(_onData);
    _transitionSubscription = _recorder.transitions.listen(_onTransition);
    // Also covers the test announcements, which go through the same speaker.
    _ducking.attach();
    _wasRecordEnabled = _settings.recordEnabled;
    _lastRecordScope = _settings.recordScope;
    _onData();
  }

  void _onFlightStateChanged() {
    final isFlying = _flightState.isFlying;
    if (isFlying == _wasFlying) return;
    _wasFlying = isFlying;
    if (isFlying) return;

    _resetDwell(AnnouncementEvent.glide, _glide);
    _cancelTimer(AnnouncementEvent.altitudeRecord);
    _resetCustomRules();
    if (_speaker.speaking.value) unawaited(_speaker.stop());
  }

  void _onSettingsChanged() {
    final anyEnabled = _settings.anyEnabled;
    final becameEnabled = anyEnabled && _wasEnabled != true;
    _wasEnabled = anyEnabled;

    if (!_settings.announcementsEnabled) {
      _resetDwell(AnnouncementEvent.glide, _glide);
      _cancelTimer(AnnouncementEvent.altitudeRecord);
      _resetCustomRules();
      if (_speaker.speaking.value) unawaited(_speaker.stop());
    }
    if (!_settings.glideEnabled) _resetDwell(AnnouncementEvent.glide, _glide);
    if (!_settings.recordEnabled) {
      _cancelTimer(AnnouncementEvent.altitudeRecord);
    }

    final recordTurnedOn = _settings.recordEnabled && _wasRecordEnabled != true;
    final scopeChanged = _settings.recordScope != _lastRecordScope;
    _wasRecordEnabled = _settings.recordEnabled;
    _lastRecordScope = _settings.recordScope;
    if ((recordTurnedOn || scopeChanged) && _flightState.isFlying) {
      _resetRecord(includeCurrentFlight: true);
    }

    if (becameEnabled) {
      // Bind the engine and pick a voice before the first announcement is due.
      unawaited(_speaker.warmUp(announcementLanguageFor(_firstTemplate())));
    }
    _onData();
  }

  String? _firstTemplate() {
    for (final event in AnnouncementEvent.values) {
      final template = _settings.templateFor(event);
      if (template != null) return template;
    }
    for (final rule in _settings.customRules) {
      if (rule.enabled && rule.content.isNotEmpty) return rule.content;
    }
    return null;
  }

  // ── Takeoff / landing ─────────────────────────────────────────────────────

  void _onTransition(FlightTransition transition) {
    if (!_attached) return;
    final AnnouncementEvent event;
    switch (transition.kind) {
      case FlightTransitionKind.takeoff:
        _flightMaxAltitude = double.nan;
        _resetDwell(AnnouncementEvent.glide, _glide);
        _resetRecord(includeCurrentFlight: false);
        event = AnnouncementEvent.takeoff;
      case FlightTransitionKind.resumedTakeoff:
        // Same flight record: keep its maximum altitude and record state.
        event = AnnouncementEvent.continueFlight;
      case FlightTransitionKind.landing:
        _resetDwell(AnnouncementEvent.glide, _glide);
        _cancelTimer(AnnouncementEvent.altitudeRecord);
        event = AnnouncementEvent.landing;
    }
    if (!_settings.takeoffLandingEnabled) return;
    unawaited(
      _announce(
        event,
        _valuesFor(source.data, track: transition.track),
        waitIfBusy: true,
      ),
    );
  }

  // ── Live data ─────────────────────────────────────────────────────────────

  void _onData() {
    if (!_attached) return;
    final data = source.data;
    final now = DateTime.now();
    final flying = _flightState.isFlying;
    final hasAltitude = _hasAltitude(data);
    if (flying && hasAltitude && !(_flightMaxAltitude >= data.altitude)) {
      _flightMaxAltitude = data.altitude;
    }
    _evaluateGlide(now, data, flying);
    _evaluateRecord(now, data, flying && hasAltitude);
    _evaluateCustomRules(now, data, flying);
  }

  void _evaluateGlide(DateTime now, FlightData data, bool flying) {
    final speed = data.verticalSpeed;
    if (!_settings.announcementsEnabled ||
        !_settings.glideEnabled ||
        !flying ||
        !speed.isFinite) {
      _resetDwell(AnnouncementEvent.glide, _glide);
      return;
    }
    final inside =
        speed >= _settings.glideMinimum && speed <= _settings.glideMaximum;
    final dwell = _settings.glideDelay;
    final repeat = _settings.glideRepeat;
    final due = _glide.update(
      now,
      inside: inside,
      rearming: !inside,
      dwell: dwell,
      repeatEvery: repeat,
    );
    if (due) {
      _cancelTimer(AnnouncementEvent.glide);
      if (_inProgress.contains(AnnouncementEvent.glide)) {
        // Previous one still speaking (long text / short interval): repeat
        // as soon as it has finished.
        _glide.rearm();
        return;
      }
      unawaited(
        _announce(
          AnnouncementEvent.glide,
          _valuesFor(data),
          onDone: (spoken) => _rearmAfterFailure(_glide, spoken),
        ),
      );
      return;
    }
    _scheduleRecheckIn(
      AnnouncementEvent.glide,
      _glide.pendingFor(now, dwell, repeat),
    );
  }

  void _evaluateRecord(DateTime now, FlightData data, bool track) {
    if (!track) return;
    // The peak is tracked even while the announcement is off, so enabling it
    // mid-flight compares against the whole flight so far.
    final enabled = _settings.announcementsEnabled && _settings.recordEnabled;
    final interval = _settings.recordInterval;
    final due = _record.update(
      data.altitude,
      now,
      minInterval: interval,
      announce:
          enabled && !_inProgress.contains(AnnouncementEvent.altitudeRecord),
    );
    if (!enabled) return;
    if (!due) {
      // A record broken during the minimum interval is announced as soon as
      // the interval is over, even if no new sample arrives by then.
      _scheduleRecheckIn(
        AnnouncementEvent.altitudeRecord,
        _record.pendingFor(now, interval),
      );
      return;
    }
    _cancelTimer(AnnouncementEvent.altitudeRecord);
    unawaited(
      _announce(
        AnnouncementEvent.altitudeRecord,
        _valuesFor(data).copyWith(maxAltitudeMeters: _record.peak),
        onDone: (spoken) {
          // Retried on the next sample unless speech is unavailable.
          if (!spoken &&
              _speaker.availability != SpeechAvailability.unavailable) {
            _record.undoLastAnnouncement();
          }
        },
      ),
    );
  }

  void _evaluateCustomRules(DateTime now, FlightData data, bool flying) {
    final rules = _settings.customRules;
    final activeIds = rules.map((rule) => rule.id).toSet();
    for (final id in _customStates.keys.toList()) {
      if (!activeIds.contains(id)) {
        _customStates.remove(id)?.trigger.reset();
        _cancelCustomTimer(id);
      }
    }
    if (!_settings.announcementsEnabled || !flying) {
      _resetCustomRules();
      return;
    }

    for (final rule in rules) {
      var state = _customStates[rule.id];
      if (state == null || !state.hasSameTriggerConfig(rule)) {
        _cancelCustomTimer(rule.id);
        state = _CustomAnnouncementState(rule);
        _customStates[rule.id] = state;
      } else {
        state.rule = rule;
      }
      if (!rule.enabled) {
        state.trigger.reset();
        _cancelCustomTimer(rule.id);
        continue;
      }

      final due = state.trigger.update(
        now,
        condition: rule.matches(data),
        repeatEvery: rule.repeatEvery,
      );
      if (due) {
        _cancelCustomTimer(rule.id);
        if (_customInProgress.contains(rule.id)) {
          state.trigger.retryNow();
        } else {
          unawaited(_announceCustomRule(rule, _valuesFor(data)));
        }
        continue;
      }
      _scheduleCustomRecheckIn(
        rule.id,
        state.trigger.pendingFor(now, rule.repeatEvery),
      );
    }
  }

  Future<void> _announceCustomRule(
    CustomAnnouncementRule rule,
    AnnouncementValues values,
  ) async {
    if (!_maySpeakCustomRule(rule.id) || _customInProgress.contains(rule.id)) {
      return;
    }
    _customInProgress.add(rule.id);
    var spoken = false;
    try {
      final template =
          AnnouncementTemplate.sanitize(rule.content) ??
          (preferredAnnouncementLanguage() == AnnouncementLanguage.chinese
              ? '条件已满足'
              : 'Condition met');
      spoken = await _speaker.speak(
        preferred: announcementLanguageFor(template),
        rate: _settings.speechRate,
        volume: _settings.volume,
        canSpeak: () => _maySpeakCustomRule(rule.id),
        phraseFor: (language) =>
            AnnouncementTemplate.render(template, language, values),
      );
    } catch (_) {
      // Voice failures must not interrupt live flight-data processing.
    } finally {
      _customInProgress.remove(rule.id);
    }

    if (!_attached) return;
    final state = _customStates[rule.id];
    if (spoken) {
      _onData();
    } else if (_speaker.availability != SpeechAvailability.unavailable) {
      state?.trigger.retryNow();
      _scheduleCustomRetry(rule.id);
    }
  }

  bool _maySpeakCustomRule(int id) =>
      _attached &&
      _settings.announcementsEnabled &&
      _flightState.isFlying &&
      _settings.customRules.any((rule) => rule.id == id && rule.enabled);

  void _scheduleCustomRecheckIn(int id, Duration? left) {
    if (left == null) {
      _cancelCustomTimer(id);
      return;
    }
    if (_customTimers.containsKey(id)) return;
    final delay = left == Duration.zero
        ? const Duration(milliseconds: 100)
        : left + const Duration(milliseconds: 20);
    _customTimers[id] = Timer(delay, () {
      _customTimers.remove(id);
      _onData();
    });
  }

  void _scheduleCustomRetry(int id) {
    _cancelCustomTimer(id);
    _customTimers[id] = Timer(const Duration(seconds: 1), () {
      _customTimers.remove(id);
      _onData();
    });
  }

  void _cancelCustomTimer(int id) => _customTimers.remove(id)?.cancel();

  void _resetCustomRules() {
    for (final state in _customStates.values) {
      state.trigger.reset();
    }
    for (final timer in _customTimers.values) {
      timer.cancel();
    }
    _customTimers.clear();
  }

  /// Starts a new record comparison: against nothing (flight scope) or the
  /// highest logged altitude (all flights), optionally including the
  /// altitude already reached in the current flight.
  void _resetRecord({required bool includeCurrentFlight}) {
    var baseline = double.negativeInfinity;
    if (_settings.recordScope == AltitudeRecordScope.allFlights) {
      for (final track in _recorder.tracks) {
        if (track.pointCount > 0 && track.maxAltitude > baseline) {
          baseline = track.maxAltitude;
        }
      }
    }
    if (includeCurrentFlight &&
        _flightMaxAltitude.isFinite &&
        _flightMaxAltitude > baseline) {
      baseline = _flightMaxAltitude;
    }
    _record.reset(baseline: baseline);
    _cancelTimer(AnnouncementEvent.altitudeRecord);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _hasAltitude(FlightData data) =>
      (data.hasFix || data.baroAltitude != null) && data.altitude.isFinite;

  void _rearmAfterFailure(DwellTrigger trigger, bool spoken) {
    // A failed attempt (engine still binding, busy, transient error) is
    // retried while the condition persists, unless speech is unavailable.
    if (!spoken && _speaker.availability != SpeechAvailability.unavailable) {
      trigger.rearm();
    }
  }

  /// Re-evaluates after [left] even if no new sample arrives; null cancels.
  /// Nothing is scheduled for a zero delay (the announcement is only blocked
  /// by one in progress), the next sample takes care of it.
  void _scheduleRecheckIn(AnnouncementEvent event, Duration? left) {
    if (left == null) {
      _cancelTimer(event);
      return;
    }
    if (left == Duration.zero || _timers.containsKey(event)) return;
    _timers[event] = Timer(left + const Duration(milliseconds: 20), () {
      _timers.remove(event);
      _onData();
    });
  }

  void _cancelTimer(AnnouncementEvent event) => _timers.remove(event)?.cancel();

  void _resetDwell(AnnouncementEvent event, DwellTrigger trigger) {
    _cancelTimer(event);
    trigger.reset();
  }

  AnnouncementValues _valuesFor(FlightData data, {FlightTrack? track}) {
    final flightTrack = track ?? _recorder.currentTrack;
    final altitude = data.altitude;
    final terrain = data.terrainElevationM;
    final takeoffAltitude =
        TakeoffReference.instance.point?.altitude ??
        flightTrack?.takeoffAltitude;
    var maxAltitude = _flightMaxAltitude;
    if (!maxAltitude.isFinite &&
        flightTrack != null &&
        flightTrack.pointCount > 0) {
      maxAltitude = flightTrack.maxAltitude;
    }
    return AnnouncementValues(
      altitudeMeters: altitude,
      climbMetersPerSecond: data.verticalSpeed,
      groundSpeedKmh:
          data.hasGroundSpeed &&
              data.groundSpeed.isFinite &&
              data.groundSpeed >= 0
          ? data.groundSpeed
          : double.nan,
      heightAboveGroundMeters: terrain != null
          ? altitude - terrain
          : double.nan,
      heightAboveTakeoffMeters: takeoffAltitude != null
          ? altitude - takeoffAltitude
          : double.nan,
      maxAltitudeMeters: maxAltitude,
      distanceMeters: flightTrack?.distanceM ?? double.nan,
      windSpeedKmh: data.windSpeed,
      flightDuration:
          flightTrack?.duration ??
          (_flightState.isFlying ? _flightState.elapsed : null),
      clockTime: DateTime.now(),
    );
  }

  bool _maySpeak(AnnouncementEvent event) {
    if (!_settings.announcementsEnabled) return false;
    final eventEnabled = switch (event) {
      AnnouncementEvent.takeoff ||
      AnnouncementEvent.continueFlight ||
      AnnouncementEvent.landing => _settings.takeoffLandingEnabled,
      AnnouncementEvent.glide => _settings.glideEnabled,
      AnnouncementEvent.altitudeRecord => _settings.recordEnabled,
    };
    return eventEnabled && (event.isFlightTransition || _flightState.isFlying);
  }

  Future<void> _announce(
    AnnouncementEvent event,
    AnnouncementValues values, {
    bool waitIfBusy = false,
    void Function(bool spoken)? onDone,
  }) async {
    if (!_maySpeak(event) || _inProgress.contains(event)) return;
    _inProgress.add(event);
    var spoken = false;
    try {
      spoken = await speakAnnouncement(
        event,
        values,
        speaker: _speaker,
        settings: _settings,
        waitIfBusy: waitIfBusy,
        busyTimeout: _transitionBusyTimeout,
        chime: event.isFlightTransition ? _chime : null,
        canSpeak: () => _maySpeak(event),
      );
    } catch (_) {
      // Never let speech problems interrupt flight-data processing.
    } finally {
      _inProgress.remove(event);
    }
    if (_attached) onDone?.call(spoken);
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final timer in _customTimers.values) {
      timer.cancel();
    }
    _customTimers.clear();
    _customStates.clear();
    unawaited(_transitionSubscription?.cancel());
    _transitionSubscription = null;
    _flightState.removeListener(_onFlightStateChanged);
    source.removeListener(_onData);
    _settings.removeListener(_onSettingsChanged);
    _ducking.dispose();
    unawaited(_speaker.stop());
  }
}

class _CustomAnnouncementState {
  _CustomAnnouncementState(this.rule);

  CustomAnnouncementRule rule;
  final ConditionRepeatTrigger trigger = ConditionRepeatTrigger();

  bool hasSameTriggerConfig(CustomAnnouncementRule other) =>
      rule.metric == other.metric &&
      rule.condition == other.condition &&
      rule.threshold == other.threshold &&
      rule.upperThreshold == other.upperThreshold &&
      rule.repeatSeconds == other.repeatSeconds &&
      rule.enabled == other.enabled;
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

/// Renders the announcement text of [event] the way it will be spoken for
/// [template] (`null` = built-in default) and [language].
String renderAnnouncement(
  AnnouncementEvent event,
  String? template,
  AnnouncementLanguage language,
  AnnouncementValues values,
) {
  return AnnouncementTemplate.render(
    template ?? AnnouncementTemplate.defaultFor(language, event),
    language,
    values,
  );
}

/// Plays the notification ding that precedes takeoff / landing
/// announcements.
Future<void> playAnnouncementChime() => VarioAudioService.instance.playChime();

/// Speaks [values] using the configured template of [event]; [chime] is
/// played right before the voice.
Future<bool> speakAnnouncement(
  AnnouncementEvent event,
  AnnouncementValues values, {
  AltitudeAnnouncementSpeaker? speaker,
  AltitudeAnnouncementSettings? settings,
  bool waitIfBusy = false,
  Duration busyTimeout = const Duration(seconds: 45),
  Future<void> Function()? chime,
  bool Function()? canSpeak,
}) {
  final resolved = settings ?? AltitudeAnnouncementSettings.instance;
  final template = resolved.templateFor(event);
  return (speaker ?? AltitudeAnnouncementSpeaker.instance).speak(
    preferred: announcementLanguageFor(template),
    waitIfBusy: waitIfBusy,
    busyTimeout: busyTimeout,
    rate: resolved.speechRate,
    volume: resolved.volume,
    prelude: chime,
    canSpeak: canSpeak,
    phraseFor: (language) =>
        renderAnnouncement(event, template, language, values),
  );
}

/// Speaks the configured text of [event] with sample values (including the
/// ding for takeoff / landing) so the user can hear how it sounds.
Future<bool> speakAnnouncementTest(AnnouncementEvent event) {
  return speakAnnouncement(
    event,
    AnnouncementValues.sampleFor(event),
    waitIfBusy: true,
    chime: event.isFlightTransition ? playAnnouncementChime : null,
  );
}
