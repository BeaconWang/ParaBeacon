import 'package:flutter/material.dart';

import '../data/asfc_auth_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showPilotTrainingRecordsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _PilotTrainingRecordsSheet(),
  );
}

class _PilotTrainingRecordsSheet extends StatefulWidget {
  const _PilotTrainingRecordsSheet();

  @override
  State<_PilotTrainingRecordsSheet> createState() =>
      _PilotTrainingRecordsSheetState();
}

class _PilotTrainingRecordsSheetState
    extends State<_PilotTrainingRecordsSheet> {
  final _auth = AsfcAuthService.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_handleAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _auth.load();
      if (!mounted || !_auth.isSignedIn) return;
      await _auth.loadPilotTrainingRecords(force: true);
    });
  }

  void _handleAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    await _auth.loadPilotTrainingRecords(force: true);
  }

  Widget _field(String label, String value, TextTheme textTheme) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _recordCard(
    BuildContext context,
    PilotTrainingRecord record,
    AppLocalizations l10n,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final subject = record.trainingSubject.trim().isEmpty
        ? l10n.pilotTrainingSubject
        : record.trainingSubject;
    final venueHeight = record.venueHeight.trim().isEmpty
        ? ''
        : '${record.venueHeight} ${l10n.pilotTrainingMetersUnit}';
    final airbornePeriod = record.airbornePeriod.trim().isEmpty
        ? ''
        : '${record.airbornePeriod} ${l10n.pilotTrainingMinutesUnit}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.pilotTrainingDate}: ${record.trainDate}',
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(subject, style: textTheme.titleMedium),
            _field(l10n.pilotTrainingLocation, record.address, textTheme),
            _field(l10n.pilotTrainingVenueHeight, venueHeight, textTheme),
            _field(
              l10n.pilotTrainingWindDirection,
              record.windDirection,
              textTheme,
            ),
            _field(l10n.pilotTrainingWindSpeed, record.windSpeed, textTheme),
            _field(
              l10n.pilotTrainingNumberOfTimes,
              record.numberOfTimes.toString(),
              textTheme,
            ),
            _field(l10n.pilotTrainingAirbornePeriod, airbornePeriod, textTheme),
            _field(l10n.pilotTrainingResult, record.trainResultName, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(
    String message,
    AppLocalizations l10n, {
    bool showRetry = true,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (showRetry) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.pilotTrainingRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final records = _auth.pilotTrainingRecords;
    final signedIn = _auth.isSignedIn;
    final loading = _auth.isPilotTrainingRecordsLoading;
    final failed = _auth.hasPilotTrainingRecordsError;

    Widget content;
    if (!signedIn) {
      content = _emptyState(
        l10n.pilotTrainingSignInRequired,
        l10n,
        showRetry: false,
      );
    } else if (loading && records.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (failed && records.isEmpty) {
      content = _emptyState(l10n.pilotTrainingLoadFailed, l10n);
    } else if (records.isEmpty) {
      content = _emptyState(l10n.pilotTrainingNoRecords, l10n);
    } else {
      content = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.pilotTrainingLoadFailed,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            for (final record in records) _recordCard(context, record, l10n),
          ],
        ),
      );
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      l10n.pilotTrainingRecords,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.refresh,
                    onPressed: loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (loading && records.isNotEmpty) const LinearProgressIndicator(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
