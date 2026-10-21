import 'package:flutter/widgets.dart';

import '../data/decimal_places.dart';

export '../data/decimal_places.dart' show DecimalPlaceRange, formatDecimalValue;

/// Per-instance number-format settings inherited by a dashboard control face.
class DecimalPlacesScope extends InheritedWidget {
  final Map<String, dynamic> settings;

  const DecimalPlacesScope({
    super.key,
    required this.settings,
    required super.child,
  });

  static DecimalPlaceRange? rangeOf(BuildContext context, String key) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DecimalPlacesScope>();
    return DecimalPlaceRange.parse(scope?.settings[key]);
  }

  @override
  bool updateShouldNotify(DecimalPlacesScope oldWidget) => true;
}
