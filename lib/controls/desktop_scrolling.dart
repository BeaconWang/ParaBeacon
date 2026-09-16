import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Adds desktop-mouse horizontal scrolling to a horizontally scrolling child.
///
/// Flutter maps wheel input onto the scrollable's own axis: a vertical mouse
/// wheel only produces `scrollDelta.dy`, so horizontal-only lists ignore it
/// (Shift+wheel flips the axis via `ScrollBehavior.pointerAxisModifiers`).
/// This wrapper turns that plain wheel input into horizontal scrolling while
/// the pointer hovers the child.
///
/// The child's [ScrollController] must be passed as [controller]. Events are
/// handed to the `PointerSignalResolver`, whose first registration wins and
/// hit-testing is child-first: whenever the child's own Scrollable can act
/// (Shift+wheel, trackpad pan with a `dx` component) it keeps precedence, and
/// when the list is at an edge the event falls through to outer scrollables.
class MouseWheelHScroll extends StatelessWidget {
  const MouseWheelHScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  /// The horizontal list's controller.
  final ScrollController controller;

  final Widget child;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Only plain wheels: anything with a dx component (trackpad pan) — or
    // modifier-flipped axes — is already handled by the child Scrollable.
    final delta = event.scrollDelta.dy;
    if (delta == 0 || event.scrollDelta.dx != 0 || !controller.hasClients) {
      return;
    }
    final position = controller.position;
    // Only claim the event when the list can actually move that way, so
    // edge-of-list wheels stay available to surrounding scrollables.
    final canScroll =
        delta > 0 ? position.pixels < position.maxScrollExtent : position.pixels > position.minScrollExtent;
    if (!canScroll) return;
    GestureBinding.instance.pointerSignalResolver.register(event, _handleScroll);
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !controller.hasClients) return;
    controller.position.pointerScroll(event.scrollDelta.dy);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerSignal: _onPointerSignal, child: child);
  }
}

/// Scroll behavior that also accepts click-and-drag from the mouse, so
/// horizontal tables and page panels can be swiped with the mouse on desktop
/// (Flutter's default `dragDevices` excludes [PointerDeviceKind.mouse]).
///
/// Scope it to touch-first surfaces (tables, page views) rather than applying
/// it app-wide: mouse drag on scrollables makes selecting text inside them
/// difficult.
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  const MouseDragScrollBehavior();

  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
    // VoiceAccess sends pointer events with an unknown type when scrolling.
    PointerDeviceKind.unknown,
  };

  @override
  Set<PointerDeviceKind> get dragDevices => _dragDevices;
}
