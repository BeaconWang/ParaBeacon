import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/geo_math.dart';
import '../data/landing_point_store.dart';
import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';
import 'data_value_control.dart' show LandingReference;
import 'decimal_places.dart';

/// Navigation widget for a landing waypoint — either the user's **default**
/// landing point or the **last** (nearest saved) landing point.
///
/// It shows, for the selected destination, any combination of:
/// distance, bearing, elevation change (height above the point), required
/// glide ratio to reach it, and ETA at the current ground speed. Each metric
/// can be shown or hidden independently from the control's settings sheet.
///
/// Reads the shared [LandingPointStore] (so it tracks edits to the landing
/// list live) and the current position from the unified [FlightDataProvider].
/// Any metric with insufficient data renders as `--`.
class LandingWaypointControl extends StatefulWidget {
  const LandingWaypointControl({
    super.key,
    required this.reference,
    this.showDistance = true,
    this.showBearing = true,
    this.showElevation = true,
    this.showGlide = true,
    this.showEta = true,
    this.cardinal = false,
    this.relative = false,
  });

  /// Which saved point to navigate to.
  final LandingReference reference;

  final bool showDistance;
  final bool showBearing;
  final bool showElevation;
  final bool showGlide;
  final bool showEta;

  /// Render the bearing as an 8-point cardinal (N, NE, …) instead of degrees.
  final bool cardinal;

  /// Express the bearing relative to the current heading instead of as an
  /// absolute compass bearing.
  final bool relative;

  @override
  State<LandingWaypointControl> createState() => _LandingWaypointControlState();
}

