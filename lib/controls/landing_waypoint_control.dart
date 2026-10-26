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
/// landing point or the **last** (nearest saved) landing point.
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

    final elevationChange =
        target?.altitudeM != null && data.altitude.isFinite
        ? data.altitude - target!.altitudeM!
        : null;

    double? requiredGlide;
    if (distanceMeters != null &&
        elevationChange != null &&
        elevationChange > 0.5) {
      final ld = distanceMeters / elevationChange;
      if (ld.isFinite && ld > 0) requiredGlide = ld;
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

    // Secondary metrics shown as chips (distance is the hero, bearing is the
    // dial). Order is stable regardless of which are enabled.
    final chips = <_Metric>[
      if (widget.showElevation)
        _Metric(
          icon: Icons.swap_vert,
          label: l10n.takeoffAltitudeDifferenceLabel,
          value: elevationText,
          unit: UnitValues.symbol(UnitDimension.altitude, altitudeUnit),
          color: elevationChange == null
              ? theme.colorScheme.onSurface
              : elevationChange >= 0
              ? theme.colorScheme.secondary
              : theme.colorScheme.error,
        ),
      if (widget.showGlide)
        _Metric(
          icon: Icons.trending_down,
          label: l10n.waypointGlideLabel,
          value: glideText,
          unit: '',
          color: theme.colorScheme.onSurface,
        ),
      if (widget.showEta)
        _Metric(
          icon: Icons.schedule,
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
        final scale = (math.min(height / 140.0, width / 240.0))
            .clamp(0.55, 1.5)
            .toDouble();
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
                  chips: chips,
                  scale: scale,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
    required this.chips,
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
  final List<_Metric> chips;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final dialSize = showBearing
            ? math.min(h, w * 0.42).clamp(40.0, 110.0).toDouble()
            : 0.0;

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDistance) ...[
              _HeroValue(
                label: distanceLabel,
                value: distanceText,
                unit: distanceUnit,
                scale: scale,
              ),
              if (chips.isNotEmpty) SizedBox(height: 8 * scale),
            ],
            if (chips.isNotEmpty)
              Wrap(
                spacing: 6 * scale,
                runSpacing: 6 * scale,
                children: [
                  for (final m in chips) _MetricChip(metric: m, scale: scale),
                ],
              ),
          ],
        );

        if (!showBearing) {
          return Align(alignment: Alignment.centerLeft, child: rightColumn);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CompassDial(
              size: dialSize,
              angle: bearingAngle,
              relative: relative,
              readout: bearingText,
              label: bearingLabel,
              scale: scale,
            ),
            SizedBox(width: 12 * scale),
            Expanded(child: rightColumn),
          ],
        );
      },
    );
  }
}

/// Big primary readout (value + small trailing unit) with a caption above.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            height: 1.0,
          ),
        ),
        SizedBox(height: 2 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 38 * scale,
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
        ),
      ],
    );
  }
}

/// A single computed metric (icon + label + value + optional unit).
@immutable
class _Metric {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
}

/// Compact rounded chip used for the secondary metrics.
class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric, required this.scale});

  final _Metric metric;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            metric.icon,
            size: 13 * scale,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 5 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label.toUpperCase(),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 1 * scale),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: metric.color,
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (metric.unit.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: 2 * scale),
                      child: Text(
                        metric.unit,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
              arrow: theme.colorScheme.primary,
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
    required this.tick,
  });

  final double? angleDegrees;
  final bool relative;
  final Color ring;
  final Color arrow;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.06)
      ..color = ring;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth / 2, ringPaint);

    // Cardinal/ahead ticks.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.045)
      ..strokeCap = StrokeCap.round
      ..color = tick;
    for (var i = 0; i < 4; i++) {
      final theta = i * math.pi / 2 - math.pi / 2;
      final outer = center + Offset(math.cos(theta), math.sin(theta)) * radius;
      final innerLen = i == 0 ? radius * 0.78 : radius * 0.86;
      final inner =
          center + Offset(math.cos(theta), math.sin(theta)) * innerLen;
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (angleDegrees == null) return;

    // Arrow pointing to the target. 0° = top; clockwise.
    final theta = (angleDegrees! - 90) * math.pi / 180;
    final dir = Offset(math.cos(theta), math.sin(theta));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = center + dir * (radius * 0.62);
    final tailLen = radius * 0.5;
    final tail = center - dir * tailLen;
    final headHalf = radius * 0.2;
    final headBase = center + dir * (radius * 0.28);

    final arrowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = arrow;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, radius * 0.09)
      ..strokeCap = StrokeCap.round
      ..color = arrow;

    // Shaft from tail to the base of the head.
    canvas.drawLine(tail, headBase, linePaint);

    // Triangular arrowhead.
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headBase.dx + perp.dx * headHalf, headBase.dy + perp.dy * headHalf)
      ..lineTo(headBase.dx - perp.dx * headHalf, headBase.dy - perp.dy * headHalf)
      ..close();
    canvas.drawPath(head, arrowPaint);

    // Pivot dot.
    canvas.drawCircle(center, math.max(1.5, radius * 0.07), arrowPaint);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.angleDegrees != angleDegrees ||
      old.relative != relative ||
      old.ring != ring ||
      old.arrow != arrow ||
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
