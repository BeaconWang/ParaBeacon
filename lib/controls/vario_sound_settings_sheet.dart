import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../audio/vario_audio_service.dart';
import '../audio/vario_config.dart';
import '../audio/vario_keypoints.dart';
import '../audio/vario_sound_settings.dart';
import '../l10n/app_localizations.dart';

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

  /// Builds a sensible initial keypoint for [speed]: reuse the interpolated
  /// curve value if already covered, otherwise seed from the classic formula so
  /// the first keypoint matches what the user is currently hearing.
  VarioKeypoint _defaultKeypointAt(double speed) {
    final curve = _settings.keypoints;
    if (curve.covers(speed)) {
      final s = curve.sampleAt(speed);
      return VarioKeypoint(
        speed: speed,
        freqHz: s.freqHz,
        cycleSeconds: s.cycleSeconds,
        duty: s.duty,
        waveform: s.waveform,
      );
    }
    final c = _settings.config;
    if (speed >= 0) {
      final v = speed <= 0 ? 0.01 : speed;
      final cycle = c.liftPeriodFor(v);
      return VarioKeypoint(
        speed: speed,
        freqHz: c.liftFrequencyFor(v),
        cycleSeconds: cycle,
        duty: (c.liftToneSeconds / cycle).clamp(0.05, 1.0),
        waveform: c.liftWaveform,
      );
    }
    final cycle = c.sinkPeriodSeconds;
    return VarioKeypoint(
      speed: speed,
      freqHz: c.sinkFrequencyFor(speed),
      cycleSeconds: cycle,
      duty: (c.sinkToneSeconds / cycle).clamp(0.05, 1.0),
      waveform: c.sinkWaveform,
    );
  }

  void _addKeypointAtCurrentSpeed() {
    // Snap to the 0.1 m/s bucket the model de-duplicates on.
    final speed = double.parse(_previewSpeed.toStringAsFixed(1));
    _settings.upsertKeypoint(_defaultKeypointAt(speed));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
                  Text(l10n.varioSoundTitle, style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.varioSoundResetTooltip,
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
                      _testCard(theme, l10n),
                      const SizedBox(height: 20),
                      _keypointsCard(theme, l10n),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.varioSoundSectionThresholds),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.trending_up,
                        label: l10n.varioSoundLiftThreshold,
                        value: _settings.liftThreshold,
                        min: 0.0,
                        max: 3.0,
                        divisions: 30,
                        display:
                            '${_settings.liftThreshold.toStringAsFixed(1)} m/s',
                        onChanged: _settings.setLiftThreshold,
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.trending_down,
                        label: l10n.varioSoundSinkThreshold,
                        value: _settings.sinkThreshold,
                        min: -6.0,
                        max: -0.5,
                        divisions: 55,
                        display:
                            '${_settings.sinkThreshold.toStringAsFixed(1)} m/s',
                        onChanged: _settings.setSinkThreshold,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.varioSoundSectionPitch),
                      const SizedBox(height: 8),
                      _sliderCard(
                        theme,
                        icon: Icons.music_note,
                        label: l10n.varioSoundLiftBasePitch,
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
                        label: l10n.varioSoundLiftPitchRange,
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
                        label: l10n.varioSoundSinkBasePitch,
                        value: _settings.sinkBaseFreq,
                        min: 300.0,
                        max: 1200.0,
                        divisions: 90,
                        display: '${_settings.sinkBaseFreq.round()} Hz',
                        onChanged: _settings.setSinkBaseFreq,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.varioSoundSectionWaveform),
                      const SizedBox(height: 8),
                      _waveformCard(
                        theme,
                        l10n,
                        label: l10n.varioSoundLiftWaveform,
                        value: _settings.liftWaveform,
                        onChanged: _settings.setLiftWaveform,
                      ),
                      const SizedBox(height: 8),
                      _waveformCard(
                        theme,
                        l10n,
                        label: l10n.varioSoundSinkWaveform,
                        value: _settings.sinkWaveform,
                        onChanged: _settings.setSinkWaveform,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.varioSoundSectionOutput),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: _settings.muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        label: l10n.varioSoundVarioSound,
                        description: l10n.varioSoundVarioSoundDescription,
                        value: !_settings.muted,
                        onChanged: (on) => _settings.setMuted(!on),
                      ),
                      _sliderCard(
                        theme,
                        icon: Icons.graphic_eq,
                        label: l10n.varioSoundVolume,
                        value: _settings.volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        display: '${(_settings.volume * 100).round()}%',
                        onChanged: _settings.muted ? null : _settings.setVolume,
                      ),
                      // Master gain is the profile's baseline headroom (a
                      // tuning constant, distinct from the live "Vario volume").
                      // It's only meaningful for advanced tuning, so it's shown
                      // in debug builds and hidden from release builds.
                      if (kDebugMode)
                        _sliderCard(
                          theme,
                          icon: Icons.volume_up_outlined,
                          label: l10n.varioSoundMasterGain,
                          value: _settings.masterGain,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          display: '${(_settings.masterGain * 100).round()}%',
                          onChanged: _settings.setMasterGain,
                        ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, l10n.varioSoundSectionBehavior),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: Icons.flight_takeoff,
                        label: l10n.varioSoundOnlyWhenFlying,
                        description: l10n.varioSoundOnlyWhenFlyingDescription,
                        value: _settings.soundOnlyWhenFlying,
                        onChanged: _settings.setSoundOnlyWhenFlying,
                      ),
                      const SizedBox(height: 8),
                      _switchCard(
                        theme,
                        icon: Icons.bluetooth_connected,
                        label: l10n.varioSoundOnlyWhenSensorConnected,
                        description:
                            l10n.varioSoundOnlyWhenSensorConnectedDescription,
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
  Widget _testCard(ThemeData theme, AppLocalizations l10n) {
    final speedLabel =
        '${_previewSpeed >= 0 ? '+' : ''}'
        '${_previewSpeed.toStringAsFixed(1)} m/s';
    return _card(theme, [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.varioSoundPreview,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            // Tap to mute/unmute the audition. Shows "LIVE" while audible and
            // "MUTED" while silenced; the slider position is preserved either
            // way.
            _PreviewToggleChip(
              muted: _previewMuted,
              liveLabel: l10n.varioSoundPreviewLive,
              mutedLabel: l10n.varioSoundPreviewMuted,
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
              child: Text(
                l10n.varioSoundVerticalSpeed,
                style: theme.textTheme.bodyMedium,
              ),
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

  // ── Vertical-speed keypoints ───────────────────────────────────────────────
  Widget _keypointsCard(ThemeData theme, AppLocalizations l10n) {
    final keypoints = _settings.keypointList;
    final speedLabel =
        '${_previewSpeed >= 0 ? '+' : ''}'
        '${_previewSpeed.toStringAsFixed(1)} m/s';
    return _card(theme, [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timeline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.varioSoundKeypointsTitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.varioSoundKeypointsDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _addKeypointAtCurrentSpeed,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.varioSoundKeypointAddAt(speedLabel)),
              ),
            ),
            if (keypoints.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _settings.clearKeypoints,
                child: Text(l10n.varioSoundKeypointClearAll),
              ),
            ],
          ],
        ),
      ),
      if (keypoints.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            l10n.varioSoundKeypointsEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else ...[
        if (keypoints.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              l10n.varioSoundKeypointsNeedTwo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ...keypoints.map((kp) => _keypointTile(theme, l10n, kp)),
      ],
    ]);
  }

  Widget _keypointTile(
    ThemeData theme,
    AppLocalizations l10n,
    VarioKeypoint kp,
  ) {
    final speedLabel =
        '${kp.speed >= 0 ? '+' : ''}${kp.speed.toStringAsFixed(1)} m/s';
    final cycleMs = (kp.cycleSeconds * 1000).round();
    final dutyLabel = kp.duty >= 1.0
        ? l10n.varioSoundKeypointContinuous
        : '${(kp.duty * 100).round()}%';
    final summary = '${kp.freqHz.round()} Hz · $cycleMs ms · $dutyLabel';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  speedLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _setPreviewSpeed(kp.speed),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.varioSoundKeypointAudition),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.varioSoundKeypointDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _settings.removeKeypoint(kp.speed),
                ),
              ],
            ),
            _miniSlider(
              theme,
              label: l10n.varioSoundKeypointPitch,
              value: kp.freqHz,
              min: 100.0,
              max: 2000.0,
              divisions: 190,
              display: '${kp.freqHz.round()} Hz',
              onChanged: (v) =>
                  _settings.upsertKeypoint(kp.copyWith(freqHz: v)),
            ),
            _miniSlider(
              theme,
              label: l10n.varioSoundKeypointCycle,
              value: kp.cycleSeconds,
              min: 0.05,
              max: 2.0,
              divisions: 195,
              display: '${(kp.cycleSeconds * 1000).round()} ms',
              onChanged: (v) =>
                  _settings.upsertKeypoint(kp.copyWith(cycleSeconds: v)),
            ),
            _miniSlider(
              theme,
              label: l10n.varioSoundKeypointDuty,
              value: kp.duty,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              display: dutyLabel,
              onChanged: (v) => _settings.upsertKeypoint(kp.copyWith(duty: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  l10n.varioSoundKeypointWaveform,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: VarioWaveform.values.map((w) {
                  return ChoiceChip(
                    label: Text(_waveformName(l10n, w)),
                    selected: w == kp.waveform,
                    onSelected: (_) =>
                        _settings.upsertKeypoint(kp.copyWith(waveform: w)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSlider(
    ThemeData theme, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
            Text(
              display,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
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
    );
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

  Widget _waveformCard(
    ThemeData theme,
    AppLocalizations l10n, {
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
                  label: Text(_waveformName(l10n, w)),
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

  String _waveformName(AppLocalizations l10n, VarioWaveform w) {
    switch (w) {
      case VarioWaveform.tick:
        return l10n.varioWaveformTick;
      case VarioWaveform.tack:
        return l10n.varioWaveformTack;
      case VarioWaveform.square:
        return l10n.varioWaveformSquare;
      case VarioWaveform.long:
        return l10n.varioWaveformLong;
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
  const _PreviewToggleChip({
    required this.muted,
    required this.liveLabel,
    required this.mutedLabel,
    required this.onTap,
  });

  final bool muted;
  final String liveLabel;
  final String mutedLabel;
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
                muted ? mutedLabel : liveLabel,
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
