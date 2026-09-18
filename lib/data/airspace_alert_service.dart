import 'dart:async';

import 'package:flutter/foundation.dart';

import 'airspace_store.dart';

enum AirspaceAlertKind { near, inside }

@immutable
class AirspaceAlert {
  const AirspaceAlert({required this.proximity, required this.kind});

  final AirspaceProximity proximity;
  final AirspaceAlertKind kind;

  bool get isInside => kind == AirspaceAlertKind.inside;
}

/// Converts airspace proximity updates into de-duplicated safety state.
///
/// The service is intentionally presentation-agnostic: audio, vibration and
/// visual controls can all subscribe to the same active alert list without
/// each implementing their own threshold and hysteresis logic.
class AirspaceAlertService extends ChangeNotifier {
  AirspaceAlertService._();
  static final AirspaceAlertService instance = AirspaceAlertService._();

  StreamSubscription<List<AirspaceProximity>>? _subscription;
  List<AirspaceAlert> _active = const [];

  /// Horizontal warning distance by airspace severity, in meters.
  final Map<AirspaceSeverity, double> warningDistanceM = const {
    AirspaceSeverity.high: 1500,
    AirspaceSeverity.medium: 1000,
    AirspaceSeverity.low: 500,
  };

  /// Vertical separation at which a nearby airspace becomes relevant.
  double verticalMarginM = 300;

  List<AirspaceAlert> get active => List.unmodifiable(_active);
  AirspaceAlert? get highest => _active.isEmpty ? null : _active.first;

  void attach() {
    _subscription?.cancel();
    _subscription = AirspaceStore.instance.proximityStream.listen(_update);
    _update(AirspaceStore.instance.lastProximity);
  }

  void _update(List<AirspaceProximity> proximities) {
    final next = <AirspaceAlert>[];
    for (final proximity in proximities) {
      final threshold = warningDistanceM[proximity.airspace.severity] ?? 500;
      final relevantVertically = proximity.verticalM <= verticalMarginM;
      if (proximity.inside) {
        next.add(
          AirspaceAlert(proximity: proximity, kind: AirspaceAlertKind.inside),
        );
      } else if (relevantVertically && proximity.horizontalM <= threshold) {
        next.add(
          AirspaceAlert(proximity: proximity, kind: AirspaceAlertKind.near),
        );
      }
    }
    next.sort((a, b) {
      final inside = (b.isInside ? 1 : 0) - (a.isInside ? 1 : 0);
      if (inside != 0) return inside;
      final severity =
          _severityRank(b.proximity.airspace.severity) -
          _severityRank(a.proximity.airspace.severity);
      if (severity != 0) return severity;
      return a.proximity.horizontalM.compareTo(b.proximity.horizontalM);
    });
    if (_sameAlerts(_active, next)) return;
    _active = List.unmodifiable(next);
    notifyListeners();
  }

  int _severityRank(AirspaceSeverity severity) {
    switch (severity) {
      case AirspaceSeverity.high:
        return 3;
      case AirspaceSeverity.medium:
        return 2;
      case AirspaceSeverity.low:
        return 1;
    }
  }

  bool _sameAlerts(List<AirspaceAlert> a, List<AirspaceAlert> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].proximity.airspace.name != b[i].proximity.airspace.name ||
          a[i].kind != b[i].kind ||
          (a[i].proximity.horizontalM - b[i].proximity.horizontalM).abs() >
              25) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
