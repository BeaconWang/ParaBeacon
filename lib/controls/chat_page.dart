import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_conversation_tile.dart';
import '../data/chat_service.dart';
import '../data/parabeacon_account_service.dart';
import '../data/pilot_avatar.dart';
import '../l10n/app_localizations.dart';

List<String> chatScopesForChannel(int channelNumber) => [
  'public',
  if (channelNumber > 0) 'channel',
  'direct',
];

Future<void> showChatPage(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const _ChatPage()));

class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage>
    with SingleTickerProviderStateMixin {
  final _chat = ChatService.instance;
  final _messageController = TextEditingController();
  final _accountSearchController = TextEditingController();
  final _accountResultsController = ScrollController();
  final _scrollController = ScrollController();
  late TabController _tabs;
  int _channelNumber =
      ParaBeaconAccountService.instance.user?.channelNumber ?? 0;
  String? _lastProfileImageUrl;

  String _scopeForTab(int index, {int? channelNumber}) {
    final scopes = chatScopesForChannel(channelNumber ?? _channelNumber);
    return scopes[index.clamp(0, scopes.length - 1)];
  }

  int _tabForScope(String scope, {int? channelNumber}) {
    final index = chatScopesForChannel(
      channelNumber ?? _channelNumber,
    ).indexOf(scope);
    return index < 0 ? 0 : index;
  }

  bool _sending = false;
  String? _localError;
  ChatAccount? _selectedRecipient;
  List<ChatConversation> _accountResults = const [];
  String? _accountCursor;
  bool _loadingAccounts = false;
  bool _refreshingDirectory = false;
  final Set<int> _pinningPilots = <int>{};
  String? _accountSearchError;
  Timer? _accountSearchTimer;
  Timer? _directoryRefreshTimer;
  int _accountSearchGeneration = 0;
  Timer? _partnerStatusTimer;
  String? _lastObservedMessageId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: chatScopesForChannel(_channelNumber).length,
      vsync: this,
    )..addListener(_onTabChanged);
    final account = ParaBeaconAccountService.instance;
    _lastProfileImageUrl = account.user?.profileImageUrl;
    account.addListener(_onAccountChannelChanged);
    _accountResultsController.addListener(_onAccountResultsScrolled);
    _chat.addListener(_onChatChanged);
    _partnerStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final recipient = _selectedRecipient;
      if (_scopeForTab(_tabs.index) == 'direct' &&
          _chat.scope == 'direct' &&
          recipient != null &&
          recipient.pilotNumber == _chat.pilotNumber) {
        unawaited(
          _chat.refreshPartnerLocationStatus(
            pilotNumber: recipient.pilotNumber,
          ),
        );
      }
    });
    _directoryRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_scopeForTab(_tabs.index) == 'direct' &&
          _selectedRecipient == null &&
          ParaBeaconAccountService.instance.isSignedIn) {
        unawaited(_refreshConversationDirectory());
      }
    });
    _openTab(0);
  }

  @override
  void dispose() {
    ParaBeaconAccountService.instance.removeListener(_onAccountChannelChanged);
    _chat.removeListener(_onChatChanged);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _messageController.dispose();
    _accountSearchController.dispose();
    _accountResultsController.removeListener(_onAccountResultsScrolled);
    _accountResultsController.dispose();
    _scrollController.dispose();
    _accountSearchTimer?.cancel();
    _directoryRefreshTimer?.cancel();
    _partnerStatusTimer?.cancel();
    if (ParaBeaconAccountService.instance.isSignedIn) {
      unawaited(_chat.openPresence());
    } else {
      unawaited(_chat.disconnect());
    }
    super.dispose();
  }

  void _onChatChanged() {
    final messages = _chat.messages;
    final latestMessageId = messages.isEmpty ? null : messages.last.id;
    final shouldScroll = latestMessageId != _lastObservedMessageId;
    _lastObservedMessageId = latestMessageId;
    if (mounted) setState(() {});
    if (!shouldScroll) return;
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

  void _onAccountChannelChanged() {
    final user = ParaBeaconAccountService.instance.user;
    final next = user?.channelNumber ?? 0;
    final profileImageChanged = user?.profileImageUrl != _lastProfileImageUrl;
    _lastProfileImageUrl = user?.profileImageUrl;
    if (_channelNumber == next) {
      if (mounted) setState(() {});
      if (_scopeForTab(_tabs.index) == 'direct' &&
          _selectedRecipient == null &&
          (profileImageChanged || _accountResults.isEmpty) &&
          ParaBeaconAccountService.instance.isSignedIn) {
        unawaited(_loadConversations(reset: true));
      }
      return;
    }
    final previousScope = _scopeForTab(_tabs.index);
    _channelNumber = next;
    final nextScope = previousScope == 'channel' && next == 0
        ? 'public'
        : previousScope;
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _tabs = TabController(
      length: chatScopesForChannel(next).length,
      initialIndex: _tabForScope(nextScope, channelNumber: next),
      vsync: this,
    )..addListener(_onTabChanged);
    if (mounted) setState(() {});
    unawaited(_openTab(_tabs.index));
  }

  Future<void> _openTab(int index) async {
    final scope = _scopeForTab(index);
    if (scope != 'direct') {
      _selectedRecipient = null;
      _accountSearchTimer?.cancel();
      _accountSearchGeneration++;
      _loadingAccounts = false;
    }
    if (mounted) setState(() => _localError = null);
    try {
      switch (scope) {
        case 'public':
          await _chat.openPublic();
        case 'channel':
          await _chat.openChannel(_channelNumber);
        case 'direct':
          if (_selectedRecipient != null) {
            await _chat.openDirect(_selectedRecipient!.pilotNumber);
          } else {
            await _chat.openPresence();
            if (ParaBeaconAccountService.instance.isSignedIn) {
              unawaited(_loadConversations(reset: true));
            }
          }
      }
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  void _onAccountResultsScrolled() {
    if (!_accountResultsController.hasClients ||
        _accountCursor == null ||
        _loadingAccounts) {
      return;
    }
    final position = _accountResultsController.position;
    if (position.extentAfter < 100) unawaited(_loadConversations());
  }

  void _scheduleAccountSearch(String value) {
    _accountSearchTimer?.cancel();
    _accountSearchGeneration++;
    final query = value.trim();
    if (query.isNotEmpty && query.runes.length < 2) {
      setState(() {
        _accountResults = const [];
        _accountCursor = null;
        _accountSearchError = AppLocalizations.of(context).chatSearchMinimum;
        _loadingAccounts = false;
      });
      return;
    }
    _accountSearchTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadConversations(reset: true));
    });
  }

  Future<void> _loadConversations({bool reset = false}) async {
    if ((_loadingAccounts && !reset) ||
        _scopeForTab(_tabs.index) != 'direct' ||
        _selectedRecipient != null) {
      return;
    }
    if (!reset && _accountCursor == null && _accountResults.isNotEmpty) return;
    final generation = reset
        ? ++_accountSearchGeneration
        : _accountSearchGeneration;
    final query = _accountSearchController.text.trim();
    final cursor = reset ? null : _accountCursor;
    setState(() {
      _loadingAccounts = true;
      _accountSearchError = null;
      if (reset) {
        _accountResults = const [];
        _accountCursor = null;
      }
    });
    try {
      final page = await _chat.listConversations(query: query, cursor: cursor);
      if (!mounted || generation != _accountSearchGeneration) return;
      final existing = _accountResults
          .map((conversation) => conversation.account.pilotNumber)
          .toSet();
      setState(() {
        _accountResults = [
          ..._accountResults,
          ...page.conversations.where(
            (conversation) =>
                !existing.contains(conversation.account.pilotNumber),
          ),
        ];
        _accountCursor = page.nextCursor;
      });
    } on Object catch (error) {
      if (!mounted || generation != _accountSearchGeneration) return;
      setState(() => _accountSearchError = _errorText(error));
    } finally {
      if (mounted && generation == _accountSearchGeneration) {
        setState(() => _loadingAccounts = false);
      }
    }
  }

  Future<void> _refreshConversationDirectory() async {
    if (_refreshingDirectory ||
        _loadingAccounts ||
        _scopeForTab(_tabs.index) != 'direct' ||
        _selectedRecipient != null) {
      return;
    }
    final query = _accountSearchController.text.trim();
    if (query.isNotEmpty && query.runes.length < 2) return;
    _refreshingDirectory = true;
    final generation = _accountSearchGeneration;
    final expectedCount = _accountResults.length;
    try {
      final refreshed = <ChatConversation>[];
      String? cursor;
      do {
        final page = await _chat.listConversations(
          query: query,
          cursor: cursor,
        );
        refreshed.addAll(page.conversations);
        cursor = page.nextCursor;
      } while (cursor != null && refreshed.length < expectedCount);
      if (!mounted ||
          generation != _accountSearchGeneration ||
          _scopeForTab(_tabs.index) != 'direct' ||
          _selectedRecipient != null) {
        return;
      }
      setState(() {
        _accountResults = refreshed;
        _accountCursor = cursor;
      });
    } on Object catch (error) {
      if (mounted && generation == _accountSearchGeneration) {
        setState(() => _accountSearchError = _errorText(error));
      }
    } finally {
      _refreshingDirectory = false;
    }
  }

  Future<void> _toggleConversationPin(ChatConversation conversation) async {
    final account = conversation.account;
    if (_pinningPilots.contains(account.pilotNumber)) return;
    setState(() => _pinningPilots.add(account.pilotNumber));
    try {
      final pinned = await _chat.setConversationPinned(
        pilotNumber: account.pilotNumber,
        pinned: !conversation.pinned,
      );
      if (!mounted) return;
      setState(() {
        _accountResults = [
          for (final current in _accountResults)
            if (current.account.pilotNumber == account.pilotNumber)
              ChatConversation(
                account: current.account,
                online: current.online,
                pinned: pinned,
                lastChatAt: current.lastChatAt,
              )
            else
              current,
        ];
      });
      unawaited(_refreshConversationDirectory());
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    } finally {
      if (mounted) setState(() => _pinningPilots.remove(account.pilotNumber));
    }
  }

  Future<void> _selectRecipient(ChatConversation conversation) async {
    _accountSearchTimer?.cancel();
    _accountSearchGeneration++;
    _loadingAccounts = false;
    final account = conversation.account;
    setState(() {
      _selectedRecipient = account;
      _localError = null;
      _accountSearchError = null;
    });
    try {
      await _chat.openDirect(account.pilotNumber);
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  Future<void> _changeRecipient() async {
    setState(() {
      _selectedRecipient = null;
      _localError = null;
    });
    await _chat.openPresence();
    if (mounted && _scopeForTab(_tabs.index) == 'direct') {
      await _loadConversations(reset: true);
    }
  }

  String _errorText(Object error) {
    final l10n = AppLocalizations.of(context);
    final code = error is ChatException ? error.code : _chat.lastError;
    return switch (code) {
      'pilot_not_found' => l10n.chatPilotNotFound,
      'account_search_query_too_short' => l10n.chatSearchMinimum,
      'rate_limited' => l10n.chatRateLimited,
      'invalid_request' || 'invalid_message' => l10n.chatInvalidMessage,
      'chat_disconnected' => l10n.chatConnecting,
      _ => l10n.chatServiceUnavailable,
    };
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_scopeForTab(_tabs.index) == 'direct' && _selectedRecipient == null) {
      setState(
        () => _localError = AppLocalizations.of(context).chatSelectRecipient,
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
    final selectedRecipient = _selectedRecipient;
    final activeScope = _scopeForTab(_tabs.index);
    final availableScopes = chatScopesForChannel(_channelNumber);

    return Scaffold(
      appBar: AppBar(
        leading: activeScope == 'direct' && selectedRecipient != null
            ? IconButton(
                tooltip: l10n.chatConversations,
                onPressed: _changeRecipient,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          activeScope == 'direct' && selectedRecipient != null
              ? selectedRecipient.title
              : l10n.chatTitle,
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final scope in availableScopes)
              Tab(
                text: switch (scope) {
                  'public' => l10n.chatWorldwide,
                  'channel' => l10n.chatChannel,
                  _ => l10n.chatDirect,
                },
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _connectionBanner(context, connected),
          if (activeScope == 'channel')
            ListTile(
              dense: true,
              leading: const Icon(Icons.tag),
              title: Text(
                l10n.chatChannelNumber(
                  _channelNumber.toString().padLeft(6, '0'),
                ),
              ),
              subtitle: Text(l10n.chatUsesLiveTrackingFilter),
            ),
          if (activeScope == 'direct' && user != null)
            _buildDirectPicker(context, l10n),
          if (activeScope == 'direct' && selectedRecipient != null)
            ListTile(
              dense: true,
              leading: Icon(
                _chat.partnerSharingLocation == true
                    ? Icons.location_on_outlined
                    : _chat.partnerSharingLocation == false
                    ? Icons.location_off_outlined
                    : Icons.location_searching,
                color: _chat.partnerSharingLocation == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                _chat.partnerSharingLocation == true
                    ? l10n.chatPartnerSharingLocation
                    : _chat.partnerSharingLocation == false
                    ? l10n.chatPartnerNotSharingLocation
                    : l10n.chatCheckingLocationStatus,
              ),
            ),
          if (activeScope == 'direct' &&
              selectedRecipient == null &&
              _accountResults.isNotEmpty &&
              _accountSearchError != null)
            MaterialBanner(
              content: Text(_accountSearchError!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _accountSearchError = null),
                  child: Text(l10n.close),
                ),
              ],
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
          else if (activeScope == 'direct' && selectedRecipient == null)
            Expanded(child: _buildConversationList(context, l10n))
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
          if (user != null &&
              (activeScope != 'direct' || selectedRecipient != null))
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
                      onPressed: connected && !_sending ? _send : null,
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

  Widget _buildDirectPicker(BuildContext context, AppLocalizations l10n) {
    final selected = _selectedRecipient;
    if (selected != null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: ListTile(
          leading: PilotAvatarPicture(
            avatarId: selected.avatarId,
            profileImageUrl: selected.profileImageUrl,
            size: 40,
          ),
          title: Text(
            selected.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('@${selected.username}'),
          trailing: IconButton(
            tooltip: l10n.chatChangeRecipient,
            onPressed: _changeRecipient,
            icon: const Icon(Icons.person_search_outlined),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _accountSearchController,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: l10n.chatSearchAccounts,
          hintText: l10n.chatSearchAccountsHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _accountSearchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.clear,
                  onPressed: () {
                    _accountSearchController.clear();
                    _scheduleAccountSearch('');
                  },
                  icon: const Icon(Icons.close),
                ),
          border: const OutlineInputBorder(),
        ),
        onChanged: _scheduleAccountSearch,
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: () => _loadConversations(reset: true),
      child: ListView.builder(
        controller: _accountResultsController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _accountResults.isEmpty
            ? 1
            : _accountResults.length +
                  (_accountCursor != null || _loadingAccounts ? 1 : 0),
        itemBuilder: (context, index) {
          if (_accountResults.isEmpty) {
            if (_loadingAccounts) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 180,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _accountSearchError ??
                        (_chat.hasError
                            ? l10n.chatServiceUnavailable
                            : l10n.chatNoAccountsFound),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (index >= _accountResults.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final conversation = _accountResults[index];
          final lastActivity = conversation.lastChatAt == null
              ? null
              : _formatConversationTime(context, conversation.lastChatAt!);
          return ChatConversationTile(
            conversation: conversation,
            lastChatTime: lastActivity,
            pinning: _pinningPilots.contains(conversation.account.pilotNumber),
            onTap: () => _selectRecipient(conversation),
            onTogglePin: () => _toggleConversationPin(conversation),
          );
        },
      ),
    );
  }

  String _formatConversationTime(BuildContext context, DateTime timestamp) {
    final localTime = timestamp.toLocal();
    final now = DateTime.now();
    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    }
    return MaterialLocalizations.of(context).formatMediumDate(localTime);
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PilotAvatarPicture(
                      avatarId: message.senderAvatarId,
                      profileImageUrl: message.senderProfileImageUrl,
                      size: 18,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
