import 'package:flutter/material.dart';

class PilotAvatar {
  PilotAvatar._();

  static const int defaultId = 0;
  static const int maxId = 7;

  static const List<IconData> icons = [
    Icons.paragliding,
    Icons.flight,
    Icons.airplanemode_active,
    Icons.landscape,
    Icons.terrain,
    Icons.wb_sunny_outlined,
    Icons.explore,
    Icons.person,
  ];

  static bool isValid(int id) => id >= 0 && id <= maxId;

  static IconData iconFor(int id) => isValid(id) ? icons[id] : icons[defaultId];
}

class PilotAvatarPicture extends StatelessWidget {
  const PilotAvatarPicture({
    required this.avatarId,
    required this.size,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  final int avatarId;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: backgroundColor ?? colors.primaryContainer,
          child: Icon(
            PilotAvatar.iconFor(avatarId),
            size: size * 0.58,
            color: iconColor ?? colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
