import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../data/pilot_avatar.dart';
import '../l10n/app_localizations.dart';

class ChatConversationTile extends StatelessWidget {
  const ChatConversationTile({
    required this.conversation,
    required this.lastChatTime,
    required this.pinning,
    required this.onTap,
    required this.onTogglePin,
    super.key,
  });

  final ChatConversation conversation;
  final String? lastChatTime;
  final bool pinning;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = conversation.account;
    final subtitle = [
      '@${account.username}',
      conversation.online ? l10n.chatPilotOnline : l10n.chatPilotOffline,
      if (lastChatTime != null) l10n.chatLastChatTime(lastChatTime!),
    ].join(' · ');

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          PilotAvatarPicture(
            avatarId: account.avatarId,
            profileImageUrl: account.profileImageUrl,
            size: 40,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: conversation.online
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.outlineVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(account.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.chatUnreadMessages(conversation.unreadCount),
            child: Container(
              key: ValueKey('chat-unread-count-${account.pilotNumber}'),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: conversation.unreadCount > 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : conversation.unreadCount.toString(),
                style: TextStyle(
                  color: conversation.unreadCount > 0
                      ? Theme.of(context).colorScheme.onError
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: conversation.pinned
                ? l10n.chatUnpinConversation
                : l10n.chatPinConversation,
            onPressed: pinning ? null : onTogglePin,
            icon: Icon(
              conversation.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: conversation.pinned
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
