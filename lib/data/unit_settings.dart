import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Physical quantity families supported by dashboard controls.
enum UnitDimension {
  altitude,
  speed,
  verticalSpeed,
  distance,
  pressure,
  temperature,
}

extension UnitDimensionLabels on UnitDimension {
  String get storageKey => switch (this) {
        UnitDimension.altitude => 'altitude',
        UnitDimension.speed => 'speed',
        UnitDimension.verticalSpeed => 'vertical_speed',
        UnitDimension.distance => 'distance',
        UnitDimension.pressure => 'pressure',
        UnitDimension.temperature => 'temperature',
      };

  String get defaultUnit => switch (this) {
        UnitDimension.altitude => 'm',
        UnitDimension.speed => 'kmh',
        UnitDimension.verticalSpeed => 'ms',
        UnitDimension.distance => 'auto',
        UnitDimension.pressure => 'hpa',
        UnitDimension.temperature => 'c',
      };

  List<String> get choices => switch (this) {
        UnitDimension.altitude => const ['m', 'ft'],
        UnitDimension.speed => const ['kmh', 'ms', 'mph', 'kn'],
        UnitDimension.verticalSpeed => const ['ms', 'fpm'],
        UnitDimension.distance => const ['auto', 'km', 'mi', 'm', 'ft'],
        UnitDimension.pressure => const ['hpa', 'inhg'],
        UnitDimension.temperature => const ['c', 'f'],
      };
}

/// Converts and labels values for the dashboard's canonical data units.
class UnitValues {
  static double convert(double value, UnitDimension dimension, String unit) {
    switch (dimension) {
      case UnitDimension.altitude:
        return unit == 'ft' ? value * 3.280839895 : value;
      case UnitDimension.speed:
        return switch (unit) {
          'ms' => value / 3.6,
          'mph' => value / 1.609344,
          'kn' => value / 1.852,
          _ => value,
        };
      case UnitDimension.verticalSpeed:
        return unit == 'fpm' ? value * 196.8503937 : value;
      case UnitDimension.distance:
        return switch (unit) {
          'm' => value,
          'ft' => value * 3.280839895,
          'mi' => value / 1609.344,
          _ => value / 1000.0,
        };
      case UnitDimension.pressure:
        return unit == 'inhg' ? value * 0.0295299830714 : value;
      case UnitDimension.temperature:
        return unit == 'f' ? value * 1.8 + 32.0 : value;
    }
  }

  static String formatDistance(double meters, String unit) {
    if (unit == 'auto') {
      if (meters < 1000) return meters.toStringAsFixed(0);
      final kilometers = meters / 1000.0;
      return kilometers.toStringAsFixed(kilometers >= 100 ? 0 : 1);
    }
    final converted = convert(meters, UnitDimension.distance, unit);
    return converted.toStringAsFixed(converted >= 100 ? 0 : 1);
  }

  static String formatAltitudeDifference(double meters, String unit) {
    final value = convert(meters, UnitDimension.altitude, unit).round();
    return value >= 0 ? '+$value' : '$value';
  }

  static String symbol(UnitDimension dimension, String unit) {
    switch (dimension) {
      case UnitDimension.altitude:
        return unit == 'ft' ? 'ft' : 'm';
      case UnitDimension.speed:
        return switch (unit) {
          'ms' => 'm/s',
          'mph' => 'mph',
          'kn' => 'kn',
          _ => 'km/h',
        };
      case UnitDimension.verticalSpeed:
        return unit == 'fpm' ? 'ft/min' : 'm/s';
      case UnitDimension.distance:
        return switch (unit) {
          'm' => 'm',
          'ft' => 'ft',
          'mi' => 'mi',
          _ => 'km',
        };
      case UnitDimension.pressure:
        return unit == 'inhg' ? 'inHg' : 'hPa';
      case UnitDimension.temperature:
        return unit == 'f' ? '°F' : '°C';
    }
  }

  static String label(UnitDimension dimension, String unit) {
    final suffix = symbol(dimension, unit);
    if (dimension == UnitDimension.distance && unit == 'auto') {
      return 'Automatic (m/km)';
    }
    return suffix;
  }
}

/// Persisted app-wide defaults for physical units.
class UnitSettings extends ChangeNotifier {
  UnitSettings._();
  static final UnitSettings instance = UnitSettings._();

  static const _prefix = 'pb.units.default.';
  final Map<UnitDimension, String> _defaults = {
    for (final dimension in UnitDimension.values) dimension: dimension.defaultUnit,
  };
  bool _loaded = false;

  String defaultUnit(UnitDimension dimension) => _defaults[dimension]!;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      for (final dimension in UnitDimension.values) {
        final saved = sp.getString('$_prefix${dimension.storageKey}');
        if (saved != null && dimension.choices.contains(saved)) {
          _defaults[dimension] = saved;
        }
      }
    } catch (_) {
      // Keep metric defaults if storage is unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefault(UnitDimension dimension, String unit) async {
    if (!dimension.choices.contains(unit) || defaultUnit(dimension) == unit) {
      return;
    }
    _defaults[dimension] = unit;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('$_prefix${dimension.storageKey}', unit);
    } catch (_) {
      // The in-memory choice remains active for this session.
    }
  }

  String resolve(UnitDimension dimension, String? customUnit) {
    if (customUnit != null && customUnit != 'default' &&
        dimension.choices.contains(customUnit)) {
      return customUnit;
    }
    return defaultUnit(dimension);
  }
}

/// Maps a catalog control id to the physical quantity it displays.
UnitDimension? unitDimensionForControl(String typeId) => switch (typeId) {
      'vertical_graph' => UnitDimension.altitude,
      'vario' => UnitDimension.verticalSpeed,
      'climb_avg' => UnitDimension.verticalSpeed,
      'vertical_speed' => UnitDimension.verticalSpeed,
      'altitude' || 'gps_altitude' || 'baro_altitude' || 'max_altitude' ||
      'altitude_above_takeoff' => UnitDimension.altitude,
      'ground_speed' || 'wind_speed' => UnitDimension.speed,
      'distance_to_takeoff' || 'takeoff_waypoint' => UnitDimension.distance,
      'gps_accuracy' => UnitDimension.altitude,
      'pressure' => UnitDimension.pressure,
      'temperature' => UnitDimension.temperature,
      'compass_wind' => UnitDimension.speed,
      _ => null,
    };

/// Inherited per-instance override used by controls while rendering a face.
class UnitDisplayScope extends InheritedWidget {
  final String? customUnit;

  const UnitDisplayScope({
    super.key,
    required this.customUnit,
    required super.child,
  });

  static UnitDisplayScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UnitDisplayScope>();

  @override
  bool updateShouldNotify(UnitDisplayScope oldWidget) =>
      customUnit != oldWidget.customUnit;
}

String selectedUnit(BuildContext context, UnitDimension dimension) {
  final custom = UnitDisplayScope.maybeOf(context)?.customUnit;
  return UnitSettings.instance.resolve(dimension, custom);
}
