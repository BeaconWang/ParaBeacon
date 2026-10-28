import 'dart:math' as math;

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
/// landing point or the **nearest** saved landing point.
///
/// It shows, for the selected destination, any combination of:
/// distance, bearing, elevation change (height above the point), required
/// glide ratio to reach it, and ETA at the current ground speed. Each metric
/// can be shown or hidden independently from the control's settings sheet.
///
/// The bearing is rendered as a live compass dial with an arrow pointing to
/// the target; distance is the hero readout; the remaining metrics sit in a
/// row of compact chips.
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

  /// Render the bearing readout as an 8-point cardinal (N, NE, …) instead of
  /// degrees.
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
    // Angle shown on the dial / in the readout. In relative mode it's folded
    // against the current heading (0 = straight ahead) when a heading exists.
    double? bearingAngle = absoluteBearing;
    if (absoluteBearing != null && widget.relative) {
      bearingAngle = data.hasHeading && data.heading.isFinite
          ? ((absoluteBearing - data.heading) % 360 + 360) % 360
          : null;
    }

    final landingAltitudeMeters = target?.altitudeM;
    final elevationChange =
        landingAltitudeMeters != null &&
            landingAltitudeMeters.isFinite &&
            data.altitude.isFinite
        ? data.altitude - landingAltitudeMeters
        : null;

    // Required L/D is horizontal distance divided by altitude available.
    double? requiredGlide;
    if (distanceMeters != null &&
        elevationChange != null &&
        elevationChange > 0.5) {
      final ld = distanceMeters / elevationChange;
      if (ld.isFinite && ld >= 0) requiredGlide = ld;
    }

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
        ? (distanceMeters < 1000 ? 'm' : 'km')
        : UnitValues.symbol(UnitDimension.distance, distanceUnit);

    final bearingText = bearingAngle == null
        ? '--'
        : widget.cardinal
        ? _cardinal8(
            bearingAngle,
            chinese: Localizations.localeOf(context).languageCode == 'zh',
          )
        : '${formatDecimalValue(bearingAngle, autoDecimals: 0, range: DecimalPlacesScope.rangeOf(context, 'bearingDecimals'))}°';

    final altitudePrecision = DecimalPlacesScope.rangeOf(
      context,
      'altitudeDifferenceDecimals',
    );
    final currentAltitudeText = data.altitude.isFinite
        ? formatDecimalValue(
            UnitValues.convert(
              data.altitude,
              UnitDimension.altitude,
              altitudeUnit,
            ),
            autoDecimals: 0,
            range: altitudePrecision,
          )
        : '--';
    final landingAltitudeText =
        landingAltitudeMeters != null && landingAltitudeMeters.isFinite
        ? formatDecimalValue(
            UnitValues.convert(
              landingAltitudeMeters,
              UnitDimension.altitude,
              altitudeUnit,
            ),
            autoDecimals: 0,
            range: altitudePrecision,
          )
        : '--';
    final elevationText = elevationChange == null
        ? '--'
        : UnitValues.formatAltitudeDifference(
            elevationChange,
            altitudeUnit,
            precision: altitudePrecision,
            showPositiveSign: false,
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

    // Secondary metrics share a row below the distance readout.
    final metrics = <_Metric>[
      if (widget.showGlide)
        _Metric(
          label: l10n.waypointRequiredGlideRatioLabel,
          value: glideText,
          color: theme.colorScheme.onSurface,
        ),
      if (widget.showEta)
        _Metric(
          label: l10n.waypointEtaLabel,
          value: etaText,
          color: theme.colorScheme.onSurface,
        ),
    ];

    final title = switch (widget.reference) {
      LandingReference.nearest => l10n.controlNearestLandingWaypoint,
      LandingReference.defaultPoint => l10n.controlDefaultLandingWaypoint,
    };
    final headerIcon = widget.reference == LandingReference.defaultPoint
        ? Icons.where_to_vote
        : Icons.flight_land;
    final hasTarget = target != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 140.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 240.0;
        final scale = (math.min(
          height / 140.0,
          width / 240.0,
        )).clamp(0.55, 1.5).toDouble();
        final pad = (height * 0.05).clamp(4.0, 10.0).toDouble();

        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                icon: headerIcon,
                name: target?.name ?? title,
                subtitle: hasTarget ? title : null,
                scale: scale,
                dimmed: !hasTarget,
              ),
              SizedBox(height: 6 * scale),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _Body(
                        showBearing: widget.showBearing,
                        showDistance: widget.showDistance,
                        bearingAngle: bearingAngle,
                        relative: widget.relative,
                        bearingText: bearingText,
                        distanceText: distanceText,
                        distanceUnit: distanceUnitLabel,
                        distanceLabel: l10n.takeoffDistanceLabel,
                        bearingLabel: l10n.waypointBearingLabel,
                        metrics: metrics,
                        scale: scale,
                      ),
                    ),
                    if (widget.showElevation) ...[
                      SizedBox(height: 5 * scale),
                      _AltitudeEquation(
                        currentLabel: l10n.landingCurrentAltitudeLabel,
                        currentValue: currentAltitudeText,
                        landingLabel: l10n.landingPointAltitudeLabel,
                        landingValue: landingAltitudeText,
                        differenceLabel: l10n.landingAltitudeDifferenceLabel,
                        differenceValue: elevationText,
                        unit: UnitValues.symbol(
                          UnitDimension.altitude,
                          altitudeUnit,
                        ),
                        differenceColor: elevationChange == null
                            ? theme.colorScheme.onSurface
                            : elevationChange >= 0
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.error,
                        scale: scale,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AltitudeEquation extends StatelessWidget {
  const _AltitudeEquation({
    required this.currentLabel,
    required this.currentValue,
    required this.landingLabel,
    required this.landingValue,
    required this.differenceLabel,
    required this.differenceValue,
    required this.unit,
    required this.differenceColor,
    required this.scale,
  });

  final String currentLabel;
  final String currentValue;
  final String landingLabel;
  final String landingValue;
  final String differenceLabel;
  final String differenceValue;
  final String unit;
  final Color differenceColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AltitudeEquationTerm(
              label: currentLabel,
              value: currentValue,
              unit: unit,
              color: theme.colorScheme.onSurface,
              scale: scale,
            ),
          ),
          _EquationOperator(symbol: '−', scale: scale),
          Expanded(
            child: _AltitudeEquationTerm(
              label: landingLabel,
              value: landingValue,
              unit: unit,
              color: theme.colorScheme.onSurface,
              scale: scale,
            ),
          ),
          _EquationOperator(symbol: '=', scale: scale),
          Expanded(
            child: _AltitudeEquationTerm(
              label: differenceLabel,
              value: differenceValue,
              unit: unit,
              color: differenceColor,
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _AltitudeEquationTerm extends StatelessWidget {
  const _AltitudeEquationTerm({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.scale,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 7.5 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.0,
          ),
        ),
        SizedBox(height: 2 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value $unit',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 13 * scale,
              fontWeight: FontWeight.w700,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _EquationOperator extends StatelessWidget {
  const _EquationOperator({required this.symbol, required this.scale});

  final String symbol;
  final double scale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 3 * scale),
    child: Text(
      symbol,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12 * scale,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.scale,
    required this.dimmed,
  });

  final IconData icon;
  final String name;
  final String? subtitle;
  final double scale;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeSize = 28.0 * scale;
    return Row(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(dimmed ? 20 : 38),
            borderRadius: BorderRadius.circular(badgeSize * 0.3),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16 * scale,
            color: dimmed
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontSize: 14 * scale,
                  height: 1.1,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5 * scale,
                    letterSpacing: 0.3,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.showBearing,
    required this.showDistance,
    required this.bearingAngle,
    required this.relative,
    required this.bearingText,
    required this.distanceText,
    required this.distanceUnit,
    required this.distanceLabel,
    required this.bearingLabel,
    required this.metrics,
    required this.scale,
  });

  final bool showBearing;
  final bool showDistance;
  final double? bearingAngle;
  final bool relative;
  final String bearingText;
  final String distanceText;
  final String distanceUnit;
  final String distanceLabel;
  final String bearingLabel;
  final List<_Metric> metrics;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final contentScale = math.min(
          scale,
          (h / 72).clamp(0.45, 1.5).toDouble(),
        );
        final dialSize = showBearing
            ? math.min(
                math.max(0.0, h - 10 * contentScale),
                math.min(w * 0.34, 96 * contentScale),
              )
            : 0.0;

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDistance)
              _HeroValue(
                label: distanceLabel,
                value: distanceText,
                unit: distanceUnit,
                scale: contentScale,
              ),
            if (metrics.isNotEmpty) ...[
              if (showDistance) SizedBox(height: 4 * contentScale),
              Row(
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    if (index > 0) SizedBox(width: 4 * contentScale),
                    Expanded(
                      child: _MetricChip(
                        metric: metrics[index],
                        scale: contentScale,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );

        if (!showBearing) return rightColumn;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CompassDial(
              size: dialSize,
              angle: bearingAngle,
              relative: relative,
              readout: bearingText,
              label: bearingLabel,
              scale: contentScale,
            ),
            SizedBox(width: 8 * contentScale),
            Expanded(child: rightColumn),
          ],
        );
      },
    );
  }
}

