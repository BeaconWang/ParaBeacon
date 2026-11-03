import 'package:flutter/material.dart';

/// Lifts a modal bottom sheet's body above the on-screen keyboard (IME).
///
/// Unlike a [Scaffold] (which honours `resizeToAvoidBottomInset`) or a
/// [Dialog]/[AlertDialog] (which already pads itself by
/// `MediaQuery.viewInsets`), a `showModalBottomSheet` sheet does **not** shrink
/// when the soft keyboard opens. A text field near the bottom of such a sheet
/// is therefore hidden behind the keyboard.
///
/// Wrapping the sheet body in [KeyboardInset] adds animated bottom padding
/// equal to the current keyboard inset. The sheet's usable area shrinks to the
/// space above the keyboard, so the enclosing scrollable (ListView /
/// SingleChildScrollView) can scroll the focused field into view and keep it
/// visible while typing — matching the behaviour of native Android apps.
///
/// Use it directly inside the sheet builder, around the sheet's root
/// [Material]/[SafeArea]:
///
/// ```dart
/// showModalBottomSheet(
///   isScrollControlled: true,
///   builder: (_) => KeyboardInset(child: _MySheet()),
/// );
/// ```
class KeyboardInset extends StatelessWidget {
  const KeyboardInset({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOut,
  });

  /// The sheet body to lift above the keyboard.
  final Widget child;

  /// Animation duration used when the keyboard shows/hides.
  final Duration duration;

  /// Animation curve used when the keyboard shows/hides.
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: duration,
      curve: curve,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
