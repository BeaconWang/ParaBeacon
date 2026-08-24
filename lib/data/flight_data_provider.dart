import 'package:flutter/widgets.dart';

import 'flight_data.dart';
import 'flight_data_source.dart';

/// Provides a [FlightDataSource] to the widget subtree and rebuilds dependents
/// whenever the source notifies (i.e. new [FlightData] arrives).
///
/// Controls read the latest data with:
/// ```dart
/// final data = FlightDataProvider.of(context);
/// ```
class FlightDataProvider extends InheritedNotifier<FlightDataSource> {
  const FlightDataProvider({
    super.key,
    required FlightDataSource source,
    required super.child,
  }) : super(notifier: source);

  /// The data source itself (does not subscribe to rebuilds).
  static FlightDataSource sourceOf(BuildContext context) {
    final provider =
        context.getInheritedWidgetOfExactType<FlightDataProvider>();
    assert(provider != null, 'No FlightDataProvider found in context');
    return provider!.notifier!;
  }

  /// The latest [FlightData], subscribing the caller to rebuilds on change.
  static FlightData of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FlightDataProvider>();
    assert(provider != null, 'No FlightDataProvider found in context');
    return provider!.notifier!.data;
  }
}
