import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum PositionSharingChoice { share, disable, timedOut }

Future<PositionSharingChoice?> showPositionSharingDialog(
  BuildContext context, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return showDialog<PositionSharingChoice>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PositionSharingDialog(timeout: timeout),
  );
}

class _PositionSharingDialog extends StatefulWidget {
  const _PositionSharingDialog({required this.timeout});

  final Duration timeout;

  @override
  State<_PositionSharingDialog> createState() => _PositionSharingDialogState();
}

class _PositionSharingDialogState extends State<_PositionSharingDialog> {
  Timer? _timer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeout.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        Navigator.of(context).pop(PositionSharingChoice.timedOut);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height - 48;
    final dialogHeight = math.min(700.0, availableHeight).clamp(280.0, 700.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 640,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l10n.positionSharingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              Expanded(
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        Navigator.of(context).pop(PositionSharingChoice.share),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 52,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.positionSharingShareAction,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.positionSharingCountdown(_secondsRemaining),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.positionSharingPromptBody,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(PositionSharingChoice.disable),
                  icon: const Icon(Icons.location_off_outlined),
                  label: Text(l10n.positionSharingDisableAction),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.positionSharingDisableSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
