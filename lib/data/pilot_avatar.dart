import 'package:flutter/material.dart';

import 'profile_image_url.dart';

class PilotAvatar {
  PilotAvatar._();

  static const int defaultId = 0;
  static const int maxId = 7;

  static bool isValid(int id) => id >= 0 && id <= maxId;

  static IconData iconFor(int _) => Icons.paragliding;
}

class PilotAvatarPicture extends StatelessWidget {
  const PilotAvatarPicture({
    required this.avatarId,
    required this.size,
    this.backgroundColor,
    this.iconColor,
    this.profileImageUrl,
    this.circular = false,
    super.key,
  });

  final int avatarId;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? profileImageUrl;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: backgroundColor ?? colors.primaryContainer,
      child: Icon(
        PilotAvatar.iconFor(avatarId),
        size: size * 0.58,
        color: iconColor ?? colors.onPrimaryContainer,
      ),
    );
    final imageUri = ProfileImageUrl.resolve(profileImageUrl);
    final picture = SizedBox.square(
      dimension: size,
      child: imageUri == null
          ? fallback
          : Image.network(
              imageUri.toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
    return circular
        ? ClipOval(child: picture)
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.24),
            child: picture,
          );
  }
}
