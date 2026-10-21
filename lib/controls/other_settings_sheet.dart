import 'package:flutter/material.dart';

import '../data/share_card_settings.dart';
import '../l10n/app_localizations.dart';

Future<void> showOtherSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _OtherSettingsSheet(),
  );
}

class _OtherSettingsSheet extends StatelessWidget {
  const _OtherSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ShareCardSettings.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.more_horiz, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(l10n.otherSettings, style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.otherSettingsSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.layers_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.shareCardFlatDesign),
                  subtitle: Text(l10n.shareCardFlatDesignSubtitle),
                  value: ShareCardSettings.instance.flatDesign,
                  onChanged: ShareCardSettings.instance.setFlatDesign,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
