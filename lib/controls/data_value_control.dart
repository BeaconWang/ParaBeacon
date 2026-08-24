import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';

/// Color state of a data value, mirroring XCTrack's value coloring.
enum ValueState { neutral, good, bad }

/// A generic "data control": a readout showing an optional title, a large
/// value, and a unit, colored by [ValueState].
///
/// This mirrors XCTrack's `ValueWidget` layout (title / value / units) used by
/// data widgets such as Vertical Speed, Ground Speed, Altitude, etc.
class DataValueControl extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final ValueState state;
  final bool showTitle;

  const DataValueControl({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.state = ValueState.neutral,
    this.showTitle = true,
  });

  Color _valueColor(ThemeData theme) {
    switch (state) {
      case ValueState.good:
        return const Color(0xFF4CD964); // climbing / positive
      case ValueState.bad:
        return const Color(0xFFFF6B6B); // sinking / negative
      case ValueState.neutral:
        return theme.colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the value font to the available space.
        final valueSize =
            (constraints.maxHeight * 0.42).clamp(16.0, 48.0).toDouble();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle)
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: _valueColor(theme),
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Vertical speed data control, inspired by XCTrack's `WVerticalSpeed`.
///
/// Displays vertical speed in m/s with color state: green when climbing
/// (>= 0), red when sinking hard (<= -1), neutral for gentle sink.
///
/// Reads from the unified [FlightDataProvider]. An optional [verticalSpeed]
/// override can be supplied (e.g. for tests/previews).
class VerticalSpeedControl extends StatelessWidget {
  /// Optional override for the vertical speed in m/s. When null the value is
  /// read from the shared flight-data source.
  final double? verticalSpeed;

  /// Whether to show the "Vertical Speed" title.
  final bool showTitle;

  const VerticalSpeedControl({
    super.key,
    this.verticalSpeed,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = verticalSpeed ?? FlightDataProvider.of(context).verticalSpeed;
    final ValueState state;
    if (v >= 0.0) {
      state = ValueState.good;
    } else if (v <= -1.0) {
      state = ValueState.bad;
    } else {
      state = ValueState.neutral;
    }
    return DataValueControl(
      title: 'Vertical Speed',
      value: '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
      unit: 'm/s',
      state: state,
      showTitle: showTitle,
    );
  }
}
