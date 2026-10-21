import 'package:flutter/material.dart';

import '../audio/altitude_announcement_speaker.dart';

/// Shows the text of the current voice announcement as a caption at the top
/// of the screen. Purely visual: it never intercepts touches.
class AnnouncementCaptionOverlay extends StatelessWidget {
  const AnnouncementCaptionOverlay({super.key, this.speaker});

  final AltitudeAnnouncementSpeaker? speaker;

  @override
  Widget build(BuildContext context) {
    final source = speaker ?? AltitudeAnnouncementSpeaker.instance;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ValueListenableBuilder<String?>(
              valueListenable: source.caption,
              builder: (context, text, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: text == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : _CaptionBubble(key: ValueKey(text), text: text),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionBubble extends StatelessWidget {
  const _CaptionBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 22,
                  color: scheme.onInverseSurface,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
