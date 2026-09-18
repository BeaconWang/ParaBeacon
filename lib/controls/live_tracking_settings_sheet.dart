import 'package:flutter/material.dart';

import '../data/live_tracking_settings.dart';
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
  bool _enabled = LiveTrackingSettings.instance.enabled;
  bool _claimContest = LiveTrackingSettings.instance.claimContest;
  bool _showPublic = LiveTrackingSettings.instance.showPublic;
  bool _flightPublic = LiveTrackingSettings.instance.flightPublic;
  bool _temporaryDontShare = LiveTrackingSettings.instance.temporaryDontShare;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        LiveTrackingSettings.instance.load(),
        XContestAuthService.instance.load(),
      ]);
      if (!mounted) return;
      final settings = LiveTrackingSettings.instance;
      setState(() {
        _enabled = settings.enabled;
        _claimContest = settings.claimContest;
        _showPublic = settings.showPublic;
        _flightPublic = settings.flightPublic;
        _temporaryDontShare = settings.temporaryDontShare;
        _loading = false;
      });
    });
  }

  Future<void> _save() async {
    await LiveTrackingSettings.instance.save(
      enabled: _enabled,
      claimContest: _claimContest,
      showPublic: _showPublic,
      flightPublic: _flightPublic,
      temporaryDontShare: _temporaryDontShare,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = LiveTrackingSettings.instance;
    final auth = XContestAuthService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([settings, auth]),
      builder: (context, _) {
        final signedIn = auth.isSignedIn;
        final canEnable = signedIn && !_temporaryDontShare;
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
                            SwitchListTile(
                              title: Text(l10n.liveTrackingEnabled),
                              subtitle: Text(
                                signedIn
                                    ? l10n.liveTrackingEnabledSubtitle
                                    : l10n.liveTrackingRequiresXContest,
                              ),
                              value: _enabled,
                              onChanged: _loading || !signedIn
                                  ? null
                                  : (value) => setState(() => _enabled = value),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingClaimContest),
                              subtitle: Text(
                                l10n.liveTrackingClaimContestSubtitle,
                              ),
                              value: _claimContest,
                              onChanged: _loading || !signedIn
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
                                  : (value) =>
                                        setState(() => _showPublic = value),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.liveTrackingFlightPublic),
                              subtitle: Text(
                                l10n.liveTrackingFlightPublicSubtitle,
                              ),
                              value: _flightPublic,
                              onChanged: _loading
                                  ? null
                                  : (value) =>
                                        setState(() => _flightPublic = value),
                            ),
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
                              : (value) =>
                                    setState(() => _temporaryDontShare = value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!signedIn)
                        _StatusMessage(
                          icon: Icons.account_circle_outlined,
                          message: l10n.liveTrackingRequiresXContest,
                        )
                      else if (_temporaryDontShare)
                        _StatusMessage(
                          icon: Icons.pause_circle_outline,
                          message: l10n.liveTrackingTemporarilyDisabled,
                        )
                      else if (canEnable && _enabled)
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
