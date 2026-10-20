import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/flight_state.dart';
import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';

/// Shows distance, bearing, and altitude difference from the takeoff point.
class TakeoffWaypointControl extends StatefulWidget {
  const TakeoffWaypointControl({super.key});

  @override
  State<TakeoffWaypointControl> createState() => _TakeoffWaypointControlState();
}

class _TakeoffWaypointControlState extends State<TakeoffWaypointControl> {
  double? _homeLatitude;
  double? _homeLongitude;
  double? _homeAltitude;

  @override
  void initState() {
    super.initState();
    FlightState.instance.addListener(_onFlightStateChanged);
  }

  @override
  void dispose() {
    FlightState.instance.removeListener(_onFlightStateChanged);
    super.dispose();
  }

  void _onFlightStateChanged() {
    if (!FlightState.instance.isFlying && _homeLatitude != null) {
      setState(() {
        _homeLatitude = null;
        _homeLongitude = null;
        _homeAltitude = null;
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  bool _hasValidPosition(FlightData data) =>
      data.hasFix &&
      data.latitude.isFinite &&
      data.longitude.isFinite &&
      data.latitude >= -90 &&
      data.latitude <= 90 &&
      data.longitude >= -180 &&
      data.longitude <= 180;

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    final flying = FlightState.instance.isFlying;
    if (flying && _homeLatitude == null && _hasValidPosition(data)) {
      _homeLatitude = data.latitude;
      _homeLongitude = data.longitude;
      _homeAltitude = data.altitude;
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canCalculate =
        flying &&
        _homeLatitude != null &&
        _homeLongitude != null &&
        _homeAltitude != null &&
        _hasValidPosition(data);
    final distanceMeters = canCalculate
        ? _distanceMeters(
            _homeLatitude!,
            _homeLongitude!,
            data.latitude,
            data.longitude,
          )
        : null;
    final bearing = canCalculate
        ? _bearing(
            _homeLatitude!,
            _homeLongitude!,
            data.latitude,
            data.longitude,
          )
        : null;
    final altitudeDifference = canCalculate
        ? data.altitude - _homeAltitude!
        : null;

    final distanceUnit = selectedUnit(context, UnitDimension.distance);
    final distanceText = distanceMeters == null
        ? '--'
        : _formatDistance(distanceMeters, distanceUnit);
    final distanceUnitLabel = distanceMeters == null
        ? UnitValues.symbol(UnitDimension.distance, distanceUnit)
        : _distanceUnitLabel(distanceMeters, distanceUnit);
    final altitudeUnit = selectedUnit(context, UnitDimension.altitude);
    final altitudeText = altitudeDifference == null
        ? '--'
        : _formatAltitudeDifference(altitudeDifference, altitudeUnit);
    final headingText = bearing == null ? '--°' : '${bearing.round()}°';

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 100.0;
        final scale = (height / 100.0).clamp(0.65, 1.35).toDouble();
        final padding = (height * 0.055).clamp(3.0, 8.0).toDouble();
        final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          height: 1.1,
        );

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.home,
                    size: 16 * scale,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      l10n.takeoffPointLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    'BRG $headingText',
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11 * scale,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              SizedBox(height: (height * 0.08).clamp(4.0, 8.0)),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _WaypointValue(
                        label: l10n.takeoffDistanceLabel,
                        value: distanceText,
                        unit: distanceUnitLabel,
                        valueColor: theme.colorScheme.primary,
                        labelStyle: labelStyle,
                        valueSize: 40 * scale,
                        unitSize: 12 * scale,
                        alignment: CrossAxisAlignment.start,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: _WaypointValue(
                        label: l10n.takeoffAltitudeDifferenceLabel,
                        value: altitudeText,
                        unit: UnitValues.symbol(
                          UnitDimension.altitude,
                          altitudeUnit,
                        ).toUpperCase(),
                        valueColor: (altitudeDifference ?? 0) >= 0
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.error,
                        labelStyle: labelStyle,
                        valueSize: 36 * scale,
                        unitSize: 12 * scale,
                        alignment: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDistance(double meters, String unit) {
    if (unit == 'auto') {
      if (meters < 1000) return meters.round().toString();
      final kilometers = meters / 1000;
      return kilometers.toStringAsFixed(kilometers >= 100 ? 0 : 1);
    }
    final value = UnitValues.convert(meters, UnitDimension.distance, unit);
    final decimals = switch (unit) {
      'km' || 'mi' => value >= 100 ? 0 : 1,
      _ => 0,
    };
    return value.toStringAsFixed(decimals);
  }

  static String _distanceUnitLabel(double meters, String unit) {
    if (unit == 'auto') return meters < 1000 ? 'M' : 'KM';
    return UnitValues.symbol(UnitDimension.distance, unit).toUpperCase();
  }

  static String _formatAltitudeDifference(double meters, String unit) {
    final value = UnitValues.convert(meters, UnitDimension.altitude, unit);
    final rounded = value.round();
    return rounded >= 0 ? '+$rounded' : '$rounded';
  }

  static double _distanceMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    double radians(double degrees) => degrees * math.pi / 180;

    final deltaLatitude = radians(latitude2 - latitude1);
    final deltaLongitude = radians(longitude2 - longitude1);
    final a =
        math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
        math.cos(radians(latitude1)) *
            math.cos(radians(latitude2)) *
            math.sin(deltaLongitude / 2) *
            math.sin(deltaLongitude / 2);
    return 2 * earthRadiusMeters * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _bearing(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    double radians(double degrees) => degrees * math.pi / 180;

    final deltaLongitude = radians(longitude2 - longitude1);
    final y = math.sin(deltaLongitude) * math.cos(radians(latitude2));
    final x =
        math.cos(radians(latitude1)) * math.sin(radians(latitude2)) -
        math.sin(radians(latitude1)) *
            math.cos(radians(latitude2)) *
            math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}

class _WaypointValue extends StatelessWidget {
  const _WaypointValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    required this.labelStyle,
    required this.valueSize,
    required this.unitSize,
    required this.alignment,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  final TextStyle? labelStyle;
  final double valueSize;
  final double unitSize;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final isRight = alignment == CrossAxisAlignment.end;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Align(
            alignment: isRight ? Alignment.bottomRight : Alignment.bottomLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: isRight ? Alignment.bottomRight : Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: valueSize,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, bottom: 4),
                    child: Text(
                      unit,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: unitSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
