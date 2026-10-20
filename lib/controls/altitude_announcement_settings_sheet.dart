import 'package:flutter/material.dart';

import '../audio/altitude_announcement_bridge.dart';
import '../audio/altitude_announcement_settings.dart';
import '../audio/altitude_announcement_speaker.dart';
import '../audio/announcement_template.dart';
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

class _AltitudeAnnouncementSettingsSheet extends StatefulWidget {
  const _AltitudeAnnouncementSettingsSheet();

  @override
  State<_AltitudeAnnouncementSettingsSheet> createState() =>
      _AltitudeAnnouncementSettingsSheetState();
}

class _AltitudeAnnouncementSettingsSheetState
    extends State<_AltitudeAnnouncementSettingsSheet> {
  bool _testing = false;
  bool? _lastTestSucceeded;
  late final TextEditingController _templateController = TextEditingController(
    text: AltitudeAnnouncementSettings.instance.template ?? '',
  );

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  void _onTemplateChanged(String value) {
    AltitudeAnnouncementSettings.instance.setTemplate(value);
  }

  void _insertPlaceholder(AnnouncementPlaceholder placeholder) {
    final value = _templateController.value;
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
    _templateController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _onTemplateChanged(next);
  }

  void _resetTemplate() {
    _templateController.clear();
    _onTemplateChanged('');
  }

  static String _placeholderLabel(
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
  };

  Future<void> _runTest() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _lastTestSucceeded = null;
    });
    final ok = await speakAltitudeAnnouncementTest();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastTestSucceeded = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AltitudeAnnouncementSettings.instance;
    final speaker = AltitudeAnnouncementSpeaker.instance;
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([settings, speaker]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final minimum = settings.minimumLiftSpeed;
        final maximum = settings.maximumLiftSpeed;
        final unavailable =
            _lastTestSucceeded == false ||
            (_lastTestSucceeded == null &&
                speaker.availability == SpeechAvailability.unavailable);
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
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.altitudeAnnouncementEnabled),
                  subtitle: Text(l10n.altitudeAnnouncementEnabledDescription),
                  value: settings.enabled,
                  onChanged: settings.setEnabled,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.altitudeAnnouncementLiftRange,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.altitudeAnnouncementRangeDescription(
                    minimum.toStringAsFixed(1),
                    maximum.toStringAsFixed(1),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                RangeSlider(
                  values: RangeValues(minimum, maximum),
                  min: 0.1,
                  max: 6.0,
                  divisions: 59,
                  labels: RangeLabels(
                    minimum.toStringAsFixed(1),
                    maximum.toStringAsFixed(1),
                  ),
                  onChanged: settings.enabled
                      ? (values) =>
                            settings.setLiftSpeedRange(values.start, values.end)
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.altitudeAnnouncementTemplate,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: settings.template == null
                          ? null
                          : _resetTemplate,
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
                  controller: _templateController,
                  onChanged: _onTemplateChanged,
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
                const SizedBox(height: 8),
                Text(
                  l10n.altitudeAnnouncementTemplatePreview(
                    renderAnnouncement(
                      settings.template,
                      announcementLanguageFor(settings.template),
                      AnnouncementValues.sample,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _runTest,
                  icon: _testing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up),
                  label: Text(l10n.altitudeAnnouncementTest),
                ),
                if (_lastTestSucceeded == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.altitudeAnnouncementTestSuccess,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ] else if (unavailable) ...[
                  const SizedBox(height: 8),
                  Row(
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
                          l10n.altitudeAnnouncementUnavailable,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
