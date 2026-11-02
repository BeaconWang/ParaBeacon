import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps the globally focused render object visible when the soft keyboard opens.
///
/// Place once around the Navigator subtree. Scrollable ancestors are asked to
/// reveal the focused field; Scaffold remains responsible for resizing pages.
class KeyboardFocusScroller extends StatefulWidget {
  const KeyboardFocusScroller({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardFocusScroller> createState() => _KeyboardFocusScrollerState();
}

class _KeyboardFocusScrollerState extends State<KeyboardFocusScroller>
    with WidgetsBindingObserver {
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_scheduleReveal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleReveal();
  }

  @override
  void didChangeMetrics() => _scheduleReveal();

  void _scheduleReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || MediaQuery.viewInsetsOf(context).bottom <= 0) return;
        final focusedContext = FocusManager.instance.primaryFocus?.context;
        if (focusedContext == null || !focusedContext.mounted) return;
        final focusedObject = focusedContext.findRenderObject();
        final keyboardTop =
            MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        final isCovered =
            focusedObject is RenderBox &&
            focusedObject.hasSize &&
            focusedObject
                    .localToGlobal(Offset(0, focusedObject.size.height))
                    .dy >
                keyboardTop - 16;
        unawaited(
          Scrollable.ensureVisible(
            focusedContext,
            alignment: isCovered ? 0.75 : 0.15,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignmentPolicy: isCovered
                ? ScrollPositionAlignmentPolicy.explicit
                : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    FocusManager.instance.removeListener(_scheduleReveal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Animates custom modal content above the keyboard.
///
/// Use for modal sheets that contain fixed headers/footers and are not hosted
/// by a Scaffold. Do not add this around a Scaffold that already resizes for IME.
class KeyboardInsetPadding extends StatelessWidget {
  const KeyboardInsetPadding({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: child,
    );
  }
}
