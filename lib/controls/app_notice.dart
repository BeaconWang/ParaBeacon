import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

@immutable
class AppNoticeMessage {
  const AppNoticeMessage({required this.id, required this.message});

  final int id;
  final String message;
}

class AppNotice extends ChangeNotifier {
  AppNotice._();

  static final AppNotice instance = AppNotice._();
  static const Duration defaultDuration = Duration(seconds: 4);

  final Queue<String> _queue = Queue<String>();
  AppNoticeMessage? _current;
  Timer? _timer;
  int _nextId = 0;

  AppNoticeMessage? get current => _current;

  static void show(String message, {Duration duration = defaultDuration}) {
    instance._show(message, duration);
  }

  static void hideCurrent() => instance._advance();

  static void clear() {
    instance._timer?.cancel();
    instance._timer = null;
    instance._queue.clear();
    instance._current = null;
    instance.notifyListeners();
  }

  void _show(String message, Duration duration) {
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    if (_current != null) {
      _queue.addLast(normalized);
      return;
    }
    _display(normalized, duration);
  }

  void _display(String message, Duration duration) {
    _timer?.cancel();
    _current = AppNoticeMessage(id: ++_nextId, message: message);
    notifyListeners();
    _timer = Timer(duration, _advance);
  }

  void _advance() {
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) {
      _current = null;
      notifyListeners();
      return;
    }
    _display(_queue.removeFirst(), defaultDuration);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AppNoticeOverlay extends StatelessWidget {
  const AppNoticeOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppNotice.instance,
    builder: (context, _) {
      final notice = AppNotice.instance.current;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (notice != null)
            PositionedDirectional(
              top: 8,
              start: 12,
              end: 12,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      key: ValueKey('app-notice-${notice.id}'),
                      color: Theme.of(context).colorScheme.inverseSurface,
                      elevation: 12,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Semantics(
                        liveRegion: true,
                        child: InkWell(
                          onTap: AppNotice.hideCurrent,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              16,
                              14,
                              16,
                              14,
                            ),
                            child: Text(
                              notice.message,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onInverseSurface,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
