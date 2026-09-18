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

  bool _enabled = false;
  bool _claimContest = true;
  bool _showPublic = true;
  bool _flightPublic = true;
  bool _temporaryDontShare = false;
  bool _loaded = false;
  bool _saving = false;

  bool get enabled => _enabled;
  bool get claimContest => _claimContest;
  bool get showPublic => _showPublic;
  bool get flightPublic => _flightPublic;
  bool get temporaryDontShare => _temporaryDontShare;
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
  }) async {
    _enabled = enabled;
    _claimContest = claimContest;
    _showPublic = showPublic;
    _flightPublic = flightPublic;
    _temporaryDontShare = temporaryDontShare;
    _saving = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kEnabled, _enabled);
      await preferences.setBool(_kClaimContest, _claimContest);
      await preferences.setBool(_kShowPublic, _showPublic);
      await preferences.setBool(_kFlightPublic, _flightPublic);
      await preferences.setBool(_kTemporaryDontShare, _temporaryDontShare);
    } catch (_) {
      // Keep the in-memory values and allow a later save to retry.
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