class _LandingWaypointControlState extends State<LandingWaypointControl> {
  @override
  void initState() {
    super.initState();
    // Make sure persisted points are available even if this is the first
    // thing on screen to touch the store.
    LandingPointStore.instance.load();
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
    return ListenableBuilder(
      listenable: LandingPointStore.instance,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final data = FlightDataProvider.of(context);
    final hasFix = _hasValidPosition(data);
    final store = LandingPointStore.instance;

    final target = switch (widget.reference) {
      LandingReference.nearest =>
        hasFix ? store.nearestPointTo(data.latitude, data.longitude) : null,
      LandingReference.defaultPoint => store.defaultPoint,
    };

    // ── Compute the raw metrics (null == unavailable → rendered as `--`). ──
    final distanceMeters = target != null && hasFix
        ? GeoMath.distanceMeters(
            data.latitude,
            data.longitude,
            target.latitude,
            target.longitude,
          )
        : null;

    final absoluteBearing =
        target != null && hasFix && (distanceMeters ?? 0) > 1.0
        ? GeoMath.bearingDegrees(
            data.latitude,
            data.longitude,
            target.latitude,
            target.longitude,
          )
        : null;
    double? bearingAngle = absoluteBearing;
    if (absoluteBearing != null && widget.relative) {
      bearingAngle = data.hasHeading && data.heading.isFinite
          ? ((absoluteBearing - data.heading) % 360 + 360) % 360
          : null;
    }

    // Elevation change = how far above the target we currently are. Needs a
    // known target altitude.
    final elevationChange =
        target?.altitudeM != null && data.altitude.isFinite
        ? data.altitude - target!.altitudeM!
        : null;

    // Required glide ratio to reach the point: horizontal distance over the
    // height we have to give away. Only meaningful while above the target.
    double? requiredGlide;
    if (distanceMeters != null &&
        elevationChange != null &&
        elevationChange > 0.5) {
      final ld = distanceMeters / elevationChange;
      if (ld.isFinite && ld > 0) requiredGlide = ld;
    }

    // ETA at the current ground speed.
    int? etaSeconds;
    if (distanceMeters != null) {
      final groundMps = data.groundSpeed / 3.6;
      if (groundMps > 0.3) {
        final seconds = distanceMeters / groundMps;
        if (seconds.isFinite && seconds >= 0 && seconds < 360000) {
          etaSeconds = seconds.round();
        }
      }
    }

    // ── Format ──
    final distanceUnit = selectedUnit(context, UnitDimension.distance);
    final altitudeUnit = selectedUnit(context, UnitDimension.altitude);

    final distanceText = distanceMeters == null
        ? '--'
        : UnitValues.formatDistance(
            distanceMeters,
            distanceUnit,
            precision: DecimalPlacesScope.rangeOf(context, 'distanceDecimals'),
          );
    final distanceUnitLabel = distanceMeters == null
        ? UnitValues.symbol(UnitDimension.distance, distanceUnit)
        : distanceUnit == 'auto'
        ? (distanceMeters < 1000 ? 'M' : 'KM')
        : UnitValues.symbol(UnitDimension.distance, distanceUnit).toUpperCase();

    final bearingText = bearingAngle == null
        ? '--'
        : widget.cardinal
        ? _cardinal8(
            bearingAngle,
            chinese: Localizations.localeOf(context).languageCode == 'zh',
          )
        : '${formatDecimalValue(bearingAngle, autoDecimals: 0, range: DecimalPlacesScope.rangeOf(context, 'bearingDecimals'))}°';

    final elevationText = elevationChange == null
        ? '--'
        : UnitValues.formatAltitudeDifference(
            elevationChange,
            altitudeUnit,
            precision: DecimalPlacesScope.rangeOf(
              context,
              'altitudeDifferenceDecimals',
            ),
          );

    final glideText = requiredGlide == null
        ? '--'
        : requiredGlide >= 100
        ? '99+'
        : formatDecimalValue(
            requiredGlide,
            autoDecimals: 1,
            range: DecimalPlacesScope.rangeOf(context, 'ratioDecimals'),
          );

    final etaText = etaSeconds == null ? '--' : _formatDuration(etaSeconds);

    // ── Assemble the enabled metrics in a stable order. ──
    final metrics = <_Metric>[
      if (widget.showDistance)
        _Metric(
          label: l10n.takeoffDistanceLabel,
          value: distanceText,
          unit: distanceUnitLabel,
          color: theme.colorScheme.primary,
        ),
      if (widget.showBearing)
        _Metric(
          label: l10n.waypointBearingLabel,
          value: bearingText,
          unit: '',
          color: theme.colorScheme.onSurface,
        ),
      if (widget.showElevation)
        _Metric(
          label: l10n.takeoffAltitudeDifferenceLabel,
          value: elevationText,
          unit: UnitValues.symbol(
            UnitDimension.altitude,
            altitudeUnit,
          ).toUpperCase(),
          color: (elevationChange ?? 0) >= 0
              ? theme.colorScheme.secondary
              : theme.colorScheme.error,
        ),
      if (widget.showGlide)
        _Metric(
          label: l10n.waypointGlideLabel,
          value: glideText,
          unit: '',
          color: theme.colorScheme.primary,
        ),
      if (widget.showEta)
        _Metric(
          label: l10n.waypointEtaLabel,
          value: etaText,
          unit: '',
          color: theme.colorScheme.onSurface,
        ),
    ];

    final title = switch (widget.reference) {
      LandingReference.nearest => l10n.controlLastLandingWaypoint,
      LandingReference.defaultPoint => l10n.controlDefaultLandingWaypoint,
    };
    final pointName = target?.name;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 120.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 200.0;
        final scale = (height / 120.0).clamp(0.6, 1.4).toDouble();
        final padding = (height * 0.05).clamp(3.0, 8.0).toDouble();

        final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 9.5 * scale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          height: 1.1,
        );

        // Two columns unless the widget is very narrow.
        final columns = width < 150 ? 1 : 2;
        final spacing = 8.0 * scale;
        final tileWidth = metrics.isEmpty
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget.reference == LandingReference.defaultPoint
                        ? Icons.where_to_vote
                        : Icons.flight_land,
                    size: 16 * scale,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      pointName ?? title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: (height * 0.06).clamp(4.0, 10.0)),
              Expanded(
                child: metrics.isEmpty
                    ? Center(
                        child: Text(
                          title,
                          style: labelStyle,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Align(
                        alignment: Alignment.topLeft,
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: (height * 0.05).clamp(4.0, 12.0),
                          children: [
                            for (final metric in metrics)
                              SizedBox(
                                width: tileWidth,
                                child: _MetricTile(
                                  metric: metric,
                                  labelStyle: labelStyle,
                                  valueSize: 26 * scale,
                                  unitSize: 11 * scale,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single computed metric to display (label + value + optional unit).
@immutable
class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.metric,
    required this.labelStyle,
    required this.valueSize,
    required this.unitSize,
  });

  final _Metric metric;
  final TextStyle? labelStyle;
  final double valueSize;
  final double unitSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.value,
                maxLines: 1,
                style: TextStyle(
                  color: metric.color,
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (metric.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 2),
                  child: Text(
                    metric.unit,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: unitSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Formats a duration in seconds as `M:SS` (or `H:MM:SS` past an hour).
String _formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// Converts a 0-360° bearing to an 8-point cardinal label.
String _cardinal8(double degrees, {bool chinese = false}) {
  const english = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const chineseLabels = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
  final labels = chinese ? chineseLabels : english;
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) ~/ 45) % 8;
  return labels[index];
}
