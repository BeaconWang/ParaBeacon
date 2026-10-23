import 'package:flutter/material.dart';

import '../data/display_settings.dart';
import '../l10n/app_localizations.dart';

Future<void> showDisplaySettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _DisplaySettingsSheet(),
  );
}

class _DisplaySettingsSheet extends StatelessWidget {
  const _DisplaySettingsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.displaySettings, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: DisplaySettings.instance,
              builder: (context, _) => Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.defaultPrecision),
                    subtitle: Text(l10n.defaultPrecisionDescription),
                    value: DisplaySettings.instance.defaultPrecisionEnabled,
                    onChanged:
                        DisplaySettings.instance.setDefaultPrecisionEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.largerFont),
                    subtitle: Text(l10n.largerFontDescription),
                    value: DisplaySettings.instance.largerFontEnabled,
                    onChanged: DisplaySettings.instance.setLargerFontEnabled,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
