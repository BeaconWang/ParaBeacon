import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/vario_audio_service.dart';
import '../audio/vario_sound_settings.dart';

enum _CustomMetric { frequency, cycle, duty }

class VarioSoundCustomizationPage extends StatefulWidget {
  const VarioSoundCustomizationPage({super.key});

  @override
  State<VarioSoundCustomizationPage> createState() =>
      _VarioSoundCustomizationPageState();
}

class _VarioSoundCustomizationPageState
    extends State<VarioSoundCustomizationPage> {
  final VarioSoundSettings _settings = VarioSoundSettings.instance;
  final VarioAudioService _audio = VarioAudioService.instance;

  _CustomMetric _metric = _CustomMetric.frequency;
  double _previewSpeed = 1.0;
  bool _previewMuted = false;

  @override
  void initState() {
    super.initState();
    _previewMuted = _audio.isPreviewMuted;
    _audio.setPreviewSpeed(_previewSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speeds = VarioSoundSettings.customSoundSpeeds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound customization'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            final values = _valuesForMetric(_metric);
            final range = _rangeForMetric(_metric);
            final unit = _unitForMetric(_metric);

            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 108,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _metricRail(theme),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: 8),
                              RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  unit,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...List.generate(speeds.length, (i) {
                                return _BarEditorCell(
                                  speedLabel: _speedLabel(speeds[i]),
                                  valueLabel:
                                      _valueLabel(_metric, values[i]).split(' ').first,
                                  value: values[i],
                                  min: range.$1,
                                  max: range.$2,
                                  onChanged: (v) => _setValueAt(_metric, i, v),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: _previewMuted ? 'Unmute preview' : 'Mute preview',
                        onPressed: () {
                          setState(() => _previewMuted = !_previewMuted);
                          _audio.setPreviewMuted(_previewMuted);
                        },
                        icon: Icon(
                          _previewMuted ? Icons.volume_off : Icons.volume_up,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Preview vertical speed',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  '${_previewSpeed.toStringAsFixed(2)} m/s',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _previewSpeed,
                              min: -7,
                              max: 7,
                              divisions: 56,
                              onChanged: (v) {
                                setState(() => _previewSpeed = v);
                                _audio.setPreviewSpeed(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metricRail(ThemeData theme) {
    Widget item({
      required IconData icon,
      required String label,
      required _CustomMetric metric,
    }) {
      final selected = _metric == metric;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _metric = metric),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        item(
          icon: Icons.graphic_eq,
          label: 'Frequency',
          metric: _CustomMetric.frequency,
        ),
        item(
          icon: Icons.data_thresholding,
          label: 'Cycle',
          metric: _CustomMetric.cycle,
        ),
        item(
          icon: Icons.tune,
          label: 'Duty',
          metric: _CustomMetric.duty,
        ),
        const Spacer(),
      ],
    );
  }

  List<double> _valuesForMetric(_CustomMetric metric) {
    switch (metric) {
      case _CustomMetric.frequency:
        return _settings.customFreqHz;
      case _CustomMetric.cycle:
        return _settings.customCycleMs;
      case _CustomMetric.duty:
        return _settings.customDutyPct;
    }
  }

  (double, double) _rangeForMetric(_CustomMetric metric) {
    switch (metric) {
      case _CustomMetric.frequency:
        return (100, 1500);
      case _CustomMetric.cycle:
        return (100, 1000);
      case _CustomMetric.duty:
        return (10, 100);
    }
  }

  String _unitForMetric(_CustomMetric metric) {
    switch (metric) {
      case _CustomMetric.frequency:
        return 'Hz';
      case _CustomMetric.cycle:
        return 'ms';
      case _CustomMetric.duty:
        return '%';
    }
  }

  String _valueLabel(_CustomMetric metric, double v) {
    switch (metric) {
      case _CustomMetric.frequency:
        return '${v.round()} Hz';
      case _CustomMetric.cycle:
        return '${v.round()} ms';
      case _CustomMetric.duty:
        return '${v.round()} %';
    }
  }

  void _setValueAt(_CustomMetric metric, int index, double value) {
    switch (metric) {
      case _CustomMetric.frequency:
        _settings.setCustomFrequencyAt(index, value);
        return;
      case _CustomMetric.cycle:
        _settings.setCustomCycleAt(index, value);
        return;
      case _CustomMetric.duty:
        _settings.setCustomDutyAt(index, value);
        return;
    }
  }

  String _speedLabel(double v) {
    if ((v - v.round()).abs() < 0.001) return v.round().toString();
    return v.toStringAsFixed(v.abs() < 1 ? 2 : 1);
  }
}

class _BarEditorCell extends StatelessWidget {
  const _BarEditorCell({
    required this.speedLabel,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String speedLabel;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 44,
        child: Column(
          children: [
            Text(
              valueLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final barHeight = math.max(2.0, c.maxHeight * ratio);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (d) {
                      final deltaRatio = -d.delta.dy / c.maxHeight;
                      final next = value + deltaRatio * (max - min);
                      onChanged(next.clamp(min, max));
                    },
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          curve: Curves.linear,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              speedLabel,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
