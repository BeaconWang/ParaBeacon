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
  late final bool _wasCustomEnabled;


  @override
  void initState() {
    super.initState();
    _wasCustomEnabled = _settings.customSoundEnabled;
    if (!_wasCustomEnabled) {
      _settings.setCustomSoundEnabled(true);
    }
    _audio.beginPreview(_previewSpeed);
    _previewMuted = _audio.isPreviewMuted;
  }

  @override
  void dispose() {
    _audio.endPreview();
    if (!_wasCustomEnabled) {
      _settings.setCustomSoundEnabled(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound customization'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shouldRotate = constraints.maxWidth < constraints.maxHeight;
            return AnimatedBuilder(
              animation: _settings,
              builder: (context, _) {
                if (!shouldRotate) {
                  return _responsiveBody(
                    theme,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                }

                final contentWidth = constraints.maxHeight;
                final contentHeight = constraints.maxWidth;

                return SizedBox.expand(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: SizedBox(
                      width: contentWidth,
                      height: contentHeight,
                      child: _responsiveBody(
                        theme,
                        width: contentWidth,
                        height: contentHeight,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _responsiveBody(
    ThemeData theme, {
    required double width,
    required double height,
  }) {
    final compact = width < 760;
    final compactPreview = width < 560 || height < 420;

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey<bool>(compact),
              child: _mainEditor(theme, compact: compact),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey<bool>(compactPreview),
            child: _previewControls(
              theme,
              compact: compactPreview,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mainEditor(ThemeData theme, {required bool compact}) {
    if (compact) {
      return Column(
        key: const ValueKey<String>('compact-main-editor'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: _metricSelectorCompact(theme),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _barEditor(
                theme,
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey<String>('regular-main-editor'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final railWidth = constraints.maxWidth < 900 ? 92.0 : 108.0;
            return SizedBox(
              width: railWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: _metricSelectorRail(theme)),
              ),
            );
          },
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => _barEditor(
              theme,
              viewportWidth: constraints.maxWidth,
              viewportHeight: constraints.maxHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _barEditor(
    ThemeData theme, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final speeds = VarioSoundSettings.customSoundSpeeds;
    final values = _valuesForMetric(_metric);
    final range = _rangeForMetric(_metric);
    final unit = _unitForMetric(_metric);
    final compact = viewportWidth < 560 || viewportHeight < 340;
    const sideWidth = 24.0;
    final horizontalPadding = compact ? 4.0 : 8.0;
    final usable = math.max(
      80.0,
      viewportWidth - sideWidth - horizontalPadding * 2,
    );
    final slotWidth = math.max(12.0, usable / speeds.length);
    final barWidth = (slotWidth * (compact ? 0.72 : 0.78)).clamp(8.0, 38.0);
    final labelStep = slotWidth < 16
        ? 4
        : (slotWidth < 24 ? 3 : (slotWidth < 34 ? 2 : 1));
    final verticalPadding = viewportHeight < 260 ? 4.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(top: verticalPadding, bottom: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: horizontalPadding),
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: compact ? 10 : null,
                  ),
                ),
              ),
            ),
          ),
          ...List.generate(speeds.length, (i) {
            final showValueLabel = i % labelStep == 0 || i == speeds.length - 1;
            return _BarEditorCell(
              slotWidth: slotWidth,
              barWidth: barWidth,
              compact: compact,
              showValueLabel: showValueLabel,
              speedLabel: _speedLabel(speeds[i]),
              valueLabel: _valueLabel(_metric, values[i]).split(' ').first,
              value: values[i],
              min: range.$1,
              max: range.$2,
              onChanged: (v) => _setValueAt(_metric, i, v),
            );
          }),
          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }

  Widget _previewControls(ThemeData theme, {required bool compact}) {
    final dense = compact;
    final label = '${_previewSpeed.toStringAsFixed(2)} m/s';
    final title = Text(
      'Preview vertical speed',
      style: theme.textTheme.bodySmall,
    );
    final value = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, dense ? 4 : 8, 12, dense ? 8 : 16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Expanded(child: title),
                    value,
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: dense ? 2.5 : null,
                    thumbShape: dense
                        ? const RoundSliderThumbShape(enabledThumbRadius: 7)
                        : null,
                  ),
                  child: Slider(
                    value: _previewSpeed,
                    min: -7,
                    max: 7,
                    divisions: 56,
                    onChanged: (v) {
                      setState(() => _previewSpeed = v);
                      _audio.setPreviewSpeed(v);
                    },
                  ),
                ),
              ],
            )
          : Row(
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
                        children: [title, const Spacer(), value],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: dense ? 2.5 : null,
                          thumbShape: dense
                              ? const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                )
                              : null,
                        ),
                        child: Slider(
                          value: _previewSpeed,
                          min: -7,
                          max: 7,
                          divisions: 56,
                          onChanged: (v) {
                            setState(() => _previewSpeed = v);
                            _audio.setPreviewSpeed(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricSelectorRail(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _metricItem(theme, icon: Icons.graphic_eq, label: 'Frequency', metric: _CustomMetric.frequency),
          _metricItem(theme, icon: Icons.data_thresholding, label: 'Cycle', metric: _CustomMetric.cycle),
          _metricItem(theme, icon: Icons.tune, label: 'Duty', metric: _CustomMetric.duty),
        ],
      ),
    );
  }

  Widget _metricSelectorCompact(ThemeData theme) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _metricChip(theme, icon: Icons.graphic_eq, label: 'Frequency', metric: _CustomMetric.frequency),
          _metricChip(theme, icon: Icons.data_thresholding, label: 'Cycle', metric: _CustomMetric.cycle),
          _metricChip(theme, icon: Icons.tune, label: 'Duty', metric: _CustomMetric.duty),
        ],
      ),
    );
  }

  Widget _metricItem(
    ThemeData theme, {
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

  Widget _metricChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required _CustomMetric metric,
  }) {
    final selected = _metric == metric;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _metric = metric),
      avatar: Icon(
        icon,
        size: 16,
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
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
    required this.slotWidth,
    required this.barWidth,
    required this.compact,
    required this.showValueLabel,
    required this.speedLabel,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double slotWidth;
  final double barWidth;
  final bool compact;
  final bool showValueLabel;
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
    final labelFontSize = (slotWidth * 0.26).clamp(8.0, 13.0);

    return SizedBox(
      width: slotWidth,
      child: Column(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: showValueLabel ? 1 : 0,
            child: SizedBox(
              width: slotWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  showValueLabel ? valueLabel : ' ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: labelFontSize,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
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
                  child: Center(
                    child: SizedBox(
                      width: barWidth,
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
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            width: slotWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                speedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: (slotWidth * 0.28).clamp(9.0, 14.0),
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
