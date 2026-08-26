import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/vario_audio_service.dart';
import '../audio/vario_config.dart';
import '../audio/vario_sound_settings.dart';

/// Opens the Vario Sound Settings screen as a modal bottom sheet.
///
/// Lets the user tune the vario beeper (climb/sink thresholds, pitch, waveform
/// and master gain). Changes apply live to [VarioAudioService] and are
/// persisted via [VarioSoundSettings].
Future<void> showVarioSoundSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _VarioSoundSettingsSheet(),
  );
}

class _VarioSoundSettingsSheet extends StatefulWidget {
  const _VarioSoundSettingsSheet();

  @override
  State<_VarioSoundSettingsSheet> createState() =>
      _VarioSoundSettingsSheetState();
}

class _VarioSoundSettingsSheetState extends State<_VarioSoundSettingsSheet> {
  final VarioSoundSettings _settings = VarioSoundSettings.instance;
  final VarioAudioService _audio = VarioAudioService.instance;

  Timer? _testTimer;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _stopTest();
    super.dispose();
  }

  /// Briefly drives the vario with a fixed vertical speed so the user can hear
  /// the current profile, then returns it to zero.
  void _playTest(double verticalSpeed) {
    _testTimer?.cancel();
    _audio.updateSpeed(verticalSpeed);
    _testTimer = Timer(const Duration(seconds: 2), () {
      _audio.updateSpeed(0.0);
    });
  }

  void _stopTest() {
    _testTimer?.cancel();
    _testTimer = null;
    _audio.updateSpeed(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Vario Sound Settings',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Reset to defaults',
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () async {
                      await _settings.resetToDefaults();
                      if (mounted) setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _settings,
                builder: (context, _) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _testCard(theme),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Thresholds'),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.trending_up,
                        label: 'Climb threshold',
                        value: _settings.climbThreshold,
                        min: 0.0,
                        max: 3.0,
                        divisions: 30,
                        display: '${_settings.climbThreshold.toStringAsFixed(1)} m/s',
                        onChanged: _settings.setClimbThreshold,
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.trending_down,
                        label: 'Sink threshold',
                        value: _settings.sinkThreshold,
                        min: -6.0,
                        max: -0.5,
                        divisions: 55,
                        display: '${_settings.sinkThreshold.toStringAsFixed(1)} m/s',
                        onChanged: _settings.setSinkThreshold,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Pitch'),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.music_note,
                        label: 'Climb base pitch',
                        value: _settings.climbBaseFreq,
                        min: 300.0,
                        max: 1200.0,
                        divisions: 90,
                        display: '${_settings.climbBaseFreq.round()} Hz',
                        onChanged: _settings.setClimbBaseFreq,
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.stacked_line_chart,
                        label: 'Climb pitch range',
                        value: _settings.climbFreqSpan,
                        min: 200.0,
                        max: 1500.0,
                        divisions: 130,
                        display: '+${_settings.climbFreqSpan.round()} Hz',
                        onChanged: _settings.setClimbFreqSpan,
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.music_note_outlined,
                        label: 'Sink base pitch',
                        value: _settings.sinkBaseFreq,
                        min: 300.0,
                        max: 1200.0,
                        divisions: 90,
                        display: '${_settings.sinkBaseFreq.round()} Hz',
                        onChanged: _settings.setSinkBaseFreq,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Waveform'),
                      const SizedBox(height: 8),
                      _waveformCard(
                        theme,
                        label: 'Climb waveform',
                        value: _settings.climbWaveform,
                        onChanged: _settings.setClimbWaveform,
                      ),
                      const SizedBox(height: 8),
                      _waveformCard(
                        theme,
                        label: 'Sink waveform',
                        value: _settings.sinkWaveform,
                        onChanged: _settings.setSinkWaveform,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Output'),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.volume_up_outlined,
                        label: 'Master gain',
                        value: _settings.masterGain,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        display: '${(_settings.masterGain * 100).round()}%',
                        onChanged: _settings.setMasterGain,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Test controls ─────────────────────────────────────────────────────────
  Widget _testCard(ThemeData theme) {
    return _card(theme, [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Preview sound', style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _playTest(2.0),
              icon: const Icon(Icons.trending_up, size: 18),
              label: const Text('Climb'),
            ),
            OutlinedButton.icon(
              onPressed: () => _playTest(-3.0),
              icon: const Icon(Icons.trending_down, size: 18),
              label: const Text('Sink'),
            ),
            TextButton.icon(
              onPressed: _stopTest,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── Widgets ─────────────────────────────────────────────────────────────
  Widget _sliderCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                display,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _waveformCard(
    ThemeData theme, {
    required String label,
    required VarioWaveform value,
    required ValueChanged<VarioWaveform> onChanged,
  }) {
    return _card(theme, [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: VarioWaveform.values.map((w) {
                final selected = w == value;
                return ChoiceChip(
                  label: Text(_waveformName(w)),
                  selected: selected,
                  onSelected: (_) => onChanged(w),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ]);
  }

  String _waveformName(VarioWaveform w) {
    switch (w) {
      case VarioWaveform.tick:
        return 'Tick';
      case VarioWaveform.tack:
        return 'Tack';
      case VarioWaveform.square:
        return 'Square';
      case VarioWaveform.long:
        return 'Long';
    }
  }

  Widget _sectionLabel(ThemeData theme, String label) => Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _card(ThemeData theme, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );
}
