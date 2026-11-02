import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveTrackingSettings extends ChangeNotifier {
  LiveTrackingSettings._();

  static final LiveTrackingSettings instance = LiveTrackingSettings._();

  static const _kEnabled = 'Livetrack.Enabled';
  static const _kClaimContest = 'Livetrack.ClaimContest';
  static const _kShowPublic = 'Livetrack.ShowPublic';
  static const _kFlightPublic = 'Livetrack.FlightPublic';
  static const _kTemporaryDontShare = 'Internal.LiveTempDontShare';
  static const _kReportSimulatedAsReal =
      'Internal.LiveReportSimulatedAsReal';

  bool _enabled = false;
  bool _claimContest = true;
  bool _showPublic = true;
  bool _flightPublic = true;
  bool _temporaryDontShare = false;
  bool _reportSimulatedAsReal = false;
  bool _loaded = false;
  bool _saving = false;

  bool get enabled => _enabled;
  bool get claimContest => _claimContest;
  bool get showPublic => _showPublic;
  bool get flightPublic => _flightPublic;
  bool get temporaryDontShare => _temporaryDontShare;

  /// Debug-only: when on, a simulated/mock feed is uploaded WITHOUT the
  /// `simulation` flag, so XContest treats it as a real flight. Always `false`
  /// in release builds - real users can never mislabel a mock feed as real.
  bool get reportSimulatedAsReal =>
      kReleaseMode ? false : _reportSimulatedAsReal;
  bool get isLoaded => _loaded;
  bool get isSaving => _saving;
  bool get isEffectivelyEnabled => _enabled && !_temporaryDontShare;

  String get statusKey {
    if (_temporaryDontShare) return 'temporarilyDisabled';
    if (_enabled) return 'enabled';
    return 'disabled';
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _enabled = preferences.getBool(_kEnabled) ?? _enabled;
      _claimContest = preferences.getBool(_kClaimContest) ?? _claimContest;
      _showPublic = preferences.getBool(_kShowPublic) ?? _showPublic;
      _flightPublic = preferences.getBool(_kFlightPublic) ?? _flightPublic;
      _temporaryDontShare =
          preferences.getBool(_kTemporaryDontShare) ?? _temporaryDontShare;
      _reportSimulatedAsReal =
          preferences.getBool(_kReportSimulatedAsReal) ??
          _reportSimulatedAsReal;
    } catch (_) {
      // Keep defaults if local storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> save({
    required bool enabled,
    required bool claimContest,
    required bool showPublic,
    required bool flightPublic,
    required bool temporaryDontShare,
    bool? reportSimulatedAsReal,
  }) async {
    _enabled = enabled;
    _claimContest = claimContest;
    _showPublic = showPublic;
    _flightPublic = flightPublic;
    _temporaryDontShare = temporaryDontShare;
    if (reportSimulatedAsReal != null) {
      _reportSimulatedAsReal = reportSimulatedAsReal;
    }
    _saving = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kEnabled, _enabled);
      await preferences.setBool(_kClaimContest, _claimContest);
      await preferences.setBool(_kShowPublic, _showPublic);
      await preferences.setBool(_kFlightPublic, _flightPublic);
      await preferences.setBool(_kTemporaryDontShare, _temporaryDontShare);
      await preferences.setBool(
        _kReportSimulatedAsReal,
        _reportSimulatedAsReal,
      );
    } catch (_) {
      // Keep the in-memory values and allow a later save to retry.
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Immediately applies and persists the "Temporarily stop sharing" pause,
  /// independent of the Save button. The live-tracking service reads this per
  /// fix, so the pause/resume takes effect at once (XCTrack reads its
  /// `Internal.LiveTempDontShare` config live). Does not touch other settings.
  Future<void> setTemporaryDontShare(bool value) async {
    if (_temporaryDontShare == value) return;
    _temporaryDontShare = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kTemporaryDontShare, value);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
    }
  }
}
