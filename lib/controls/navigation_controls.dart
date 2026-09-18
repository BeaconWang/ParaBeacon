import 'package:flutter/material.dart';

import '../data/airspace_alert_service.dart';
import '../data/navigation_store.dart';
import '../l10n/app_localizations.dart';
import 'data_value_control.dart';

class NavigationTaskControl extends StatelessWidget {
  const NavigationTaskControl({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NavigationStore.instance,
      builder: (context, _) {
        final snapshot = NavigationStore.instance.snapshot;
        final target = snapshot.target;
        final l10n = AppLocalizations.of(context);
        if (target == null) {
          return DataValueControl(
            title: l10n.controlNavigationTask,
            value: '--',
            unit: '',
            showTitle: showTitle,
          );
        }
        final distance = snapshot.distanceM;
        final value = distance == null
            ? target.name
            : '${_formatDistance(distance)}  ${snapshot.bearingDeg?.round() ?? 0}°';
        return DataValueControl(
          title: '${l10n.controlNavigationTask}: ${target.name}',
          value: value,
          unit: '',
          showTitle: showTitle,
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }
}

class AirspaceAlertControl extends StatelessWidget {
  const AirspaceAlertControl({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AirspaceAlertService.instance,
      builder: (context, _) {
        final alert = AirspaceAlertService.instance.highest;
        final l10n = AppLocalizations.of(context);
        final value = alert == null
            ? l10n.airspaceAlertClear
            : alert.isInside
            ? '${l10n.airspaceAlertInside}: ${alert.proximity.airspace.name}'
            : '${l10n.airspaceAlertNear}: ${alert.proximity.airspace.name}';
        return DataValueControl(
          title: l10n.controlAirspaceAlert,
          value: value,
          unit: '',
          state: alert == null ? ValueState.good : ValueState.bad,
          showTitle: showTitle,
        );
      },
    );
  }
}
