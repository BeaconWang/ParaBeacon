import 'package:flutter/material.dart';

import '../data/pilot_avatar.dart';
import 'pilot_direction_arrow.dart';

/// Compact participant marker for a pilot sharing a live flight location.
/// The paraglider glyph's center is the geographic anchor; identity and flight
/// details remain in badges below it.
class LivePilotMapMarker extends StatelessWidget {
  const LivePilotMapMarker({
    required this.name,
    required this.color,
    required this.landed,
    this.avatarId = PilotAvatar.defaultId,
    this.flightInfo,
    this.headingDegrees,
    this.screenRotationDegrees = 0,
    super.key,
  });

  static const double markerWidth = 160;
  static const double markerHeight = 84;
  static const double glyphCenterFromTop = 19;
  static const Alignment markerAlignment = Alignment(
    0,
    (2 * glyphCenterFromTop / markerHeight) - 1,
  );

  static const liveIndicatorColor = Color(0xff36c878);

  final String name;
  final Color color;
  final bool landed;
  final int avatarId;
  final String? flightInfo;
  final double? headingDegrees;
  final double screenRotationDegrees;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: landed ? 0.45 : 1,
      child: Semantics(
        label: '$name, ${landed ? 'landed' : 'sharing live location'}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
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
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PilotAvatar.iconFor(avatarId),
                      size: 21,
                      color: color,
                    ),
                  ),
                ),
                if (headingDegrees != null && headingDegrees!.isFinite)
                  Positioned(
                    top: -3,
                    child: PilotDirectionArrow(
                      headingDegrees: headingDegrees!,
                      mapRotationDegrees: screenRotationDegrees,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            _buildBadge(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 7, color: liveIndicatorColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (flightInfo != null && flightInfo!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _buildBadge(
                child: Text(
                  flightInfo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ],
          ],
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
