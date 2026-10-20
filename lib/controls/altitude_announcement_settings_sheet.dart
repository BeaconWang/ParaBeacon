import 'package:flutter/material.dart';

import '../audio/altitude_announcement_settings.dart';
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

class _AltitudeAnnouncementSettingsSheet extends StatelessWidget {
  const _AltitudeAnnouncementSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = AltitudeAnnouncementSettings.instance;
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final minimum = settings.minimumLiftSpeed;
        final maximum = settings.maximumLiftSpeed;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
