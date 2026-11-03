import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/competition/competition_task.dart';
import '../l10n/app_localizations.dart';

/// Shows the active task as an XCTrack-compatible QR code (`XCTSK:` + compact
/// JSON), which other XCTrack / XCTSK apps can scan to load the task.
Future<void> showCompetitionTaskQr(
  BuildContext context,
  CompetitionTask task,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _TaskQrSheet(task: task),
  );
}

class _TaskQrSheet extends StatelessWidget {
  const _TaskQrSheet({required this.task});

  final CompetitionTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final code = task.toTaskCode();
    final size = MediaQuery.of(context).size;
    final qrSize = (size.width < size.height ? size.width : size.height) * 0.72;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.name.isEmpty
                        ? l10n.competitionShowQr
                        : task.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: qrSize.clamp(180.0, 420.0),
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                // The compact payload can be long; fail gracefully if it cannot
                // fit a QR symbol rather than throwing.
                errorStateBuilder: (context, error) => SizedBox(
                  width: qrSize.clamp(180.0, 420.0),
                  height: qrSize.clamp(180.0, 420.0),
                  child: Center(
                    child: Text(
                      l10n.competitionQrTooBig,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.competitionShowQrHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.competitionCodeCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l10n.competitionCopyCode),
            ),
          ],
        ),
      ),
    );
  }
}
