import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveTrackingSettings extends ChangeNotifier {
  LiveTrackingSettings._();

  static final LiveTrackingSettings instance = LiveTrackingSettings._();

  static const _kLegacyEnabled = 'Livetrack.Enabled';
  static const _kXContestEnabled = 'Livetrack.XContestEnabled';
  static const _kParaBeaconEnabled = 'Livetrack.ParaBeaconEnabled';
  static const _kDestinationSelectionMade =
      'Livetrack.DestinationSelectionMade';
  static const _kDestinationMigrationComplete =
      'Livetrack.DestinationMigrationComplete';
  static const _kClaimContest = 'Livetrack.ClaimContest';
  static const _kShowPublic = 'Livetrack.ShowPublic';
  static const _kFlightPublic = 'Livetrack.FlightPublic';
  static const _kShareLocationPublicly = 'ParaBeacon.ShareLocationPublicly';
  static const _kShareLocationWhileNotFlying =
      'ParaBeacon.ShareLocationWhileNotFlying';
  static const _kTemporaryDontShare = 'Internal.LiveTempDontShare';
  static const _kReportSimulatedAsReal = 'Internal.LiveReportSimulatedAsReal';

  bool _xcontestEnabled = false;
  bool _parabeaconEnabled = false;
  bool _destinationSelectionMade = false;
  bool _claimContest = true;
  bool _showPublic = true;
  bool _flightPublic = true;
  bool _shareLocationPublicly = false;
  bool _shareLocationWhileNotFlying = false;
  bool _temporaryDontShare = false;
  bool _reportSimulatedAsReal = false;
  bool _loaded = false;
  bool _saving = false;

  bool get xcontestEnabled => _xcontestEnabled;
  bool get parabeaconEnabled => _parabeaconEnabled;
  bool get hasExplicitDestinationSelection => _destinationSelectionMade;
  bool get claimContest => _claimContest;
  bool get showPublic => _showPublic;
  bool get flightPublic => _flightPublic;
  bool get shareLocationPublicly => _shareLocationPublicly;
  bool get shareLocationWhileNotFlying => _shareLocationWhileNotFlying;
  bool get temporaryDontShare => _temporaryDontShare;

  /// Debug-only: when on, a simulated/mock feed is uploaded WITHOUT the
  /// `simulation` flag, so XContest treats it as a real flight. Always `false`
  /// in release builds - real users can never mislabel a mock feed as real.
  bool get reportSimulatedAsReal =>
      kReleaseMode ? false : _reportSimulatedAsReal;
  bool get isLoaded => _loaded;
  bool get isSaving => _saving;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final migrationComplete =
          preferences.getBool(_kDestinationMigrationComplete) ?? false;
      if (migrationComplete) {
        _xcontestEnabled =
            preferences.getBool(_kXContestEnabled) ?? _xcontestEnabled;
        _parabeaconEnabled =
            preferences.getBool(_kParaBeaconEnabled) ?? _parabeaconEnabled;
        _destinationSelectionMade =
            preferences.getBool(_kDestinationSelectionMade) ?? false;
      } else {
        final legacyEnabled = preferences.getBool(_kLegacyEnabled) ?? false;
        _xcontestEnabled = legacyEnabled
            ? preferences.getBool(_kXContestEnabled) ?? true
            : false;
        _parabeaconEnabled = legacyEnabled
            ? preferences.getBool(_kParaBeaconEnabled) ?? true
            : false;
        _destinationSelectionMade = legacyEnabled;
        await preferences.setBool(_kXContestEnabled, _xcontestEnabled);
        await preferences.setBool(_kParaBeaconEnabled, _parabeaconEnabled);
        await preferences.setBool(
          _kDestinationSelectionMade,
          _destinationSelectionMade,
        );
        await preferences.setBool(_kDestinationMigrationComplete, true);
        await preferences.remove(_kLegacyEnabled);
      }
      _claimContest = preferences.getBool(_kClaimContest) ?? _claimContest;
      _showPublic = preferences.getBool(_kShowPublic) ?? _showPublic;
      _flightPublic = preferences.getBool(_kFlightPublic) ?? _flightPublic;
      _shareLocationPublicly =
          preferences.getBool(_kShareLocationPublicly) ??
          _shareLocationPublicly;
      _shareLocationWhileNotFlying =
          preferences.getBool(_kShareLocationWhileNotFlying) ?? false;
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
    bool? shareLocationWhileNotFlying,
    required bool xcontestEnabled,
    required bool parabeaconEnabled,
    required bool claimContest,
    required bool showPublic,
    required bool flightPublic,
    required bool shareLocationPublicly,
    required bool temporaryDontShare,
    bool? reportSimulatedAsReal,
  }) async {
    _xcontestEnabled = xcontestEnabled;
    _parabeaconEnabled = parabeaconEnabled;
    _destinationSelectionMade = true;
    _claimContest = claimContest;
    _showPublic = showPublic;
    _flightPublic = flightPublic;
    _shareLocationPublicly = shareLocationPublicly;
    if (shareLocationWhileNotFlying != null) {
      _shareLocationWhileNotFlying = shareLocationWhileNotFlying;
    }
    _temporaryDontShare = temporaryDontShare;
    if (reportSimulatedAsReal != null) {
      _reportSimulatedAsReal = reportSimulatedAsReal;
    }
    _saving = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kXContestEnabled, _xcontestEnabled);
      await preferences.setBool(_kParaBeaconEnabled, _parabeaconEnabled);
      await preferences.setBool(_kDestinationSelectionMade, true);
      await preferences.setBool(_kDestinationMigrationComplete, true);
      await preferences.setBool(_kClaimContest, _claimContest);
      await preferences.setBool(_kShowPublic, _showPublic);
      await preferences.setBool(_kFlightPublic, _flightPublic);
      await preferences.setBool(
        _kShareLocationPublicly,
        _shareLocationPublicly,
      );
      await preferences.setBool(
        _kShareLocationWhileNotFlying,
        _shareLocationWhileNotFlying,
      );
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

  /// Immediately applies and persists the XContest destination selection.
  Future<void> setXContestEnabled(bool value) async {
    if (_xcontestEnabled == value && _destinationSelectionMade) return;
    _xcontestEnabled = value;
    _destinationSelectionMade = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kXContestEnabled, _xcontestEnabled);
      await preferences.setBool(_kParaBeaconEnabled, _parabeaconEnabled);
      await preferences.setBool(_kDestinationSelectionMade, true);
      await preferences.setBool(_kDestinationMigrationComplete, true);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
    }
  }

  /// Immediately applies and persists the ParaBeacon destination selection.
  Future<void> setParaBeaconEnabled(bool value) async {
    if (_parabeaconEnabled == value && _destinationSelectionMade) return;
    _parabeaconEnabled = value;
    _destinationSelectionMade = true;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kXContestEnabled, _xcontestEnabled);
      await preferences.setBool(_kParaBeaconEnabled, _parabeaconEnabled);
      await preferences.setBool(_kDestinationSelectionMade, true);
      await preferences.setBool(_kDestinationMigrationComplete, true);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
    }
  }

  /// Immediately applies and persists "Show public tracking", independent of
  /// the Save button. The live service hot-updates `xcSetOptions` mid-flight
  /// from this, so other pilots start/stop appearing on the map at once.
  Future<void> setShowPublic(bool value) async {
    if (_showPublic == value) return;
    _showPublic = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kShowPublic, value);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
    }
  }

  /// Immediately applies and persists the ParaBeacon public-location consent.
  Future<void> setShareLocationPublicly(bool value) async {
    if (_shareLocationPublicly == value) return;
    _shareLocationPublicly = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kShareLocationPublicly, value);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
    }
  }

  /// Immediately applies and persists consent to share location while grounded.
  Future<void> setShareLocationWhileNotFlying(bool value) async {
    if (_shareLocationWhileNotFlying == value) return;
    _shareLocationWhileNotFlying = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_kShareLocationWhileNotFlying, value);
    } catch (_) {
      // In-memory value still applies; persistence can retry later.
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
