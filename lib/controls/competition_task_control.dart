import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/competition/competition_task.dart';
import '../data/competition/competition_task_store.dart';
import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/geo_math.dart';
import '../data/unit_settings.dart';
import '../l10n/app_localizations.dart';
import 'decimal_places.dart';

/// Dashboard widget that navigates the active competition task: it points to
/// the next turnpoint cylinder and shows the optimized distance to goal, the
/// required glide and an ETA.
///
/// Reads the shared [CompetitionTaskStore] (so it tracks task edits and auto
/// advances as cylinders are entered) and the current position from the
/// unified [FlightDataProvider].
class CompetitionTaskControl extends StatefulWidget {
  const CompetitionTaskControl({
    super.key,
    this.showGoalDistance = true,
    this.showGlide = true,
    this.showEta = true,
    this.relative = true,
    this.arrowColor,
  });

  final bool showGoalDistance;
  final bool showGlide;
  final bool showEta;
  final bool relative;
  final Color? arrowColor;

  @override
  State<CompetitionTaskControl> createState() => _CompetitionTaskControlState();
}

class _CompetitionTaskControlState extends State<CompetitionTaskControl> {
  @override
  void initState() {
    super.initState();
    CompetitionTaskStore.instance.load();
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
      listenable: CompetitionTaskStore.instance,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final data = FlightDataProvider.of(context);
    final store = CompetitionTaskStore.instance;
    final hasFix = _hasValidPosition(data);

    if (!store.hasTask) {
      return _EmptyFace(theme: theme, l10n: l10n);
    }

    // Auto-advance through cylinders after the frame (mutating here would be
    // unsafe during build; the store only notifies on an actual crossing).
    if (hasFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        store.updatePosition(data.latitude, data.longitude);
      });
    }

    final next = store.nextTurnpoint;
    final nextIndex = store.nextTurnpointIndex;
    final task = store.task!;
    final totalTurnpoints = task.turnpoints.length;

    // ── Distance / bearing to the next turnpoint cylinder ──
    double? centreDistance;
    double? edgeDistance;
    double? absoluteBearing;
    if (next != null && hasFix) {
      centreDistance = GeoMath.distanceMeters(
        data.latitude,
        data.longitude,
        next.latitude,
        next.longitude,
      );
      edgeDistance = math.max(0.0, centreDistance - next.radiusMeters);
      if (centreDistance > 1.0) {
        absoluteBearing = GeoMath.bearingDegrees(
          data.latitude,
          data.longitude,
          next.latitude,
          next.longitude,
        );
      }
    }

    double? bearingAngle = absoluteBearing;
    if (absoluteBearing != null && widget.relative) {
      bearingAngle = data.hasHeading && data.heading.isFinite
          ? ((absoluteBearing - data.heading) % 360 + 360) % 360
          : null;
    }

    // ── Optimized distance to goal ──
    final goalDistance = hasFix
        ? store.remainingDistanceToGoal(data.latitude, data.longitude)
        : null;

    // ── Required glide + ETA to goal ──
    double? requiredGlide;
    final goalAlt = task.turnpoints.isNotEmpty
        ? task.turnpoints.last.waypoint.altitudeM
        : null;
    if (goalDistance != null &&
        goalAlt != null &&
        goalAlt.isFinite &&
        data.altitude.isFinite) {
      final height = data.altitude - goalAlt;
      if (height > 0.5) {
        final ld = goalDistance / height;
        if (ld.isFinite && ld >= 0) requiredGlide = ld;
      }
    }

    int? etaSeconds;
    if (goalDistance != null) {
      final groundMps = data.groundSpeed / 3.6;
      if (groundMps > 0.3) {
        final seconds = goalDistance / groundMps;
        if (seconds.isFinite && seconds >= 0 && seconds < 360000) {
          etaSeconds = seconds.round();
        }
      }
    }

    // ── Format ──
    final distanceUnit = selectedUnit(context, UnitDimension.distance);
    String fmtDistance(double? meters) {
      if (meters == null) return '--';
      return UnitValues.formatDistance(
        meters,
        distanceUnit,
        precision: DecimalPlacesScope.rangeOf(context, 'distanceDecimals'),
      );
    }

    String distanceUnitLabel(double? meters) {
      if (meters == null || distanceUnit != 'auto') {
        return UnitValues.symbol(UnitDimension.distance, distanceUnit);
      }
      return meters < 1000 ? 'm' : 'km';
    }

    final nextTitle = next == null
        ? l10n.competitionTaskComplete
        : next.name.isEmpty
            ? l10n.competitionTurnpointShort((nextIndex ?? 0) + 1)
            : next.name;
    final roleLabel = next == null ? null : _roleLabel(l10n, next.role);

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

    final arrowColor = widget.arrowColor ?? const Color(0xFF1E88E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 150.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 240.0;
        final scale = (math.min(height / 150.0, width / 240.0))
            .clamp(0.5, 1.6)
            .toDouble();
        final pad = (height * 0.05).clamp(4.0, 10.0).toDouble();

        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                scale: scale,
                taskName: task.name.isEmpty
                    ? l10n.competitionTaskTitle
                    : task.name,
                progress:
                    '${(nextIndex ?? totalTurnpoints).clamp(0, totalTurnpoints)}/$totalTurnpoints',
                nextName: nextTitle,
                roleLabel: roleLabel,
              ),
              SizedBox(height: 6 * scale),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DirectionDial(
                      size: math.min(
                        math.max(0.0, height * 0.46),
                        width * 0.32,
                      ),
                      color: arrowColor,
                      angle: bearingAngle,
                      ringColor: theme.colorScheme.outlineVariant.withAlpha(
                        140,
                      ),
                      tickColor: theme.colorScheme.onSurfaceVariant.withAlpha(
                        150,
                      ),
                      hubColor: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hero(
                            label: l10n.competitionNextTurnpointLabel,
                            value: fmtDistance(edgeDistance),
                            unit: distanceUnitLabel(edgeDistance),
                            scale: scale,
                            color: theme.colorScheme.primary,
                          ),
                          SizedBox(height: 4 * scale),
                          Row(
                            children: [
                              if (widget.showGoalDistance)
                                Expanded(
                                  child: _Chip(
                                    label: l10n.competitionGoalDistanceLabel,
                                    value:
                                        '${fmtDistance(goalDistance)} ${distanceUnitLabel(goalDistance)}',
                                    scale: scale,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              if (widget.showGlide) ...[
                                if (widget.showGoalDistance)
                                  SizedBox(width: 4 * scale),
                                Expanded(
                                  child: _Chip(
                                    label: l10n
                                        .waypointRequiredGlideRatioLabel,
                                    value: glideText,
                                    scale: scale,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                              if (widget.showEta) ...[
                                SizedBox(width: 4 * scale),
                                Expanded(
                                  child: _Chip(
                                    label: l10n.waypointEtaLabel,
                                    value: etaText,
                                    scale: scale,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

  String _roleLabel(AppLocalizations l10n, TurnpointRole role) {
    switch (role) {
      case TurnpointRole.takeoff:
        return l10n.competitionRoleTakeoff;
      case TurnpointRole.sss:
        return l10n.competitionRoleSss;
      case TurnpointRole.ess:
        return l10n.competitionRoleEss;
      case TurnpointRole.turnpoint:
        return l10n.competitionRoleTurnpoint;
    }
  }
}

class _EmptyFace extends StatelessWidget {
  const _EmptyFace({required this.theme, required this.l10n});

  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.competitionNoTask,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scale,
    required this.taskName,
    required this.progress,
    required this.nextName,
    required this.roleLabel,
  });

  final double scale;
  final String taskName;
  final String progress;
  final String nextName;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 26 * scale,
          height: 26 * scale,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(38),
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.flag,
            size: 15 * scale,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      nextName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * scale,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (roleLabel != null) ...[
                    SizedBox(width: 5 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5 * scale,
                        vertical: 1 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4 * scale),
                      ),
                      child: Text(
                        roleLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontSize: 8 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '$taskName · $progress',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9.5 * scale,
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.label,
    required this.value,
    required this.unit,
    required this.scale,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final double scale;
  final Color color;

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
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9 * scale,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: 6 * scale),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 30 * scale,
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
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.scale,
    required this.color,
  });

  final String label;
  final String value;
  final double scale;
  final Color color;

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
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 7.5 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 2 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact direction dial with a dart pointing to the next turnpoint.
class _DirectionDial extends StatelessWidget {
  const _DirectionDial({
    required this.size,
    required this.color,
    required this.angle,
    required this.ringColor,
    required this.tickColor,
    required this.hubColor,
  });

  final double size;
  final Color color;
  final double? angle;
  final Color ringColor;
  final Color tickColor;
  final Color hubColor;

  @override
  Widget build(BuildContext context) {
    if (size <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(
          angleDegrees: angle,
          ring: ringColor,
          arrow: color,
          tick: tickColor,
          hub: hubColor,
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.angleDegrees,
    required this.ring,
    required this.arrow,
    required this.tick,
    required this.hub,
  });

  final double? angleDegrees;
  final Color ring;
  final Color arrow;
  final Color tick;
  final Color hub;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    if (radius <= 1) return;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.06)
      ..color = ring;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth / 2, ringPaint);

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
    canvas.drawPath(referenceMarker, Paint()..color = tick);

    canvas.drawCircle(
      center,
      (radius * 0.06).clamp(2.0, 6.0),
      Paint()..color = hub,
    );
    if (angleDegrees == null) return;

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
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.angleDegrees != angleDegrees ||
      old.ring != ring ||
      old.arrow != arrow ||
      old.tick != tick ||
      old.hub != hub;
}

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
