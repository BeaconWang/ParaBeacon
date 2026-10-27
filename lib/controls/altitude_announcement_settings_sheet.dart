import 'package:flutter/material.dart';

import '../audio/altitude_announcement_bridge.dart';
import '../audio/altitude_announcement_settings.dart';
import '../audio/altitude_announcement_speaker.dart';
import '../audio/ble_sensor_announcement_bridge.dart'
    show speakBleSensorAnnouncementTest;
import '../audio/announcement_template.dart';
import '../audio/custom_announcement_rule.dart';
import '../data/flight_state.dart';
import '../l10n/app_localizations.dart';

Future<void> showAltitudeAnnouncementSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AltitudeAnnouncementSettingsSheet(),
  );
}

/// 1.0 -> "1.0", 1.25 -> "1.25", 1.1 -> "1.1".
String _formatRate(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

String _eventLabel(AppLocalizations l10n, AnnouncementEvent event) =>
    switch (event) {
      AnnouncementEvent.takeoff => l10n.altitudeAnnouncementEventTakeoff,
      AnnouncementEvent.continueFlight =>
        l10n.altitudeAnnouncementEventContinueFlight,
      AnnouncementEvent.landing => l10n.altitudeAnnouncementEventLanding,
      AnnouncementEvent.glide => l10n.altitudeAnnouncementEventGlide,
      AnnouncementEvent.altitudeRecord =>
        l10n.altitudeAnnouncementEventAltitudeRecord,
    };

String _placeholderLabel(
  AppLocalizations l10n,
  AnnouncementPlaceholder placeholder,
) => switch (placeholder) {
  AnnouncementPlaceholder.altitude =>
    l10n.altitudeAnnouncementPlaceholderAltitude,
  AnnouncementPlaceholder.altitudeUnit =>
    l10n.altitudeAnnouncementPlaceholderAltitudeUnit,
  AnnouncementPlaceholder.climb => l10n.altitudeAnnouncementPlaceholderClimb,
  AnnouncementPlaceholder.climbUnit =>
    l10n.altitudeAnnouncementPlaceholderClimbUnit,
  AnnouncementPlaceholder.groundSpeed =>
    l10n.altitudeAnnouncementPlaceholderGroundSpeed,
  AnnouncementPlaceholder.speedUnit =>
    l10n.altitudeAnnouncementPlaceholderSpeedUnit,
  AnnouncementPlaceholder.heightAboveGround =>
    l10n.altitudeAnnouncementPlaceholderAgl,
  AnnouncementPlaceholder.heightAboveTakeoff =>
    l10n.altitudeAnnouncementPlaceholderTakeoffHeight,
  AnnouncementPlaceholder.maxAltitude =>
    l10n.altitudeAnnouncementPlaceholderMaxAltitude,
  AnnouncementPlaceholder.glideRatio =>
    l10n.altitudeAnnouncementPlaceholderGlideRatio,
  AnnouncementPlaceholder.windSpeed =>
    l10n.altitudeAnnouncementPlaceholderWindSpeed,
  AnnouncementPlaceholder.flightTime =>
    l10n.altitudeAnnouncementPlaceholderFlightTime,
  AnnouncementPlaceholder.distance =>
    l10n.altitudeAnnouncementPlaceholderDistance,
  AnnouncementPlaceholder.distanceUnit =>
    l10n.altitudeAnnouncementPlaceholderDistanceUnit,
  AnnouncementPlaceholder.time => l10n.altitudeAnnouncementPlaceholderTime,
};

class _AltitudeAnnouncementSettingsSheet extends StatefulWidget {
  const _AltitudeAnnouncementSettingsSheet();

  @override
  State<_AltitudeAnnouncementSettingsSheet> createState() =>
      _AltitudeAnnouncementSettingsSheetState();
}

class _AltitudeAnnouncementSettingsSheetState
    extends State<_AltitudeAnnouncementSettingsSheet> {
  Object? _testing;
  Object? _lastTested;
  bool? _lastTestSucceeded;

  Future<void> _runTest(AnnouncementEvent event) async {
    if (_testing != null) return;
    setState(() {
      _testing = event;
      _lastTested = event;
      _lastTestSucceeded = null;
    });
    final ok = await speakAnnouncementTest(event);
    if (!mounted) return;
    setState(() {
      _testing = null;
      _lastTestSucceeded = ok;
    });
  }

  Future<void> _runBleTest(BleSensorAnnouncementEvent event) async {
    if (_testing != null) return;
    setState(() {
      _testing = event;
      _lastTested = event;
      _lastTestSucceeded = null;
    });
    final ok = await speakBleSensorAnnouncementTest(event);
    if (!mounted) return;
    setState(() {
      _testing = null;
      _lastTestSucceeded = ok;
    });
  }

  Widget _textTile(AnnouncementEvent event) {
    return _AnnouncementTextTile(
      event: event,
      testing: _testing == event,
      testBusy: _testing != null,
      testResult: _lastTested == event ? _lastTestSucceeded : null,
      onTest: () => _runTest(event),
    );
  }

  Widget _bleSensorTextTile(BleSensorAnnouncementEvent event) {
    return _BleSensorAnnouncementTextTile(
      event: event,
      testing: _testing == event,
      testBusy: _testing != null,
      testResult: _lastTested == event ? _lastTestSucceeded : null,
      onTest: () => _runBleTest(event),
    );
  }

  Future<void> _addCustomRule(AltitudeAnnouncementSettings settings) async {
    final rule = CustomAnnouncementRule(
      id: settings.nextCustomRuleId,
      metric: AnnouncementMetric.verticalSpeed,
      condition: AnnouncementCondition.greaterThan,
      threshold: 2,
      upperThreshold: 4,
      repeatSeconds: null,
      enabled: true,
      content: '',
    );
    final saved = await showDialog<CustomAnnouncementRule>(
      context: context,
      builder: (context) => _CustomAnnouncementRuleDialog(rule: rule),
    );
    if (!mounted || saved == null) return;
    settings.saveCustomRule(saved);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AltitudeAnnouncementSettings.instance;
    final speaker = AltitudeAnnouncementSpeaker.instance;
    final flightState = FlightState.instance;
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([settings, speaker, flightState]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final unavailable =
            _lastTestSucceeded == null &&
            speaker.availability == SpeechAvailability.unavailable;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.altitudeAnnouncementTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.altitudeAnnouncementDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementVoiceEnabled),
                  subtitle: Text(
                    l10n.altitudeAnnouncementVoiceEnabledDescription,
                  ),
                  value: settings.announcementsEnabled,
                  onChanged: settings.setAnnouncementsEnabled,
                ),
                if (unavailable) ...[
                  const SizedBox(height: 8),
                  _ErrorNote(text: l10n.altitudeAnnouncementUnavailable),
                ],

                // ── Events ────────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.event,
                  title: l10n.altitudeAnnouncementSectionEvent,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.bleSensorAnnouncementEnabled),
                  subtitle: Text(l10n.bleSensorAnnouncementEnabledDescription),
                  value: settings.bleSensorAnnouncementsEnabled,
                  onChanged: settings.setBleSensorAnnouncementsEnabled,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.bleSensorAnnouncementTextDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                for (final event in BleSensorAnnouncementEvent.values)
                  _bleSensorTextTile(event),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementTakeoffLandingEnabled),
                  subtitle: Text(
                    l10n.altitudeAnnouncementTakeoffLandingDescription,
                  ),
                  value: settings.takeoffLandingEnabled,
                  onChanged: settings.setTakeoffLandingEnabled,
                ),
                if (!flightState.autoDetect) ...[
                  _InfoNote(text: l10n.altitudeAnnouncementAutoDetectOff),
                  const SizedBox(height: 4),
                ],
                _textTile(AnnouncementEvent.takeoff),
                _textTile(AnnouncementEvent.continueFlight),
                _textTile(AnnouncementEvent.landing),

                // ── Feature 2: glide dead zone ────────────────────────────
                _SectionHeader(
                  icon: Icons.trending_flat,
                  title: l10n.altitudeAnnouncementSectionGlide,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementGlideEnabled),
                  subtitle: Text(l10n.altitudeAnnouncementGlideDescription),
                  value: settings.glideEnabled,
                  onChanged: settings.setGlideEnabled,
                ),
                Text(
                  l10n.altitudeAnnouncementGlideRange(
                    settings.glideMinimum.toStringAsFixed(1),
                    settings.glideMaximum.toStringAsFixed(1),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                RangeSlider(
                  values: RangeValues(
                    settings.glideMinimum,
                    settings.glideMaximum,
                  ),
                  min: AltitudeAnnouncementSettings.glideRangeMin,
                  max: AltitudeAnnouncementSettings.glideRangeMax,
                  divisions: 40,
                  labels: RangeLabels(
                    settings.glideMinimum.toStringAsFixed(1),
                    settings.glideMaximum.toStringAsFixed(1),
                  ),
                  onChanged: settings.glideEnabled
                      ? (values) =>
                            settings.setGlideRange(values.start, values.end)
                      : null,
                ),
                Text(
                  l10n.altitudeAnnouncementGlideDelay(
                    settings.glideDelaySeconds.toStringAsFixed(1),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: settings.glideDelaySeconds,
                  min: AltitudeAnnouncementSettings.minGlideDelay,
                  max: AltitudeAnnouncementSettings.maxGlideDelay,
                  divisions: 20,
                  label: '${settings.glideDelaySeconds.toStringAsFixed(1)} s',
                  onChanged: settings.glideEnabled
                      ? settings.setGlideDelaySeconds
                      : null,
                ),
                Text(
                  l10n.altitudeAnnouncementGlideRepeat(
                    settings.glideRepeatSeconds.round().toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: settings.glideRepeatSeconds,
                  min: AltitudeAnnouncementSettings.minGlideRepeat,
                  max: AltitudeAnnouncementSettings.maxGlideRepeat,
                  divisions: 9,
                  label: '${settings.glideRepeatSeconds.round()} s',
                  onChanged: settings.glideEnabled
                      ? settings.setGlideRepeatSeconds
                      : null,
                ),
                _textTile(AnnouncementEvent.glide),

                // ── Feature 3: altitude record ────────────────────────────
                _SectionHeader(
                  icon: Icons.emoji_events_outlined,
                  title: l10n.altitudeAnnouncementSectionRecord,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementRecordEnabled),
                  subtitle: Text(l10n.altitudeAnnouncementRecordDescription),
                  value: settings.recordEnabled,
                  onChanged: settings.setRecordEnabled,
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AltitudeRecordScope>(
                    segments: [
                      ButtonSegment(
                        value: AltitudeRecordScope.flight,
                        label: Text(l10n.altitudeAnnouncementRecordScopeFlight),
                      ),
                      ButtonSegment(
                        value: AltitudeRecordScope.allFlights,
                        label: Text(l10n.altitudeAnnouncementRecordScopeAll),
                      ),
                    ],
                    selected: {settings.recordScope},
                    onSelectionChanged: settings.recordEnabled
                        ? (selection) =>
                              settings.setRecordScope(selection.first)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.altitudeAnnouncementRecordInterval(
                    settings.recordIntervalSeconds.round().toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: settings.recordIntervalSeconds,
                  min: AltitudeAnnouncementSettings.minRecordInterval,
                  max: AltitudeAnnouncementSettings.maxRecordInterval,
                  divisions: 59,
                  label: '${settings.recordIntervalSeconds.round()} s',
                  onChanged: settings.recordEnabled
                      ? settings.setRecordIntervalSeconds
                      : null,
                ),
                _textTile(AnnouncementEvent.altitudeRecord),

                // ── Custom data conditions ────────────────────────────────
                _SectionHeader(
                  icon: Icons.rule_folder_outlined,
                  title: l10n.altitudeAnnouncementSectionCustomRules,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.altitudeAnnouncementCustomRulesDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                for (final rule in settings.customRules)
                  _CustomAnnouncementRuleTile(
                    key: ValueKey(rule.id),
                    rule: rule,
                  ),
                if (settings.customRules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.altitudeAnnouncementCustomRuleEmpty,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        settings.customRules.length >=
                            CustomAnnouncementRule.maxRules
                        ? null
                        : () => _addCustomRule(settings),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.altitudeAnnouncementCustomRuleAdd),
                  ),
                ),
                if (settings.customRules.length >=
                    CustomAnnouncementRule.maxRules)
                  _InfoNote(text: l10n.altitudeAnnouncementCustomRuleLimit),

                // ── Voice ─────────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.tune,
                  title: l10n.altitudeAnnouncementSectionVoice,
                ),
                Text(
                  l10n.altitudeAnnouncementVolume(
                    (settings.volume * 100).round().toString(),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                Slider(
                  key: const ValueKey('announcementVolume'),
                  value: settings.volume,
                  min: AltitudeAnnouncementSettings.minVolume,
                  max: AltitudeAnnouncementSettings.maxVolume,
                  divisions: 20,
                  label: '${(settings.volume * 100).round()}%',
                  semanticFormatterCallback: (value) =>
                      l10n.altitudeAnnouncementVolume(
                        (value * 100).round().toString(),
                      ),
                  onChanged: settings.setVolume,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.altitudeAnnouncementSpeechRate(
                          _formatRate(settings.speechRate),
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: settings.speechRate == 1.0
                          ? null
                          : () => settings.setSpeechRate(1.0),
                      child: Text(l10n.altitudeAnnouncementSpeechRateNormal),
                    ),
                  ],
                ),
                Slider(
                  value: settings.speechRate,
                  min: AltitudeAnnouncementSettings.minSpeechRate,
                  max: AltitudeAnnouncementSettings.maxSpeechRate,
                  divisions: 150,
                  label: '${_formatRate(settings.speechRate)}×',
                  onChanged: settings.setSpeechRate,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementDuckVario),
                  subtitle: Text(l10n.altitudeAnnouncementDuckVarioDescription),
                  value: settings.duckVario,
                  onChanged: settings.setDuckVario,
                ),
                Text(
                  l10n.altitudeAnnouncementDuckLevel(
                    (settings.varioDuckLevel * 100).round().toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: settings.varioDuckLevel,
                  min: AltitudeAnnouncementSettings.minDuckLevel,
                  max: AltitudeAnnouncementSettings.maxDuckLevel,
                  divisions: 9,
                  label: '${(settings.varioDuckLevel * 100).round()}%',
                  onChanged: settings.duckVario
                      ? settings.setVarioDuckLevel
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// One announcement: its label, a live preview of the spoken text, a test
/// (listen) button and an expandable editor for the custom text.
class _AnnouncementTextTile extends StatefulWidget {
  const _AnnouncementTextTile({
    required this.event,
    required this.testing,
    required this.testBusy,
    required this.testResult,
    required this.onTest,
  });

  final AnnouncementEvent event;

  /// This announcement is currently being tested.
  final bool testing;

  /// Any announcement is currently being tested.
  final bool testBusy;

  /// Result of the last test of this announcement, if any.
  final bool? testResult;
  final VoidCallback onTest;

  @override
  State<_AnnouncementTextTile> createState() => _AnnouncementTextTileState();
}

class _AnnouncementTextTileState extends State<_AnnouncementTextTile> {
  final _settings = AltitudeAnnouncementSettings.instance;
  late final TextEditingController _controller = TextEditingController(
    text: _settings.templateFor(widget.event) ?? '',
  );
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) =>
      _settings.setTemplateFor(widget.event, value);

  void _insertPlaceholder(AnnouncementPlaceholder placeholder) {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final token = placeholder.token;
    if (text.length - (end - start) + token.length >
        AnnouncementTemplate.maxLength) {
      return;
    }
    final next = text.replaceRange(start, end, token);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _onChanged(next);
  }

  void _reset() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final event = widget.event;
    final template = _settings.templateFor(event);
    final preview = renderAnnouncement(
      event,
      template,
      announcementLanguageFor(template),
      AnnouncementValues.sampleFor(event),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventLabel(l10n, event),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.altitudeAnnouncementTemplatePreview(preview),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.altitudeAnnouncementCustomize,
                    isSelected: _expanded,
                    icon: const Icon(Icons.edit_outlined),
                    selectedIcon: const Icon(Icons.expand_less),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                  IconButton(
                    tooltip: l10n.altitudeAnnouncementTest,
                    onPressed: widget.testBusy ? null : widget.onTest,
                    icon: widget.testing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up),
                  ),
                ],
              ),
              if (widget.testResult == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    l10n.altitudeAnnouncementTestSuccess,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else if (widget.testResult == false)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: _ErrorNote(text: l10n.altitudeAnnouncementUnavailable),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: _buildEditor(theme, l10n, template),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(
    ThemeData theme,
    AppLocalizations l10n,
    String? template,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.altitudeAnnouncementTemplate,
                style: theme.textTheme.labelLarge,
              ),
            ),
            TextButton(
              onPressed: template == null ? null : _reset,
              child: Text(l10n.altitudeAnnouncementTemplateReset),
            ),
          ],
        ),
        Text(
          l10n.altitudeAnnouncementTemplateDescription,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          maxLength: AnnouncementTemplate.maxLength,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: AnnouncementTemplate.defaultFor(
              preferredAnnouncementLanguage(),
              widget.event,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final placeholder in AnnouncementPlaceholder.values)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.add, size: 16),
                label: Text(_placeholderLabel(l10n, placeholder)),
                tooltip: placeholder.token,
                onPressed: () => _insertPlaceholder(placeholder),
              ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _BleSensorAnnouncementTextTile extends StatefulWidget {
  const _BleSensorAnnouncementTextTile({
    required this.event,
    required this.testing,
    required this.testBusy,
    required this.testResult,
    required this.onTest,
  });

  final BleSensorAnnouncementEvent event;
  final bool testing;
  final bool testBusy;
  final bool? testResult;
  final VoidCallback onTest;

  @override
  State<_BleSensorAnnouncementTextTile> createState() =>
      _BleSensorAnnouncementTextTileState();
}

class _BleSensorAnnouncementTextTileState
    extends State<_BleSensorAnnouncementTextTile> {
  final _settings = AltitudeAnnouncementSettings.instance;
  late final Map<AnnouncementLanguage, TextEditingController> _controllers = {
    for (final language in AnnouncementLanguage.values)
      language: TextEditingController(
        text:
            _settings.customBleSensorAnnouncementText(widget.event, language) ??
            '',
      ),
  };
  bool _expanded = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reset(AnnouncementLanguage language) {
    _controllers[language]!.clear();
    _settings.setBleSensorAnnouncementText(widget.event, language, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final language = preferredAnnouncementLanguage();
    final title = switch (widget.event) {
      BleSensorAnnouncementEvent.connected => l10n.sensorConnected,
      BleSensorAnnouncementEvent.disconnected => l10n.sensorDisconnected,
    };
    final preview = _settings.bleSensorAnnouncementText(widget.event, language);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          l10n.altitudeAnnouncementTemplatePreview(preview),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey(
                      'bleSensorAnnouncementCustomize-${widget.event.name}',
                    ),
                    tooltip: l10n.altitudeAnnouncementCustomize,
                    isSelected: _expanded,
                    icon: const Icon(Icons.edit_outlined),
                    selectedIcon: const Icon(Icons.expand_less),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                  IconButton(
                    key: ValueKey(
                      'bleSensorAnnouncementTest-${widget.event.name}',
                    ),
                    tooltip: l10n.altitudeAnnouncementTest,
                    onPressed: widget.testBusy ? null : widget.onTest,
                    icon: widget.testing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up),
                  ),
                ],
              ),
              if (widget.testResult == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    l10n.altitudeAnnouncementTestSuccess,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else if (widget.testResult == false)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: _ErrorNote(text: l10n.altitudeAnnouncementUnavailable),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: _buildEditor(l10n),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(AppLocalizations l10n) {
    final language = preferredAnnouncementLanguage();
    return TextField(
      key: ValueKey(
        'bleSensorAnnouncement-${widget.event.name}-${language.name}',
      ),
      controller: _controllers[language],
      onChanged: (text) =>
          _settings.setBleSensorAnnouncementText(widget.event, language, text),
      maxLength: AnnouncementTemplate.maxLength,
      minLines: 1,
      maxLines: 2,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: language == AnnouncementLanguage.chinese
            ? l10n.languageChineseSimplified
            : l10n.languageEnglish,
        hintText: AltitudeAnnouncementSettings.defaultBleSensorAnnouncement(
          widget.event,
          language,
        ),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          key: ValueKey(
            'bleSensorAnnouncementReset-${widget.event.name}-${language.name}',
          ),
          tooltip: l10n.altitudeAnnouncementTemplateReset,
          onPressed:
              _settings.customBleSensorAnnouncementText(
                    widget.event,
                    language,
                  ) ==
                  null
              ? null
              : () => _reset(language),
          icon: const Icon(Icons.restore),
        ),
      ),
    );
  }
}

