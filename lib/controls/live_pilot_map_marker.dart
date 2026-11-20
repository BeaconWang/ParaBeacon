import 'package:flutter/material.dart';

import '../data/pilot_avatar.dart';
import '../data/pilot_course.dart';

/// Compact participant marker for a pilot sharing a live flight location.
/// The circular avatar center is the geographic anchor; identity and flight
/// details remain in badges below it.
class LivePilotMapMarker extends StatelessWidget {
  const LivePilotMapMarker({
    required this.name,
    required this.color,
    required this.landed,
    this.showName = true,
    this.avatarId = PilotAvatar.defaultId,
    this.profileImageUrl,
    this.flightInfo,
    this.headingDegrees,
    this.screenRotationDegrees = 0,
    super.key,
  });

  static const double markerWidth = 160;
  static const double markerHeight = 104;
  static const double iconStageSize = 52;
  static const double glyphCenterFromTop = iconStageSize / 2;
  static const Alignment markerAlignment = Alignment(
    0,
    (2 * glyphCenterFromTop / markerHeight) - 1,
  );

  static const liveIndicatorColor = Color(0xff36c878);
  static const captionTextColor = Color(0xccffffff);

  final String name;
  final Color color;
  final bool landed;
  final bool showName;
  final int avatarId;
  final String? profileImageUrl;
  final String? flightInfo;
  final double? headingDegrees;
  final double screenRotationDegrees;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: markerWidth,
      height: markerHeight,
      child: Opacity(
        opacity: landed ? 0.45 : 1,
        child: Semantics(
          label: '$name, ${landed ? 'landed' : 'sharing live location'}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: iconStageSize,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (headingDegrees != null && headingDegrees!.isFinite)
                      PilotDirectionIndicator(
                        headingDegrees: headingDegrees!,
                        mapRotationDegrees: screenRotationDegrees,
                        color: color,
                      ),
                    Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: PilotAvatarPicture(
                        avatarId: avatarId,
                        profileImageUrl: profileImageUrl,
                        size: 28,
                        circular: true,
                        backgroundColor: color.withValues(alpha: 0.14),
                        iconColor: color,
                      ),
                    ),
                  ],
                ),
              ),

              if (showName) ...[
                const SizedBox(height: 3),
                _buildBadge(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 7,
                        color: liveIndicatorColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: captionTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (flightInfo != null && flightInfo!.isNotEmpty) ...[
                const SizedBox(height: 2),
                _buildBadge(
                  child: Text(
                    flightInfo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: captionTextColor,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required Widget child}) => Container(
    constraints: const BoxConstraints(maxWidth: markerWidth - 12),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xdd17212b),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
      ],
    ),
    child: child,
  );
}

class PilotDirectionIndicator extends StatelessWidget {
  const PilotDirectionIndicator({
    required this.headingDegrees,
    required this.mapRotationDegrees,
    required this.color,
    super.key,
  });

  final double headingDegrees;
  final double mapRotationDegrees;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: PilotCourse.screenRadians(
      courseDegrees: headingDegrees,
      mapRotationDegrees: mapRotationDegrees,
    ),
    child: CustomPaint(
      size: const Size.square(indicatorSize),
      painter: _PilotDirectionIndicatorPainter(color: color),
    ),
  );

  static const double indicatorSize = 52;
}

class _PilotDirectionIndicatorPainter extends CustomPainter {
  const _PilotDirectionIndicatorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / PilotDirectionIndicator.indicatorSize;
    final scaleY = size.height / PilotDirectionIndicator.indicatorSize;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.miter;
    final accent = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pointer = Path()
      ..moveTo(26, 0)
      ..lineTo(18, 14)
      ..lineTo(26, 10)
      ..lineTo(34, 14)
      ..close();
    canvas.drawPath(pointer, outline);
    canvas.drawPath(pointer, accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PilotDirectionIndicatorPainter oldDelegate) =>
      oldDelegate.color != color;
}
