import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/xcontest_live_tracking_service.dart';
import '../data/live_tracking_settings.dart';
import '../data/parabeacon_account_service.dart';
import '../data/live_tracking_service.dart' as server_tracking;
import '../data/xcontest_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showLiveTrackingSettingsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _LiveTrackingSettingsSheet(),
  );
}

class _LiveTrackingSettingsSheet extends StatefulWidget {
  const _LiveTrackingSettingsSheet();

  @override
  State<_LiveTrackingSettingsSheet> createState() =>
      _LiveTrackingSettingsSheetState();
}

class _LiveTrackingSettingsSheetState
    extends State<_LiveTrackingSettingsSheet> {
  bool _xcontestEnabled = LiveTrackingSettings.instance.xcontestEnabled;
  bool _parabeaconEnabled = LiveTrackingSettings.instance.parabeaconEnabled;
  bool _claimContest = LiveTrackingSettings.instance.claimContest;
  bool _showPublic = LiveTrackingSettings.instance.showPublic;
  bool _flightPublic = LiveTrackingSettings.instance.flightPublic;
  bool _shareLocationPublicly =
      LiveTrackingSettings.instance.shareLocationPublicly;
  bool _shareLocationWhileNotFlying =
      LiveTrackingSettings.instance.shareLocationWhileNotFlying;
  late final TextEditingController _channelNumberController;
  Timer? _channelSaveTimer;
  bool _savingChannelNumber = false;
  bool _channelNumberSaveFailed = false;
  bool _temporaryDontShare = LiveTrackingSettings.instance.temporaryDontShare;
  bool _reportSimulatedAsReal =
      LiveTrackingSettings.instance.reportSimulatedAsReal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final initialChannel =
        ParaBeaconAccountService.instance.user?.channelNumber ?? 0;
    _channelNumberController = TextEditingController(
      text: initialChannel.toString().padLeft(6, '0'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        LiveTrackingSettings.instance.load(),
        XContestAuthService.instance.load(),
        ParaBeaconAccountService.instance.load(),
      ]);
      if (!mounted) return;
      final settings = LiveTrackingSettings.instance;
      setState(() {
        _xcontestEnabled = settings.xcontestEnabled;
        _parabeaconEnabled = settings.parabeaconEnabled;
        _claimContest = settings.claimContest;
        _showPublic = settings.showPublic;
        _flightPublic = settings.flightPublic;
        _shareLocationPublicly = settings.shareLocationPublicly;
        _shareLocationWhileNotFlying = settings.shareLocationWhileNotFlying;
        final channelNumber =
            ParaBeaconAccountService.instance.user?.channelNumber ?? 0;
        _channelNumberController.text = channelNumber.toString().padLeft(
          6,
          '0',
        );
        _temporaryDontShare = settings.temporaryDontShare;
        _reportSimulatedAsReal = settings.reportSimulatedAsReal;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _channelSaveTimer?.cancel();
    _channelNumberController.dispose();
    super.dispose();
  }

  void _scheduleChannelNumberSave(String value) {
    _channelSaveTimer?.cancel();
    if (value.length != 6) return;
    _channelSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveChannelNumber(value));
    });
  }

  Future<void> _saveChannelNumber(String value) async {
    final channelNumber = int.tryParse(value);
    if (channelNumber == null || value.length != 6 || _savingChannelNumber) {
      return;
    }
    final account = ParaBeaconAccountService.instance;
    if (account.user?.channelNumber == channelNumber) return;
    setState(() {
      _savingChannelNumber = true;
      _channelNumberSaveFailed = false;
    });
    final saved = await account.updateChannelNumber(channelNumber);
    if (!mounted) return;
    setState(() {
      _savingChannelNumber = false;
      _channelNumberSaveFailed = !saved;
    });
  }

  Future<void> _save() async {
    await LiveTrackingSettings.instance.save(
      xcontestEnabled: _xcontestEnabled,
      parabeaconEnabled: _parabeaconEnabled,
      claimContest: _claimContest,
      showPublic: _showPublic,
      flightPublic: _flightPublic,
      shareLocationPublicly: _shareLocationPublicly,
      shareLocationWhileNotFlying: _shareLocationWhileNotFlying,
      temporaryDontShare: _temporaryDontShare,
      reportSimulatedAsReal: kDebugMode ? _reportSimulatedAsReal : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = LiveTrackingSettings.instance;
    final auth = XContestAuthService.instance;
    final tracking = XContestLiveTrackingService.instance;
    final serverAccount = ParaBeaconAccountService.instance;
    final serverTracking = server_tracking.LiveTrackingService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        settings,
        auth,
        tracking,
        serverAccount,
        serverTracking,
      ]),
      builder: (context, _) {
        final signedIn = auth.isSignedIn;
        final serverSignedIn = serverAccount.isSignedIn;
        final hasTrackingAccount = signedIn || serverSignedIn;
        final hasSelectedTrackingAccount =
            (settings.xcontestEnabled && signedIn) ||
            (settings.parabeaconEnabled && serverSignedIn);
        final canEnable = hasSelectedTrackingAccount && !_temporaryDontShare;
        final xcontestActiveForUi =
            settings.xcontestEnabled && signedIn && !_temporaryDontShare;
        final flightPublicLocked = tracking.isFlightSessionStarted;
        final String serverMessage;
        if (settings.temporaryDontShare) {
          serverMessage = l10n.liveTrackingServerPaused;
        } else if (!settings.parabeaconEnabled) {
          serverMessage = l10n.liveTrackingServerSyncDisabled;
        } else if (!serverAccount.isSignedIn) {
          serverMessage = l10n.liveTrackingServerAccountRequired;
        } else {
          serverMessage = switch (serverTracking.state) {
            server_tracking.LiveTrackingConnectionState.connecting =>
              l10n.liveTrackingServerConnecting,
            server_tracking.LiveTrackingConnectionState.active =>
              l10n.liveTrackingServerActive,
            server_tracking.LiveTrackingConnectionState.reconnecting =>
              l10n.liveTrackingServerRetrying,
            server_tracking.LiveTrackingConnectionState.disconnected =>
              serverTracking.lastErrorCode == null
                  ? l10n.liveTrackingServerWaiting
                  : l10n.liveTrackingServerFailed,
            server_tracking.LiveTrackingConnectionState.idle =>
              l10n.liveTrackingServerWaiting,
          };
        }
        return Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          l10n.liveTracking,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.liveTracking,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.liveTrackingSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.cloud_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('ParaBeacon'),
                              subtitle: serverSignedIn
                                  ? null
                                  : Text(
                                      l10n.liveTrackingServerAccountRequired,
                                    ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingParaBeaconSync),
                              subtitle: Text(
                                serverSignedIn
                                    ? l10n.liveTrackingParaBeaconSyncSubtitle
                                    : l10n.liveTrackingParaBeaconSignInRequired,
                              ),
                              value: _parabeaconEnabled,
                              onChanged: _loading || !serverSignedIn
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _parabeaconEnabled = value,
                                      );
                                      settings.setParaBeaconEnabled(value);
                                    },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.public),
                              title: Text(
                                l10n.liveTrackingShareLocationPublicly,
                              ),
                              subtitle: Text(
                                l10n.liveTrackingShareLocationPubliclySubtitle,
                              ),
                              value: _shareLocationPublicly,
                              onChanged: _loading || !serverSignedIn
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _shareLocationPublicly = value,
                                      );
                                      settings.setShareLocationPublicly(value);
                                    },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.near_me_outlined),
                              title: Text(
                                l10n.liveTrackingShareLocationWhileNotFlying,
                              ),
                              subtitle: Text(
                                l10n.liveTrackingShareLocationWhileNotFlyingSubtitle,
                              ),
                              value: _shareLocationWhileNotFlying,
                              onChanged:
                                  _loading ||
                                      !serverSignedIn ||
                                      !_parabeaconEnabled ||
                                      !_shareLocationPublicly
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _shareLocationWhileNotFlying =
                                            value,
                                      );
                                      settings.setShareLocationWhileNotFlying(
                                        value,
                                      );
                                    },
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: TextField(
                                key: const ValueKey('channel-number'),
                                controller: _channelNumberController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                maxLength: 6,
                                enabled:
                                    !_loading &&
                                    serverSignedIn &&
                                    !_savingChannelNumber,
                                decoration: InputDecoration(
                                  labelText: l10n.liveTrackingChannelNumber,
                                  helperText:
                                      l10n.liveTrackingChannelNumberSubtitle,
                                  errorText: _channelNumberSaveFailed
                                      ? l10n.liveTrackingChannelNumberSaveFailed
                                      : null,
                                  suffixIcon: _savingChannelNumber
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : null,
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(
                                    () => _channelNumberSaveFailed = false,
                                  );
                                  _scheduleChannelNumberSave(value);
                                },
                                onSubmitted: _saveChannelNumber,
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                Icons.cloud_upload_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(l10n.liveTrackingServerTitle),
                              subtitle: Text(serverMessage),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.flight_takeoff_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('XContest'),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingXContestSync),
                              subtitle: Text(
                                signedIn
                                    ? l10n.liveTrackingXContestSyncSubtitle
                                    : l10n.liveTrackingXContestSignInRequired,
                              ),
                              value: _xcontestEnabled,
                              onChanged: _loading || !signedIn
                                  ? null
                                  : (value) {
                                      setState(() => _xcontestEnabled = value);
                                      settings.setXContestEnabled(value);
                                    },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingClaimContest),
                              subtitle: Text(
                                flightPublicLocked
                                    ? l10n.liveTrackingClaimContestLockedSubtitle
                                    : l10n.liveTrackingClaimContestSubtitle,
                              ),
                              value: _claimContest,
                              onChanged:
                                  _loading || !signedIn || flightPublicLocked
                                  ? null
                                  : (value) =>
                                        setState(() => _claimContest = value),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingShowPublic),
                              subtitle: Text(
                                l10n.liveTrackingShowPublicSubtitle,
                              ),
                              value: _showPublic,
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                      setState(() => _showPublic = value);
                                      LiveTrackingSettings.instance
                                          .setShowPublic(value);
                                    },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingFlightPublic),
                              subtitle: Text(
                                flightPublicLocked
                                    ? l10n.liveTrackingFlightPublicLockedSubtitle
                                    : l10n.liveTrackingFlightPublicSubtitle,
                              ),
                              value: _flightPublic,
                              onChanged:
                                  _loading || !signedIn || flightPublicLocked
                                  ? null
                                  : (value) =>
                                        setState(() => _flightPublic = value),
                            ),
                            if (kDebugMode) ...[
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.science_outlined),
                                title: const Text('Report simulated as real'),
                                subtitle: const Text(
                                  'Debug only: upload simulated locations without '
                                  'the "simulation" flag, so XContest treats the '
                                  'flight as real.',
                                ),
                                value: _reportSimulatedAsReal,
                                onChanged: _loading
                                    ? null
                                    : (value) => setState(
                                        () => _reportSimulatedAsReal = value,
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: _temporaryDontShare
                            ? theme.colorScheme.errorContainer
                            : null,
                        child: SwitchListTile(
                          title: Text(l10n.liveTrackingTemporaryDisable),
                          subtitle: Text(
                            l10n.liveTrackingTemporaryDisableSubtitle,
                          ),
                          value: _temporaryDontShare,
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(() => _temporaryDontShare = value);
                                  // Apply + persist immediately so the pause
                                  // takes effect without waiting for Save.
                                  LiveTrackingSettings.instance
                                      .setTemporaryDontShare(value);
                                },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!hasTrackingAccount)
                        _StatusMessage(
                          icon: Icons.account_circle_outlined,
                          message: l10n.liveTrackingRequiresXContest,
                        )
                      else if (_temporaryDontShare)
                        _StatusMessage(
                          icon: Icons.pause_circle_outline,
                          message: l10n.liveTrackingTemporarilyDisabled,
                        )
                      else if (!hasSelectedTrackingAccount)
                        _StatusMessage(
                          icon: Icons.cloud_off_outlined,
                          message: l10n.liveTrackingNoDestinationSelected,
                        )
                      else if (xcontestActiveForUi && !tracking.isConfigured)
                        _StatusMessage(
                          icon: Icons.settings_outlined,
                          message: l10n.liveTrackingConfigInvalid,
                        )
                      else if (xcontestActiveForUi &&
                          tracking.state ==
                              LiveTrackingConnectionState.connecting)
                        _StatusMessage(
                          icon: Icons.cloud_sync_outlined,
                          message: l10n.liveTrackingConnecting,
                        )
                      else if (xcontestActiveForUi &&
                          tracking.state == LiveTrackingConnectionState.active)
                        _StatusMessage(
                          icon: Icons.cloud_done_outlined,
                          message: l10n.liveTrackingConnected,
                        )
                      else if (xcontestActiveForUi &&
                          tracking.state ==
                              LiveTrackingConnectionState.reconnecting)
                        _StatusMessage(
                          icon: Icons.cloud_sync_outlined,
                          message: l10n.liveTrackingRetrying,
                        )
                      else if (xcontestActiveForUi &&
                          tracking.state ==
                              LiveTrackingConnectionState.disconnected &&
                          tracking.lastErrorCode != null)
                        _StatusMessage(
                          icon: Icons.error_outline,
                          message: l10n.liveTrackingFailed,
                        )
                      else if (canEnable)
                        _StatusMessage(
                          icon: Icons.check_circle_outline,
                          message: l10n.liveTrackingReady,
                        ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loading || settings.isSaving ? null : _save,
                        icon: settings.isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          settings.isSaving ? l10n.saving : l10n.save,
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 24),
                        _DebugLogPanel(tracking: tracking),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

/// Debug-only tail of the live-tracking lifecycle log. Rebuilds with the
/// service (which notifies on every logged line); newest line stays in view.
class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel({required this.tracking});

  final XContestLiveTrackingService tracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = tracking.debugLog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Debug log (${lines.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: lines.isEmpty
              ? Text(
                  'No events yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    lines.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