class _CustomAnnouncementRuleTile extends StatelessWidget {
  const _CustomAnnouncementRuleTile({required this.rule, super.key});

  final CustomAnnouncementRule rule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AltitudeAnnouncementSettings.instance;
    final bounds = rule.condition == AnnouncementCondition.withinRange
        ? '${rule.threshold}–${rule.upperThreshold}'
        : '${rule.threshold}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Switch.adaptive(
          value: rule.enabled,
          onChanged: (value) => settings.setCustomRuleEnabled(rule.id, value),
        ),
        title: Text(_metricLabel(l10n, rule.metric)),
        subtitle: Text(
          '${_conditionLabel(l10n, rule.condition)} $bounds ${_metricUnit(rule.metric)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.altitudeAnnouncementCustomize,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final edited = await showDialog<CustomAnnouncementRule>(
                  context: context,
                  builder: (context) =>
                      _CustomAnnouncementRuleDialog(rule: rule),
                );
                if (edited != null) settings.saveCustomRule(edited);
              },
            ),
            IconButton(
              tooltip: l10n.altitudeAnnouncementCustomDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => settings.removeCustomRule(rule.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomAnnouncementRuleDialog extends StatefulWidget {
  const _CustomAnnouncementRuleDialog({required this.rule});

  final CustomAnnouncementRule rule;

  @override
  State<_CustomAnnouncementRuleDialog> createState() =>
      _CustomAnnouncementRuleDialogState();
}

class _CustomAnnouncementRuleDialogState
    extends State<_CustomAnnouncementRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late AnnouncementMetric _metric = widget.rule.metric;
  late AnnouncementCondition _condition = widget.rule.condition;
  late final TextEditingController _threshold = TextEditingController(
    text: _formatNumber(widget.rule.threshold),
  );
  late final TextEditingController _upper = TextEditingController(
    text: _formatNumber(widget.rule.upperThreshold),
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.rule.content,
  );
  late bool _repeat = widget.rule.repeatSeconds != null;
  late double _repeatSeconds = widget.rule.repeatSeconds ?? 10;

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  void _insertPlaceholder(AnnouncementPlaceholder placeholder) {
    final value = _content.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final token = placeholder.token;
    if (text.length - (end - start) + token.length >
        AnnouncementTemplate.maxLength) {
      return;
    }
    final next = text.replaceRange(start, end, token);
    _content.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  String _preview() {
    final template = _content.text;
    return AnnouncementTemplate.render(
      template,
      announcementLanguageFor(template),
      AnnouncementValues.sample,
    );
  }

  @override
  void dispose() {
    _threshold.dispose();
    _upper.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final lower = _number(_threshold)!;
    final upper = _condition == AnnouncementCondition.withinRange
        ? _number(_upper)!
        : lower;
    Navigator.of(context).pop(
      CustomAnnouncementRule(
        id: widget.rule.id,
        metric: _metric,
        condition: _condition,
        threshold: lower,
        upperThreshold: upper,
        repeatSeconds: _repeat ? _repeatSeconds : null,
        enabled: widget.rule.enabled,
        content: AnnouncementTemplate.sanitize(_content.text) ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.altitudeAnnouncementCustomRuleTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<AnnouncementMetric>(
                initialValue: _metric,
                decoration: InputDecoration(
                  labelText: l10n.altitudeAnnouncementCustomMetric,
                ),
                items: [
                  for (final value in AnnouncementMetric.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_metricLabel(l10n, value)),
                    ),
                ],
                onChanged: (value) => setState(() => _metric = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AnnouncementCondition>(
                initialValue: _condition,
                decoration: InputDecoration(
                  labelText: l10n.altitudeAnnouncementCustomCondition,
                ),
                items: [
                  for (final value in AnnouncementCondition.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_conditionLabel(l10n, value)),
                    ),
                ],
                onChanged: (value) => setState(() => _condition = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _threshold,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: _condition == AnnouncementCondition.withinRange
                      ? l10n.altitudeAnnouncementCustomLower
                      : l10n.altitudeAnnouncementCustomThreshold,
                  suffixText: _metricUnit(_metric),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || !parsed.isFinite
                      ? l10n.altitudeAnnouncementCustomThreshold
                      : null;
                },
              ),
              if (_condition == AnnouncementCondition.withinRange) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _upper,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.altitudeAnnouncementCustomUpper,
                    suffixText: _metricUnit(_metric),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    final lower = _number(_threshold);
                    return parsed == null ||
                            !parsed.isFinite ||
                            lower == null ||
                            parsed < lower
                        ? l10n.altitudeAnnouncementCustomUpper
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.altitudeAnnouncementCustomContent,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.altitudeAnnouncementCustomTemplateDescription,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _content,
                onChanged: (_) => setState(() {}),
                maxLength: AnnouncementTemplate.maxLength,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.altitudeAnnouncementCustomContentRequired,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.altitudeAnnouncementCustomContentRequired
                    : null,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final placeholder in AnnouncementPlaceholder.values)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(_placeholderLabel(l10n, placeholder)),
                      tooltip: placeholder.token,
                      onPressed: () => _insertPlaceholder(placeholder),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.altitudeAnnouncementTemplatePreview(_preview()),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.altitudeAnnouncementCustomRepeat),
                value: _repeat,
                onChanged: (value) => setState(() => _repeat = value ?? false),
              ),
              if (_repeat) ...[
                Text(
                  l10n.altitudeAnnouncementCustomRepeatInterval(
                    _repeatSeconds.round().toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: _repeatSeconds,
                  min: CustomAnnouncementRule.minRepeatSeconds,
                  max: CustomAnnouncementRule.maxRepeatSeconds,
                  divisions: 59,
                  label: '${_repeatSeconds.round()} s',
                  onChanged: (value) => setState(() => _repeatSeconds = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}

String _metricLabel(
  AppLocalizations l10n,
  AnnouncementMetric metric,
) => switch (metric) {
  AnnouncementMetric.altitude => l10n.altitudeAnnouncementMetricAltitude,
  AnnouncementMetric.verticalSpeed =>
    l10n.altitudeAnnouncementMetricVerticalSpeed,
  AnnouncementMetric.groundSpeed => l10n.altitudeAnnouncementMetricGroundSpeed,
  AnnouncementMetric.windSpeed => l10n.altitudeAnnouncementMetricWindSpeed,
  AnnouncementMetric.temperature => l10n.altitudeAnnouncementMetricTemperature,
  AnnouncementMetric.pressure => l10n.altitudeAnnouncementMetricPressure,
  AnnouncementMetric.battery => l10n.altitudeAnnouncementMetricBattery,
  AnnouncementMetric.heartRate => l10n.altitudeAnnouncementMetricHeartRate,
  AnnouncementMetric.heading => l10n.altitudeAnnouncementMetricHeading,
};

String _conditionLabel(
  AppLocalizations l10n,
  AnnouncementCondition condition,
) => switch (condition) {
  AnnouncementCondition.greaterThan =>
    l10n.altitudeAnnouncementConditionGreater,
  AnnouncementCondition.lessThan => l10n.altitudeAnnouncementConditionLess,
  AnnouncementCondition.withinRange => l10n.altitudeAnnouncementConditionRange,
};

String _metricUnit(AnnouncementMetric metric) => switch (metric) {
  AnnouncementMetric.altitude => 'm',
  AnnouncementMetric.verticalSpeed => 'm/s',
  AnnouncementMetric.groundSpeed || AnnouncementMetric.windSpeed => 'km/h',
  AnnouncementMetric.temperature => '°C',
  AnnouncementMetric.pressure => 'hPa',
  AnnouncementMetric.battery => '%',
  AnnouncementMetric.heartRate => 'bpm',
  AnnouncementMetric.heading => '°',
};
