import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../audio/vario_audio_service.dart';
import '../audio/vario_config.dart';
import '../audio/vario_sound_settings.dart';
import 'vario_sound_customization_page.dart';

/// Opens the Vario Sound Settings screen as a modal bottom sheet.
///
/// Lets the user tune the vario beeper (lift/sink thresholds, pitch, waveform
/// and master gain). Changes apply live to [VarioAudioService] and are
/// persisted via [VarioSoundSettings].
Future<void> showVarioSoundSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
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

  /// Current audition vertical speed (m/s) driven by the preview slider.
  double _previewSpeed = 0.0;

  /// When true the audition is muted. The slider still moves and shows a speed,
  /// but the engine follows the live vario feed instead (subject to the flight
  /// gate), so preview-muted + not flying + "sound only when flying" is silent.
  bool _previewMuted = false;

  @override
  void initState() {
    super.initState();
    _settings.load();
    // Take over the vario sound while the panel is open so the live sensor
    // feed can't fight the audition. Starts silent (0 m/s).
    _audio.beginPreview(_previewSpeed);
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    // Hand control of the vario sound back to the live feed.
    _audio.endPreview();
    super.dispose();
  }

  void _setPreviewSpeed(double v) {
    _testTimer?.cancel();
    _testTimer = null;
    setState(() => _previewSpeed = v);
    _audio.setPreviewSpeed(v);
  }

  /// Mutes/unmutes the audition without changing the slider position. While
  /// muted the engine follows the live feed (and the flight gate).
  void _togglePreviewMuted() {
    setState(() => _previewMuted = !_previewMuted);
    _audio.setPreviewMuted(_previewMuted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
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
                      _sectionLabel(theme, 'Sound customization'),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: Icons.tune,
                        label: 'Enable sound customization',
                        description:
                            'Use custom Frequency/Cycle/Duty anchors instead '
                            'of the default vario profile curve.',
                        value: _settings.customSoundEnabled,
                        onChanged: _settings.setCustomSoundEnabled,
                      ),
                      _actionCard(
                        theme,
                        icon: Icons.equalizer,
                        label: 'Open Sound customization editor',
                        description:
                            'Adjust Frequency, Cycle and Duty by vertical '
                            'speed, with live preview.',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const VarioSoundCustomizationPage(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Thresholds'),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.trending_up,
                        label: 'Lift threshold',
                        value: _settings.liftThreshold,
                        min: 0.0,
                        max: 3.0,
                        divisions: 30,
                        display: '${_settings.liftThreshold.toStringAsFixed(1)} m/s',
                        onChanged: _settings.setLiftThreshold,
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
                        label: 'Lift base pitch',
                        value: _settings.liftBaseFreq,
                        min: 300.0,
                        max: 1200.0,
                        divisions: 90,
                        display: '${_settings.liftBaseFreq.round()} Hz',
                        onChanged: _settings.setLiftBaseFreq,
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.stacked_line_chart,
                        label: 'Lift pitch range',
                        value: _settings.liftFreqSpan,
                        min: 200.0,
                        max: 1500.0,
                        divisions: 130,
                        display: '+${_settings.liftFreqSpan.round()} Hz',
                        onChanged: _settings.setLiftFreqSpan,
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
                        label: 'Lift waveform',
                        value: _settings.liftWaveform,
                        onChanged: _settings.setLiftWaveform,
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
                      _switchCard(
                        theme,
                        icon: _settings.muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        label: 'Vario sound',
                        description: 'Master on/off for the vario beeper.',
                        value: !_settings.muted,
                        onChanged: (on) => _settings.setMuted(!on),
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.graphic_eq,
                        label: 'Vario volume',
                        value: _settings.volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        display: '${(_settings.volume * 100).round()}%',
                        onChanged:
                            _settings.muted ? null : _settings.setVolume,
                      ),
                      // Master gain is the profile's baseline headroom (a
                      // tuning constant, distinct from the live "Vario volume").
                      // It's only meaningful for advanced tuning, so it's shown
                      // in debug builds and hidden from release builds.
                      if (kDebugMode)
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
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'Behavior'),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: Icons.flight_takeoff,
                        label: 'Sound only when flying',
                        description:
                            'Stay silent until a flight is started, then '
                            'beep normally.',
                        value: _settings.soundOnlyWhenFlying,
                        onChanged: _settings.setSoundOnlyWhenFlying,
                      ),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: Icons.bluetooth_connected,
                        label: 'Sound only when sensor connected',
                        description:
                            'Stay silent unless a Bluetooth sensor is '
                            'connected.',
                        value: _settings.soundOnlyWhenSensorConnected,
                        onChanged: _settings.setSoundOnlyWhenSensorConnected,
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
    final speedLabel = '${_previewSpeed >= 0 ? '+' : ''}'
        '${_previewSpeed.toStringAsFixed(1)} m/s';
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
            // Tap to mute/unmute the audition. Shows "LIVE" while audible and
            // "MUTED" while silenced; the slider position is preserved either
            // way.
            _PreviewToggleChip(
              muted: _previewMuted,
              onTap: _togglePreviewMuted,
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.height, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text('Vertical speed', style: theme.textTheme.bodyMedium),
            ),
            Text(
              speedLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      Slider(
        value: _previewSpeed.clamp(-10.0, 10.0),
        min: -10.0,
        max: 10.0,
        divisions: 200,
        label: speedLabel,
        onChanged: _setPreviewSpeed,
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
    required ValueChanged<double>? onChanged,
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

  Widget _switchCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _actionCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
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

/// Tappable chip that mutes/unmutes the audition. Reads "LIVE" (highlighted)
/// while audible and "MUTED" (subdued) while silenced.
class _PreviewToggleChip extends StatelessWidget {
  const _PreviewToggleChip({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg = muted
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    final Color fg = muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimaryContainer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted ? Icons.volume_off : Icons.volume_up,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: 4),
              Text(
                muted ? 'MUTED' : 'LIVE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
