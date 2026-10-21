import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';
import '../data/flight_data_transformer.dart';
import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';
import 'decimal_places.dart';

/// Rolling 30-second climb average, peak, and recent vertical-speed bars.
class ClimbAvgControl extends StatefulWidget {
  const ClimbAvgControl({super.key});

  @override
  State<ClimbAvgControl> createState() => _ClimbAvgControlState();
}

class _ClimbAvgControlState extends State<ClimbAvgControl> {
  static const int _windowSize = 30;
  static const int _barCount = 7;
  static const int _barSeconds = 5;
  static const int _maxSamples = _windowSize + _barCount * _barSeconds;

  final List<double> _samples = <double>[];
  FlightDataTransformer? _transformer;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transformer = FlightDataProvider.transformerOf(context);
    if (!identical(_transformer, transformer)) {
      _transformer = transformer;
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _addSample(_transformer?.data.verticalSpeed ?? 0.0);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _addSample(double value) {
    if (!mounted) return;
    setState(() {
      _samples.add(value.isFinite ? value : 0.0);
      if (_samples.length > _maxSamples) _samples.removeAt(0);
    });
  }

  List<double> _recentSamples() {
    if (_samples.length <= _windowSize) return _samples;
    return _samples.sublist(_samples.length - _windowSize);
  }

  List<double> _barValues() {
    return List<double>.generate(_barCount, (index) {
      final end = _samples.length - (_barCount - 1 - index) * _barSeconds;
      final start = end - _barSeconds;
      if (start < 0 || end > _samples.length) return 0.0;
      final segment = _samples.sublist(start, end);
      if (segment.isEmpty) return 0.0;
      return segment.reduce((a, b) => a + b) / segment.length;
    });
  }

  String _formatValue(
    double value,
    String unit, {
    required bool signed,
    required DecimalPlaceRange? precision,
  }) {
    final converted = UnitValues.convert(
      value,
      UnitDimension.verticalSpeed,
      unit,
    );
    final decimals = unit == 'fpm' ? 0 : 1;
    final sign = signed && converted >= 0 ? '+' : '';
    return '$sign${formatDecimalValue(converted, autoDecimals: decimals, range: precision)}';
  }

  Color _barColor(double value, ColorScheme colors) {
    if (value >= 2.0) return colors.primaryContainer;
    if (value >= 0.5) return colors.secondaryContainer;
    if (value >= 0.0) return colors.outlineVariant;
    return colors.error.withAlpha(153);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final unit = selectedUnit(context, UnitDimension.verticalSpeed);
    final recent = _recentSamples();
    final average = recent.isEmpty
        ? 0.0
        : recent.fold<double>(0.0, (sum, value) => sum + value) / recent.length;
    final peak = recent.isEmpty ? 0.0 : recent.reduce((a, b) => a > b ? a : b);
    final bars = _barValues();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 160.0;
        final scale = (height / 160.0).clamp(0.55, 1.25).toDouble();
        final padding = (height * 0.075).clamp(4.0, 12.0).toDouble();
        final chartHeight = (height * 0.30).clamp(18.0, 48.0).toDouble();
        final sectionGap = (height * 0.05).clamp(3.0, 8.0).toDouble();
        final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          height: 1.1,
        );

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.climbAverageLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle,
                          ),
                          SizedBox(height: 3 * scale),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatValue(
                                        average,
                                        unit,
                                        signed: false,
                                        precision: DecimalPlacesScope.rangeOf(
                                          context,
                                          'averageDecimals',
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 40 * scale,
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4 * scale,
                                        bottom: 6 * scale,
                                      ),
                                      child: Text(
                                        UnitValues.symbol(
                                          UnitDimension.verticalSpeed,
                                          unit,
                                        ).toLowerCase(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12 * scale,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.peakLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle,
                          ),
                          SizedBox(height: 3 * scale),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _formatValue(
                                    peak,
                                    unit,
                                    signed: true,
                                    precision: DecimalPlacesScope.rangeOf(
                                      context,
                                      'peakDecimals',
                                    ),
                                  ),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: peak >= 0
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.error,
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((value) {
                    final normalized = ((value + 3.0) / 8.0).clamp(0.0, 1.0);
                    final barHeight = math.max(3.0, normalized * chartHeight);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: scale),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: barHeight,
                            width: double.infinity,
                            child: ColoredBox(
                              color: _barColor(value, theme.colorScheme),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
