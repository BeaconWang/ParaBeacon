import 'dart:async';

import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';
import '../data/flight_state.dart';
import '../l10n/app_localizations.dart';

/// A widget control that starts/stops a flight.
///
/// All Flight buttons share the single [FlightState.instance], so tapping any
/// one of them toggles the same global flight session and every button (across
/// pages) updates in sync. While flying it shows the elapsed time and a "Stop"
/// affordance; when idle it shows "Start".
///
/// When [showAutoDetect] is true, a checkbox is shown to the left of the
/// button; ticking it enables system auto start/stop (take-off & landing
/// detection). That flag is also shared via [FlightState], so it stays in sync
/// across every Flight button that shows the checkbox.
class FlightButtonControl extends StatefulWidget {
  /// Whether the auto-detect checkbox is shown to the left of the button.
  final bool showAutoDetect;

  const FlightButtonControl({super.key, this.showAutoDetect = true});

  @override
  State<FlightButtonControl> createState() => _FlightButtonControlState();
}

class _FlightButtonControlState extends State<FlightButtonControl> {
  final FlightState _flight = FlightState.instance;

  /// Ticks once per second while flying so the elapsed-time label advances.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _flight.addListener(_onFlightChanged);
    _syncTicker();
  }

  @override
  void dispose() {
    _flight.removeListener(_onFlightChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onFlightChanged() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
  }

  /// Runs the 1 Hz ticker only while a flight is in progress.
  void _syncTicker() {
    if (_flight.isFlying) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final flying = _flight.isFlying;

    // Single unified pill: strong colored background, "onColor" foreground.
    final bgColor = flying ? theme.colorScheme.error : Colors.green.shade600;
    final fgColor = Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final base = constraints.biggest.shortestSide;
        final iconSize = (base * 0.30).clamp(16.0, 40.0).toDouble();
        final labelSize = (base * 0.15).clamp(11.0, 20.0).toDouble();
        final timeSize = (base * 0.12).clamp(10.0, 16.0).toDouble();

        return Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Left: integrated auto-detect badge, its own hit area, divided
              // from the main button by a subtle vertical rule.
              if (widget.showAutoDetect)
                _AutoDetectBadge(
                  enabled: _flight.autoDetect,
                  fgColor: fgColor,
                  onChanged: _flight.setAutoDetect,
                ),

              // Right: the main start/stop tap area.
              Expanded(
                child: InkWell(
                  onTap: _flight.toggle,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          flying
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                          size: iconSize,
                          color: fgColor,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flying ? l10n.flightButtonStop : l10n.flightButtonStart,
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: fgColor,
                          ),
                        ),
                        if (flying) ...[
                          const SizedBox(height: 2),
                          Text(
                            _fmtElapsed(_flight.elapsed),
                            style: TextStyle(
                              fontSize: timeSize,
                              color: fgColor.withAlpha(220),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          _RecordingReadout(
                            fgColor: fgColor,
                            fontSize: (timeSize * 0.85)
                                .clamp(8.0, 14.0)
                                .toDouble(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The integrated "auto detect take-off / landing" badge shown on the left of
/// the Flight button.
///
/// Matches the reference design: a flight icon + "AUTO" caps label above a
/// compact [Switch], its own tap area, separated from the main button by a
/// translucent vertical rule. Toggling flips the shared [FlightState.autoDetect]
/// flag so every visible badge stays in sync.
class _AutoDetectBadge extends StatelessWidget {
  final bool enabled;
  final Color fgColor;
  final ValueChanged<bool> onChanged;

  const _AutoDetectBadge({
    required this.enabled,
    required this.fgColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dim = fgColor.withAlpha(115);
    final labelColor = enabled ? fgColor : dim;

    return Tooltip(
      message: l10n.flightButtonAutoTooltip,
      child: InkWell(
        onTap: () => onChanged(!enabled),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: fgColor.withAlpha(64), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled ? Icons.flight_takeoff : Icons.flight,
                    color: labelColor,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    l10n.flightButtonAuto,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 9,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Compact switch scaled to fit within the button height.
              SizedBox(
                width: 36,
                height: 20,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: enabled,
                    onChanged: onChanged,
                    activeThumbColor: fgColor,
                    activeTrackColor: fgColor.withAlpha(140),
                    inactiveThumbColor: fgColor.withAlpha(180),
                    inactiveTrackColor: fgColor.withAlpha(40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny "● REC · N pts" readout backed by the [FlightRecorder]. Rebuilds as
/// samples are appended so the pilot can see recording is live and growing.
class _RecordingReadout extends StatelessWidget {
  final Color fgColor;
  final double fontSize;

  const _RecordingReadout({required this.fgColor, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recorder = FlightRecorder.instance;
    return AnimatedBuilder(
      animation: recorder,
      builder: (context, _) {
        if (!recorder.isRecording) return const SizedBox.shrink();
        final track = recorder.currentTrack!;
        final km = track.distanceM / 1000.0;
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record,
                  size: fontSize + 2, color: fgColor),
              const SizedBox(width: 3),
              Text(
                l10n.flightRecordingReadout(
                    track.pointCount, km.toStringAsFixed(1)),
                style: TextStyle(
                  fontSize: fontSize,
                  color: fgColor.withAlpha(230),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
