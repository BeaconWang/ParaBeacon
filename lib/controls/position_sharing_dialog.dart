import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum PositionSharingChoice { share, disable, timedOut }

class PositionSharingResult {
  const PositionSharingResult({
    required this.choice,
    required this.syncToXContest,
    required this.syncToParaBeacon,
  });

  final PositionSharingChoice choice;
  final bool syncToXContest;
  final bool syncToParaBeacon;
}

Future<PositionSharingResult?> showPositionSharingDialog(
  BuildContext context, {
  required bool xcontestSignedIn,
  required bool paraBeaconSignedIn,
  required bool initialXContestSync,
  required bool initialParaBeaconSync,
  Duration timeout = const Duration(seconds: 5),
}) {
  return showDialog<PositionSharingResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PositionSharingDialog(
      timeout: timeout,
      xcontestSignedIn: xcontestSignedIn,
      paraBeaconSignedIn: paraBeaconSignedIn,
      initialXContestSync: initialXContestSync,
      initialParaBeaconSync: initialParaBeaconSync,
    ),
  );
}

class _PositionSharingDialog extends StatefulWidget {
  const _PositionSharingDialog({
    required this.timeout,
    required this.xcontestSignedIn,
    required this.paraBeaconSignedIn,
    required this.initialXContestSync,
    required this.initialParaBeaconSync,
  });

  final Duration timeout;
  final bool xcontestSignedIn;
  final bool paraBeaconSignedIn;
  final bool initialXContestSync;
  final bool initialParaBeaconSync;

  @override
  State<_PositionSharingDialog> createState() => _PositionSharingDialogState();
}

class _PositionSharingDialogState extends State<_PositionSharingDialog> {
  Timer? _timer;
  late int _secondsRemaining;
  late bool _syncToXContest;
  late bool _syncToParaBeacon;

  bool get _hasSelectedDestination => _syncToXContest || _syncToParaBeacon;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeout.inSeconds;
    _syncToXContest = widget.xcontestSignedIn && widget.initialXContestSync;
    _syncToParaBeacon =
        widget.paraBeaconSignedIn && widget.initialParaBeaconSync;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        _finish(PositionSharingChoice.timedOut);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _finish(PositionSharingChoice choice) {
    Navigator.of(context).pop(
      PositionSharingResult(
        choice: choice,
        syncToXContest: _syncToXContest,
        syncToParaBeacon: _syncToParaBeacon,
      ),
    );
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
                child: ListView(
                  children: [
                    Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _hasSelectedDestination
                            ? () => _finish(PositionSharingChoice.share)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 52,
                                color: _hasSelectedDestination
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.positionSharingShareAction,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l10n.positionSharingCountdown(
                                  _secondsRemaining,
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.positionSharingPromptBody,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (!_hasSelectedDestination) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.liveTrackingNoDestinationSelected,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            key: const ValueKey('positionSharingXContest'),
                            title: Text(l10n.liveTrackingXContestSync),
                            subtitle: Text(
                              widget.xcontestSignedIn
                                  ? l10n.liveTrackingXContestSyncSubtitle
                                  : l10n.liveTrackingXContestSignInRequired,
                            ),
                            value: _syncToXContest,
                            onChanged: widget.xcontestSignedIn
                                ? (value) =>
                                      setState(() => _syncToXContest = value)
                                : null,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            key: const ValueKey('positionSharingParaBeacon'),
                            title: Text(l10n.liveTrackingParaBeaconSync),
                            subtitle: Text(
                              widget.paraBeaconSignedIn
                                  ? l10n.liveTrackingParaBeaconSyncSubtitle
                                  : l10n.liveTrackingParaBeaconSignInRequired,
                            ),
                            value: _syncToParaBeacon,
                            onChanged: widget.paraBeaconSignedIn
                                ? (value) =>
                                      setState(() => _syncToParaBeacon = value)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _finish(PositionSharingChoice.disable),
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
