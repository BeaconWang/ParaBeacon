import 'package:flutter/widgets.dart';

import 'flight_data.dart';
import 'raw_flight_data_source.dart';
import 'flight_data_transformer.dart';

/// Provides the [FlightDataTransformer] (the *data-transform layer*) to the
/// widget subtree and rebuilds dependents whenever it notifies (i.e. new
/// transformed [FlightData] is available).
///
/// Pipeline:
/// ```
/// [control] <- [FlightDataTransformer] <- [RawFlightDataSource] <- [raw data]
/// ```
///
/// Controls read the latest *transformed* data with:
/// ```dart
/// final data = FlightDataProvider.of(context);
/// ```
///
/// Debug controls that need to write into the *raw data layer* (e.g. installing
/// a vertical-speed override) reach it via [FlightDataProvider.sourceOf].
class FlightDataProvider extends InheritedNotifier<FlightDataTransformer> {
  const FlightDataProvider({
    super.key,
    required FlightDataTransformer transformer,
    required super.child,
  }) : super(notifier: transformer);

  /// The data-transform layer itself (does not subscribe to rebuilds).
  static FlightDataTransformer transformerOf(BuildContext context) {
    final provider =
        context.getInheritedWidgetOfExactType<FlightDataProvider>();
    assert(provider != null, 'No FlightDataProvider found in context');
    return provider!.notifier!;
  }

  /// The underlying raw data source (does not subscribe to rebuilds). Used by
  /// debug controls to install/clear overrides at the raw layer.
  static RawFlightDataSource sourceOf(BuildContext context) {
    return transformerOf(context).rawSource;
  }

  /// The latest transformed [FlightData], subscribing the caller to rebuilds on
  /// change.
  static FlightData of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FlightDataProvider>();
    assert(provider != null, 'No FlightDataProvider found in context');
    return provider!.notifier!.data;
  }
}