/// Primary distance readout arranged on one baseline to preserve vertical room.
class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.scale,
  });

  final String label;
  final String value;
  final String unit;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9.5 * scale,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
          SizedBox(width: 6 * scale),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 34 * scale,
              fontWeight: FontWeight.w700,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 4 * scale),
              child: Text(
                unit,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A computed secondary metric shown beneath the primary distance.
@immutable
class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

/// Compact equal-height cell used by the secondary-metric row.
class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric, required this.scale});

  final _Metric metric;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(7 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.label.toUpperCase(),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 7.5 * scale,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: 2 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: TextStyle(
                color: metric.color,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular compass dial with an arrow pointing to the target, plus the
/// numeric/cardinal bearing readout centered inside it.
class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.size,
    required this.angle,
    required this.relative,
    required this.readout,
    required this.label,
    required this.scale,
  });

  final double size;
  final double? angle;
  final bool relative;
  final String readout;
  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CompassPainter(
              angleDegrees: angle,
              relative: relative,
              ring: theme.colorScheme.outlineVariant.withAlpha(140),
              arrow: const Color(0xFF4C9AFF),
              arrowOutline: theme.colorScheme.surface.withAlpha(140),
              hub: theme.colorScheme.onSurface.withAlpha(200),
              tick: theme.colorScheme.onSurfaceVariant.withAlpha(150),
            ),
            child: Center(
              child: Text(
                readout,
                maxLines: 1,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 8.5 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.angleDegrees,
    required this.relative,
    required this.ring,
    required this.arrow,
    required this.arrowOutline,
    required this.hub,
    required this.tick,
  });

  final double? angleDegrees;
  final bool relative;
  final Color ring;
  final Color arrow;
  final Color arrowOutline;
  final Color hub;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    if (radius <= 1) return;

    // Outer ring.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.06)
      ..color = ring;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth / 2, ringPaint);

    // The top marker identifies north in absolute mode and forward in relative mode.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.045)
      ..strokeCap = StrokeCap.round
      ..color = tick;
    for (var i = 1; i < 4; i++) {
      final theta = i * math.pi / 2 - math.pi / 2;
      final outer = center + Offset(math.cos(theta), math.sin(theta)) * radius;
      final inner =
          center + Offset(math.cos(theta), math.sin(theta)) * radius * 0.86;
      canvas.drawLine(inner, outer, tickPaint);
    }
    final topY = center.dy - radius;
    final referenceMarker = Path()
      ..moveTo(center.dx, topY + radius * 0.16)
      ..lineTo(center.dx - radius * 0.09, topY)
      ..lineTo(center.dx + radius * 0.09, topY)
      ..close();
    canvas.drawPath(
      referenceMarker,
      Paint()
        ..style = PaintingStyle.fill
        ..color = tick,
    );

    canvas.drawCircle(
      center,
      (radius * 0.06).clamp(2.0, 6.0),
      Paint()..color = hub,
    );
    if (angleDegrees == null) return;

    // Match the two-tone dart pointer used by the compass control.
    // 0° = top; clockwise.
    final theta = (angleDegrees! - 90) * math.pi / 180;
    const wingAngle = 140.0 * math.pi / 180.0;
    final arrowRadius = radius * 0.82;
    final wingRadius = arrowRadius * 0.9;
    final tailRadius = arrowRadius * 0.4;

    Offset polar(double angle, double r) => Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );

    final tip = polar(theta, arrowRadius);
    final leftWing = polar(theta - wingAngle, wingRadius);
    final rightWing = polar(theta + wingAngle, wingRadius);
    final tail = polar(theta + math.pi, tailRadius);
    final darkColor = Color.lerp(arrow, Colors.black, 0.28)!;

    final leftHalf = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..lineTo(tail.dx, tail.dy)
      ..close();
    final rightHalf = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..lineTo(tail.dx, tail.dy)
      ..close();
    canvas.drawPath(leftHalf, Paint()..color = arrow);
    canvas.drawPath(rightHalf, Paint()..color = darkColor);

    final outline = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * 0.012).clamp(0.8, 2.0)
        ..strokeJoin = StrokeJoin.round
        ..color = arrowOutline,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.angleDegrees != angleDegrees ||
      old.relative != relative ||
      old.ring != ring ||
      old.arrow != arrow ||
      old.arrowOutline != arrowOutline ||
      old.hub != hub ||
      old.tick != tick;
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
