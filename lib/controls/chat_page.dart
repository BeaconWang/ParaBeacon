import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_service.dart';
import '../data/live_tracking_settings.dart';
import '../data/parabeacon_account_service.dart';
import '../l10n/app_localizations.dart';

Future<void> showChatSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints.expand(),
  builder: (_) => const _ChatPage(),
);

class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage>
    with SingleTickerProviderStateMixin {
  final _chat = ChatService.instance;
  final _messageController = TextEditingController();
  final _directController = TextEditingController();
  final _scrollController = ScrollController();
  late final TabController _tabs;
  late final VoidCallback _filterListener;
  String _channelFilter = LiveTrackingSettings.instance.pilotNumberFilter;
  bool _sending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    _filterListener = _onPilotFilterChanged;
    LiveTrackingSettings.instance.addListener(_filterListener);
    _directController.text = '';
    _chat.addListener(_onChatChanged);
    _openTab(0);
  }

  @override
  void dispose() {
    LiveTrackingSettings.instance.removeListener(_filterListener);
    _chat.removeListener(_onChatChanged);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _messageController.dispose();
    _directController.dispose();
    _scrollController.dispose();
    _chat.disconnect();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    _openTab(_tabs.index);
  }

  void _onPilotFilterChanged() {
    final next = LiveTrackingSettings.instance.pilotNumberFilter;
    if (_channelFilter == next) return;
    _channelFilter = next;
    if (_tabs.index == 1) _openTab(1);
    if (mounted) setState(() {});
  }

  Future<void> _openTab(int index) async {
    setState(() => _localError = null);
    try {
      switch (index) {
        case 0:
          await _chat.openPublic();
        case 1:
          await _chat.openChannel(int.parse(_channelFilter));
        case 2:
          final number = int.tryParse(_directController.text);
          if (number != null && number >= 100000 && number <= 999999) {
            await _chat.openDirect(number);
          } else {
            await _chat.disconnect();
          }
      }
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  Future<void> _openDirect() async {
    final number = int.tryParse(_directController.text);
    if (number == null || number < 100000 || number > 999999) {
      setState(
        () => _localError = AppLocalizations.of(context).chatInvalidPilotNumber,
      );
      return;
    }
    try {
      await _chat.openDirect(number);
      if (mounted) setState(() => _localError = null);
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  String _errorText(Object error) {
    final l10n = AppLocalizations.of(context);
    final code = error is ChatException ? error.code : _chat.lastError;
    return switch (code) {
      'pilot_not_found' => l10n.chatPilotNotFound,
      'rate_limited' => l10n.chatRateLimited,
      'invalid_request' || 'invalid_message' => l10n.chatInvalidMessage,
      'chat_disconnected' => l10n.chatConnecting,
      _ => l10n.chatServiceUnavailable,
    };
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_tabs.index == 2 &&
        int.tryParse(_directController.text) != _chat.pilotNumber) {
      setState(
        () => _localError = AppLocalizations.of(context).chatInvalidPilotNumber,
      );
      return;
    }
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _localError = null;
    });
    try {
      await _chat.send(text);
      _messageController.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ParaBeaconAccountService.instance.user;
    final myPilotNumber = user?.pilotNumber;
    final connected = _chat.state == ChatConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.chatWorldwide),
            Tab(text: l10n.chatChannel),
            Tab(text: l10n.chatDirect),
          ],
        ),
      ),
      body: Column(
        children: [
          _connectionBanner(context, connected),
          if (_tabs.index == 1)
            ListTile(
              dense: true,
              leading: const Icon(Icons.tag),
              title: Text(l10n.chatChannelNumber(_channelFilter)),
              subtitle: Text(l10n.chatUsesLiveTrackingFilter),
            ),
          if (_tabs.index == 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _directController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.chatPilotNumber,
                        hintText: '123456',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _openDirect(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _openDirect,
                    child: Text(l10n.chatOpenConversation),
                  ),
                ],
              ),
            ),
          if (_localError != null)
            MaterialBanner(
              content: Text(_localError!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _localError = null),
                  child: Text(l10n.close),
                ),
              ],
            ),
          if (user == null)
            Expanded(child: Center(child: Text(l10n.chatSignInRequired)))
          else
            Expanded(
              child: _chat.messages.isEmpty
                  ? Center(
                      child: Text(
                        connected ? l10n.chatNoMessages : l10n.chatConnecting,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _chat.messages.length,
                      itemBuilder: (context, index) {
                        final message = _chat.messages[index];
                        final mine = message.senderPilotNumber == myPilotNumber;
                        return _ChatMessageTile(message: message, mine: mine);
                      },
                    ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.chatMessageHint,
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: l10n.chatSend,
                    onPressed: connected && user != null && !_sending
                        ? _send
                        : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionBanner(BuildContext context, bool connected) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: connected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(
              connected ? Icons.circle : Icons.sync,
              size: 12,
              color: connected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _chat.lastError == null
                    ? (connected ? l10n.chatConnected : l10n.chatConnecting)
                    : _errorText(ChatException(_chat.lastError!)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Card(
          color: mine ? theme.colorScheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${message.senderName} · ${message.senderPilotNumber.toString().padLeft(6, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message.text),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (message.scope == 'channel' && message.channelNumber != null)
                  Text(
                    l10n.chatChannelNumber(
                      message.channelNumber.toString().padLeft(6, '0'),
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
