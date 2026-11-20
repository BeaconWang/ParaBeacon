import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../l10n/app_localizations.dart';

class ChatIncomingMessageOverlay extends StatefulWidget {
  const ChatIncomingMessageOverlay({
    required this.child,
    required this.messages,
    required this.onAlert,
    super.key,
  });

  final Widget child;
  final Stream<ChatMessage> messages;
  final VoidCallback onAlert;

  @override
  State<ChatIncomingMessageOverlay> createState() =>
      _ChatIncomingMessageOverlayState();
}

class _ChatIncomingMessageOverlayState extends State<ChatIncomingMessageOverlay>
    with WidgetsBindingObserver {
  StreamSubscription<ChatMessage>? _subscription;
  Timer? _dismissTimer;
  ChatMessage? _visibleMessage;
  ChatMessage? _pendingMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(covariant ChatIncomingMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages) _listen();
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.messages.listen(_onIncomingMessage);
  }

  void _onIncomingMessage(ChatMessage message) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _pendingMessage = message;
      return;
    }
    _show(message);
  }

  void _show(ChatMessage message) {
    _pendingMessage = null;
    _dismissTimer?.cancel();
    widget.onAlert();
    if (mounted) setState(() => _visibleMessage = message);
    _dismissTimer = Timer(const Duration(seconds: 6), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (mounted) setState(() => _visibleMessage = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingMessage != null) {
      _show(_pendingMessage!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_visibleMessage case final message?)
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
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _dismiss,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        8,
                        12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).chatNewMessageFrom(message.senderName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: AppLocalizations.of(context).close,
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close),
                          ),
                        ],
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
}
