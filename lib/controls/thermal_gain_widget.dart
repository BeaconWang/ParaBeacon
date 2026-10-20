import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/flight_data_transformer.dart';
import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';
import 'data_value_control.dart';

/// Tracks altitude gained during one thermal.
///
/// Feed each altitude/variometer sample to [addSample]. When [isThermalling]
/// is omitted, the tracker enters at [entryThresholdMps] and exits at
/// [exitThresholdMps]. Supplying a thermal-state value overrides that
/// automatic threshold detection for the sample.
class ThermalGainTracker extends ChangeNotifier {
  ThermalGainTracker({
    this.entryThresholdMps = 0.5,
    this.exitThresholdMps = 0.1,
  }) : assert(entryThresholdMps.isFinite),
       assert(exitThresholdMps.isFinite),
       assert(exitThresholdMps <= entryThresholdMps);

  /// Minimum climb rate that starts a thermal when no explicit state is given.
  final double entryThresholdMps;

  /// Climb rate at or below which a detected thermal ends.
  final double exitThresholdMps;

  bool _isActive = false;
  double? _entryAltitudeM;
  double? _currentGainM;
  double? _lastGainM;

  bool get isActive => _isActive;
  double? get entryAltitudeM => _entryAltitudeM;
  double? get currentGainM => _currentGainM;
  double? get lastGainM => _lastGainM;

  /// Ingests one altitude in meters and climb rate in meters per second.
  void addSample({
    required double altitudeM,
    required double climbRateMps,
    bool? isThermalling,
  }) {
    if (!altitudeM.isFinite || !climbRateMps.isFinite) return;

    if (_isActive) {
      final shouldExit =
          isThermalling == false ||
          (isThermalling == null && climbRateMps <= exitThresholdMps);
      if (shouldExit) {
        _lastGainM = altitudeM - (_entryAltitudeM ?? altitudeM);
        _isActive = false;
        _entryAltitudeM = null;
        _currentGainM = null;
        notifyListeners();
        return;
      }

      final gain = altitudeM - (_entryAltitudeM ?? altitudeM);
      if (_currentGainM != gain) {
        _currentGainM = gain;
        notifyListeners();
      }
      return;
    }

    final shouldEnter =
        isThermalling == true ||
        (isThermalling == null && climbRateMps >= entryThresholdMps);
    if (!shouldEnter) return;

    _isActive = true;
    _entryAltitudeM = altitudeM;
    _currentGainM = 0;
    notifyListeners();
  }

  /// Ends the active thermal while retaining its last measured gain.
  void finishThermal() {
    if (!_isActive) return;
    _lastGainM = _currentGainM ?? 0;
    _isActive = false;
    _entryAltitudeM = null;
    _currentGainM = null;
    notifyListeners();
  }

  /// Clears both the active thermal and the stored last-thermal value.
  void reset() {
    if (!_isActive &&
        _entryAltitudeM == null &&
        _currentGainM == null &&
        _lastGainM == null) {
      return;
    }
    _isActive = false;
    _entryAltitudeM = null;
    _currentGainM = null;
    _lastGainM = null;
    notifyListeners();
  }
}

/// Live thermal-gain dashboard control, powered by [FlightDataProvider].
///
/// It reads effective altitude and vertical speed from the shared flight-data
/// stream. An optional [thermalState] can be supplied by an app-level thermal
/// detector; otherwise climb-rate thresholds are used with hysteresis.
class ThermalGainWidget extends StatefulWidget {
  const ThermalGainWidget({
    super.key,
    this.showTitle = true,
    this.entryThresholdMps = 0.5,
    this.exitThresholdMps = 0.1,
    this.thermalState,
  }) : assert(exitThresholdMps <= entryThresholdMps);

  final bool showTitle;
  final double entryThresholdMps;
  final double exitThresholdMps;

  /// Optional externally detected thermal state. If provided, it takes
  /// precedence over the climb-rate thresholds.
  final ValueListenable<bool>? thermalState;

  @override
  State<ThermalGainWidget> createState() => _ThermalGainWidgetState();
}

class _ThermalGainWidgetState extends State<ThermalGainWidget> {
  late ThermalGainTracker _tracker;
  FlightDataTransformer? _transformer;

  @override
  void initState() {
    super.initState();
    _tracker = _createTracker();
    widget.thermalState?.addListener(_onThermalStateChanged);
  }

  ThermalGainTracker _createTracker() => ThermalGainTracker(
    entryThresholdMps: widget.entryThresholdMps,
    exitThresholdMps: widget.exitThresholdMps,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transformer = FlightDataProvider.transformerOf(context);
    if (!identical(transformer, _transformer)) {
      _transformer?.removeListener(_onFlightDataChanged);
      _transformer = transformer;
      transformer.addListener(_onFlightDataChanged);
      _consume(transformer.data);
    }
  }

  @override
  void didUpdateWidget(covariant ThermalGainWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thermalState != widget.thermalState) {
      oldWidget.thermalState?.removeListener(_onThermalStateChanged);
      widget.thermalState?.addListener(_onThermalStateChanged);
    }
    if (oldWidget.entryThresholdMps != widget.entryThresholdMps ||
        oldWidget.exitThresholdMps != widget.exitThresholdMps) {
      _tracker.dispose();
      _tracker = _createTracker();
      final transformer = _transformer;
      if (transformer != null) _consume(transformer.data);
    }
  }

  void _onFlightDataChanged() {
    final transformer = _transformer;
    if (transformer != null) _consume(transformer.data);
  }

  void _onThermalStateChanged() {
    final transformer = _transformer;
    if (transformer != null) _consume(transformer.data);
  }

  void _consume(FlightData data) {
    if (!(data.hasFix || data.baroAltitude != null) ||
        !data.altitude.isFinite) {
      return;
    }
    _tracker.addSample(
      altitudeM: data.altitude,
      climbRateMps: data.verticalSpeed,
      isThermalling: widget.thermalState?.value,
    );
  }

  @override
  void dispose() {
    _transformer?.removeListener(_onFlightDataChanged);
    widget.thermalState?.removeListener(_onThermalStateChanged);
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThermalGainReadout(tracker: _tracker, showTitle: widget.showTitle);
  }
}

/// XCTrack-style high-contrast readout for a [ThermalGainTracker].
class ThermalGainReadout extends StatelessWidget {
  const ThermalGainReadout({
    super.key,
    required this.tracker,
    this.showTitle = true,
  });

  final ThermalGainTracker tracker;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        final isActive = tracker.isActive;
        final gain = isActive ? tracker.currentGainM : tracker.lastGainM;
        final altitudeUnit = selectedUnit(context, UnitDimension.altitude);
        return DataValueControl(
          title: isActive
              ? AppLocalizations.of(context).controlThermalGain
              : gain == null
              ? AppLocalizations.of(context).controlThermalGain
              : AppLocalizations.of(context).controlLastThermalGain,
          value: gain == null
              ? '--'
              : UnitValues.formatAltitudeDifference(gain, altitudeUnit),
          unit: UnitValues.symbol(UnitDimension.altitude, altitudeUnit),
          state: isActive && (gain ?? 0) >= 0
              ? ValueState.good
              : ValueState.neutral,
          showTitle: showTitle,
        );
      },
    );
  }
}
