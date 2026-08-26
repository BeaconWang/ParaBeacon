import 'dart:async';

import 'package:flutter/material.dart';

import '../data/flight_state.dart';

/// A widget control that starts/stops a flight.
///
/// All Flight buttons share the single [FlightState.instance], so tapping any
/// one of them toggles the same global flight session and every button (across
/// pages) updates in sync. While flying it shows the elapsed time and a "Stop"
/// affordance; when idle it shows "Start".
class FlightButtonControl extends StatefulWidget {
  const FlightButtonControl({super.key});

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
    final flying = _flight.isFlying;

    final color = flying ? theme.colorScheme.error : Colors.green.shade600;
    final onColor = Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final base = constraints.biggest.shortestSide;
        final iconSize = (base * 0.34).clamp(18.0, 48.0).toDouble();
        final labelSize = (base * 0.16).clamp(11.0, 22.0).toDouble();
        final timeSize = (base * 0.13).clamp(10.0, 18.0).toDouble();

        return Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _flight.toggle,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    flying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    size: iconSize,
                    color: onColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    flying ? 'Stop' : 'Start',
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: FontWeight.bold,
                      color: onColor,
                    ),
                  ),
                  if (flying) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtElapsed(_flight.elapsed),
                      style: TextStyle(
                        fontSize: timeSize,
                        color: onColor.withAlpha(220),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
