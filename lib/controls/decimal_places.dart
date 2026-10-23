import 'package:flutter/widgets.dart';

import '../data/decimal_places.dart';

export '../data/decimal_places.dart' show DecimalPlaceRange, formatDecimalValue;

/// Per-instance number-format settings inherited by a dashboard control face.
class DecimalPlacesScope extends InheritedWidget {
  final Map<String, dynamic> settings;
  final String controlTypeId;
  final bool defaultPrecisionEnabled;

  const DecimalPlacesScope({
    super.key,
    required this.settings,
    required this.controlTypeId,
    required this.defaultPrecisionEnabled,
    required super.child,
  });

  static DecimalPlaceRange? rangeOf(BuildContext context, String key) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DecimalPlacesScope>();
    final configured = DecimalPlaceRange.parse(scope?.settings[key]);
    if (configured != null) return configured;
    if (scope == null) return null;
    final decimals = defaultDecimalPlacesForControl(
      scope.controlTypeId,
      key,
      scope.defaultPrecisionEnabled,
    );
    return decimals == null ? null : DecimalPlaceRange(decimals, decimals);
  }

  @override
  bool updateShouldNotify(DecimalPlacesScope oldWidget) => true;
}
