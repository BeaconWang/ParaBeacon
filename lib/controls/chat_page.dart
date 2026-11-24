import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_conversation_tile.dart';
import 'chat_emoji.dart';
import '../data/chat_notification_service.dart';
import '../data/chat_service.dart';
import '../data/parabeacon_account_service.dart';
import '../data/pilot_avatar.dart';
import '../l10n/app_localizations.dart';

List<String> chatScopesForChannel(int channelNumber) => [
  'public',
  if (channelNumber > 0) 'channel',
  'direct',
];

Future<void> showChatPage(BuildContext context) {
  unawaited(ChatNotificationService.instance.requestPermission());
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _ChatPage()));
}

enum _ChatAttachmentAction { image, location, voice }

bool _sameCalendarDay(DateTime first, DateTime second) {
  final localFirst = first.toLocal();
  final localSecond = second.toLocal();
  return localFirst.year == localSecond.year &&
      localFirst.month == localSecond.month &&
      localFirst.day == localSecond.day;
}

class _ChatDateSeparator extends StatelessWidget {
  const _ChatDateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final localDate = date.toLocal();
    final label = _sameCalendarDay(localDate, DateTime.now())
        ? AppLocalizations.of(context).chatToday
        : localizations.formatMediumDate(localDate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
      ),
    );
  }
}

class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage>
    with SingleTickerProviderStateMixin {
  final _chat = ChatService.instance;
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _voiceRecorder = AudioRecorder();
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
  bool _voiceRecording = false;
  ChatTarget? _voiceTarget;
  DateTime? _voiceStartedAt;
  Duration _voiceElapsed = Duration.zero;
  String? _activeVoicePath;
  Timer? _voiceElapsedTimer;
  Timer? _voiceLimitTimer;
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
  bool _showJumpToLatest = false;
  int _newMessageCount = 0;

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
    _messageFocusNode.dispose();
    _accountSearchController.dispose();
    _accountResultsController.removeListener(_onAccountResultsScrolled);
    _accountResultsController.dispose();
    _scrollController.dispose();
    _voiceLimitTimer?.cancel();
    _voiceElapsedTimer?.cancel();
    unawaited(_voiceRecorder.dispose());
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
    final wasNearLatest = _isNearLatestMessage;
    _lastObservedMessageId = latestMessageId;
    if (shouldScroll && !wasNearLatest) {
      _newMessageCount++;
      _showJumpToLatest = true;
    }
    if (mounted) setState(() {});
    if (!shouldScroll || !wasNearLatest) return;
    _scrollToLatest();
  }

  bool get _isNearLatestMessage =>
      !_scrollController.hasClients ||
      _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels <
          120;

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController
          .animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted && _showJumpToLatest) {
              setState(() {
                _showJumpToLatest = false;
                _newMessageCount = 0;
              });
            }
          });
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
    if (_voiceRecording) unawaited(_cancelVoiceRecording());
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
                unreadCount: current.unreadCount,
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
      _accountResults = [
        for (final current in _accountResults)
          if (current.account.pilotNumber == account.pilotNumber)
            ChatConversation(
              account: current.account,
              online: current.online,
              pinned: current.pinned,
              unreadCount: 0,
              lastChatAt: current.lastChatAt,
            )
          else
            current,
      ];
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
      'chat_media_too_large' => l10n.chatMediaTooLarge,
      'chat_location_unavailable' => l10n.chatLocationUnavailable,
      'chat_microphone_denied' => l10n.chatMicrophoneDenied,
      'chat_voice_record_failed' => l10n.chatVoiceRecordFailed,
      'chat_conversation_changed' => l10n.chatMediaSendFailed,
      'chat_media_unavailable' ||
      'invalid_chat_media' => l10n.chatMediaSendFailed,
      _ when code?.startsWith('chat_media_http_') == true =>
        l10n.chatMediaSendFailed,
      _ => l10n.chatServiceUnavailable,
    };
  }

  Future<void> _send() async {
    if (_sending || _voiceRecording) return;
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

  bool _canAttach() {
    final l10n = AppLocalizations.of(context);
    if (_sending) return false;
    if (_scopeForTab(_tabs.index) == 'direct' && _selectedRecipient == null) {
      setState(() => _localError = l10n.chatSelectRecipient);
      return false;
    }
    if (_chat.state != ChatConnectionState.connected) {
      setState(() => _localError = l10n.chatConnecting);
      return false;
    }
    return true;
  }

  void _selectAttachment(_ChatAttachmentAction action) {
    switch (action) {
      case _ChatAttachmentAction.image:
        unawaited(_pickAndSendImage());
      case _ChatAttachmentAction.location:
        unawaited(_shareLocation());
      case _ChatAttachmentAction.voice:
        unawaited(_startVoiceRecording());
    }
  }

  Future<void> _pickAndSendImage() async {
    if (!_canAttach()) return;
    final target = _chat.currentTarget;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null ||
          bytes.isEmpty ||
          bytes.length > ChatService.maxImageUploadBytes) {
        if (mounted) {
          setState(
            () => _localError = AppLocalizations.of(context).chatMediaTooLarge,
          );
        }
        return;
      }
      await _uploadAndSendMedia('image', bytes, target);
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  Future<void> _uploadAndSendMedia(
    String kind,
    List<int> bytes,
    ChatTarget target,
  ) async {
    if (_sending) return;
    final caption = _messageController.text;
    setState(() {
      _sending = true;
      _localError = null;
    });
    try {
      final mediaId = await _chat.uploadMedia(
        kind: kind,
        bytes: bytes,
        target: target,
      );
      await _chat.send(caption, kind: kind, mediaId: mediaId, target: target);
      _messageController.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareLocation() async {
    if (!_canAttach()) return;
    final target = _chat.currentTarget;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatLocationConsentTitle),
        content: Text(l10n.chatLocationConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chatShare),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _sending = true;
      _localError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ChatException('chat_location_unavailable');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ChatException('chat_location_unavailable');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _chat.send(
        _messageController.text,
        kind: 'location',
        latitude: position.latitude,
        longitude: position.longitude,
        target: target,
      );
      _messageController.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!_canAttach()) return;
    final target = _chat.currentTarget;
    try {
      if (!await _voiceRecorder.hasPermission()) {
        throw const ChatException('chat_microphone_denied');
      }
      if (!_chat.isCurrentTarget(target)) {
        throw const ChatException('chat_conversation_changed');
      }
      final directory = await getTemporaryDirectory();
      final path = p.join(
        directory.path,
        'pilot-chat-${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) {
        await _voiceRecorder.stop();
        return;
      }
      if (!_chat.isCurrentTarget(target)) {
        await _voiceRecorder.stop();
        throw const ChatException('chat_conversation_changed');
      }
      setState(() {
        _voiceRecording = true;
        _voiceTarget = target;
        _voiceStartedAt = DateTime.now();
        _voiceElapsed = Duration.zero;
        _activeVoicePath = path;
        _localError = null;
      });
      _voiceElapsedTimer?.cancel();
      _voiceElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final startedAt = _voiceStartedAt;
        if (!mounted || startedAt == null) return;
        setState(() => _voiceElapsed = DateTime.now().difference(startedAt));
      });
      _voiceLimitTimer = Timer(
        const Duration(seconds: 90),
        () => unawaited(_finishVoiceRecording()),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_voiceRecording) return;
    _voiceLimitTimer?.cancel();
    _voiceElapsedTimer?.cancel();
    final path = _activeVoicePath;
    _activeVoicePath = null;
    _voiceTarget = null;
    setState(() {
      _voiceRecording = false;
      _voiceStartedAt = null;
      _voiceElapsed = Duration.zero;
      _sending = true;
    });
    try {
      await _voiceRecorder.stop();
    } on Object {
      // A stopped recorder is already cancelled.
    }
    if (path != null) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Temporary cleanup is best-effort.
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _finishVoiceRecording() async {
    if (!_voiceRecording || _sending) return;
    final target = _voiceTarget;
    _voiceTarget = null;
    _activeVoicePath = null;
    _voiceStartedAt = null;
    _voiceLimitTimer?.cancel();
    _voiceElapsedTimer?.cancel();
    setState(() {
      _voiceRecording = false;
      _sending = true;
      _localError = null;
    });
    String? path;
    try {
      path = await _voiceRecorder.stop();
      if (path == null || target == null) {
        throw const ChatException('chat_voice_record_failed');
      }
      if (!mounted || !_chat.isCurrentTarget(target)) {
        throw const ChatException('chat_conversation_changed');
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > ChatService.maxVoiceUploadBytes) {
        throw const ChatException('chat_media_too_large');
      }
      final mediaId = await _chat.uploadMedia(
        kind: 'voice',
        bytes: bytes,
        target: target,
      );
      await _chat.send(
        _messageController.text,
        kind: 'voice',
        mediaId: mediaId,
        target: target,
      );
      _messageController.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _errorText(error));
    } finally {
      _activeVoicePath = null;
      if (mounted) {
        setState(() {
          _voiceStartedAt = null;
          _voiceElapsed = Duration.zero;
        });
      }
      if (path != null) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Temporary cleanup is best-effort.
        }
      }
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
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification &&
                            _isNearLatestMessage &&
                            _showJumpToLatest) {
                          setState(() {
                            _showJumpToLatest = false;
                            _newMessageCount = 0;
                          });
                        }
                        return false;
                      },
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            itemCount: _chat.messages.length,
                            itemBuilder: (context, index) {
                              final message = _chat.messages[index];
                              final previous = index == 0
                                  ? null
                                  : _chat.messages[index - 1];
                              final next = index + 1 < _chat.messages.length
                                  ? _chat.messages[index + 1]
                                  : null;
                              return Column(
                                children: [
                                  if (previous == null ||
                                      !_sameCalendarDay(
                                        previous.createdAt,
                                        message.createdAt,
                                      ))
                                    _ChatDateSeparator(date: message.createdAt),
                                  ChatMessageTile(
                                    message: message,
                                    mine:
                                        message.senderPilotNumber ==
                                        myPilotNumber,
                                    groupedWithPrevious:
                                        previous != null &&
                                        previous.senderPilotNumber ==
                                            message.senderPilotNumber &&
                                        _sameCalendarDay(
                                          previous.createdAt,
                                          message.createdAt,
                                        ) &&
                                        message.createdAt
                                                .difference(previous.createdAt)
                                                .inMinutes <
                                            3,
                                    groupedWithNext:
                                        next != null &&
                                        next.senderPilotNumber ==
                                            message.senderPilotNumber &&
                                        _sameCalendarDay(
                                          next.createdAt,
                                          message.createdAt,
                                        ) &&
                                        next.createdAt
                                                .difference(message.createdAt)
                                                .inMinutes <
                                            3,
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_showJumpToLatest)
                            Positioned(
                              right: 16,
                              bottom: 12,
                              child: FloatingActionButton.small(
                                heroTag: 'chat-jump-to-latest',
                                tooltip: l10n.chatJumpToLatest,
                                onPressed: _scrollToLatest,
                                child: Badge(
                                  isLabelVisible: _newMessageCount > 0,
                                  label: Text('$_newMessageCount'),
                                  child: const Icon(Icons.south),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                    if (_voiceRecording) ...[
                      IconButton(
                        tooltip: l10n.chatCancelVoiceRecording,
                        onPressed: _cancelVoiceRecording,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${l10n.chatRecordingVoice} · ${_formatChatDuration(_voiceElapsed, null)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: l10n.chatStopVoiceRecording,
                        onPressed: _finishVoiceRecording,
                        icon: const Icon(Icons.send),
                      ),
                    ] else ...[
                      PopupMenuButton<_ChatAttachmentAction>(
                        tooltip: l10n.chatAttachMedia,
                        enabled: connected && !_sending,
                        onSelected: _selectAttachment,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _ChatAttachmentAction.image,
                            child: ListTile(
                              leading: const Icon(Icons.image_outlined),
                              title: Text(l10n.chatSendImage),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _ChatAttachmentAction.location,
                            child: ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(l10n.chatShareLocation),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _ChatAttachmentAction.voice,
                            child: ListTile(
                              leading: const Icon(Icons.mic_none),
                              title: Text(l10n.chatRecordVoice),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add_circle_outline),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l10n.chatEmojiPicker,
                        onPressed: _sending ? null : _showEmojiPicker,
                        icon: const Icon(Icons.emoji_emotions_outlined),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: chatMaximumMessageLength,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showEmojiPicker() async {
    final messageValue = _messageController.value;
    _messageFocusNode.unfocus();
    final emoji = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.chatChooseEmoji,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                    itemCount: pilotChatEmojis.length,
                    itemBuilder: (context, index) {
                      final value = pilotChatEmojis[index];
                      return IconButton(
                        tooltip: value,
                        onPressed: () => Navigator.of(context).pop(value),
                        icon: Text(value, style: const TextStyle(fontSize: 26)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (emoji == null || !mounted) return;
    _messageController.value = insertPilotChatEmoji(messageValue, emoji);
    _messageFocusNode.requestFocus();
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

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    required this.message,
    required this.mine,
    this.groupedWithPrevious = false,
    this.groupedWithNext = false,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final bool groupedWithPrevious;
  final bool groupedWithNext;

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
          margin: EdgeInsets.only(
            left: mine ? 36 : 0,
            right: mine ? 0 : 36,
            top: groupedWithPrevious ? 2 : 5,
            bottom: groupedWithNext ? 1 : 5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16).copyWith(
              topLeft: Radius.circular(groupedWithPrevious && !mine ? 5 : 16),
              topRight: Radius.circular(groupedWithPrevious && mine ? 5 : 16),
              bottomLeft: Radius.circular(groupedWithNext && !mine ? 5 : 16),
              bottomRight: Radius.circular(groupedWithNext && mine ? 5 : 16),
            ),
          ),
          color: mine ? theme.colorScheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!groupedWithPrevious)
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
                      if (message.scope != 'direct') ...[
                        const SizedBox(width: 5),
                        Text(
                          message.senderName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                if (message.kind == 'image' && message.mediaId != null)
                  _ChatImageBubble(mediaId: message.mediaId!),
                if (message.kind == 'voice' && message.mediaId != null)
                  _ChatVoiceBubble(mediaId: message.mediaId!),
                if (message.kind == 'location' &&
                    message.latitude != null &&
                    message.longitude != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.chatLocationMessage),
                            SelectableText(
                              '${message.latitude!.toStringAsFixed(5)}, '
                              '${message.longitude!.toStringAsFixed(5)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: l10n.chatOpenLocation,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => unawaited(
                              _openLocation(
                                context,
                                message.latitude!,
                                message.longitude!,
                              ),
                            ),
                            icon: const Icon(Icons.directions_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(message.text),
                ],
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (mine &&
                        message.scope == 'direct' &&
                        message.recipientHasRead != null) ...[
                      Text(
                        message.recipientHasRead!
                            ? l10n.chatRead
                            : l10n.chatNotRead,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if ((message.scope == 'public' ||
                            message.scope == 'channel') &&
                        message.readerCount != null) ...[
                      Text(
                        l10n.chatReaderCount(message.readerCount!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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

  Future<void> _openLocation(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatOpenLocationFailed),
          ),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatOpenLocationFailed),
          ),
        );
      }
    }
  }
}

class _ChatImageBubble extends StatelessWidget {
  const _ChatImageBubble({required this.mediaId});

  final String mediaId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FutureBuilder<Uint8List>(
          future: ChatService.instance.loadMedia(mediaId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox(
                width: 240,
                height: 150,
                child: Center(
                  child: snapshot.hasError
                      ? const Icon(Icons.broken_image_outlined)
                      : const CircularProgressIndicator(),
                ),
              );
            }
            final bytes = snapshot.data!;
            return GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog.fullscreen(
                  backgroundColor: Colors.black,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: Center(child: Image.memory(bytes)),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(dialogContext).top + 8,
                        right: 8,
                        child: IconButton.filledTonal(
                          tooltip: AppLocalizations.of(dialogContext).close,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: Image.memory(
                bytes,
                width: 260,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 240,
                  height: 150,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatVoiceBubble extends StatefulWidget {
  const _ChatVoiceBubble({required this.mediaId});

  final String mediaId;

  @override
  State<_ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<_ChatVoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  Uint8List? _audioBytes;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loadFailed = false;

  bool get _loaded => _audioBytes != null;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bytes = await ChatService.instance.loadMedia(widget.mediaId);
      if (mounted) setState(() => _audioBytes = bytes);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _togglePlayback() async {
    final bytes = _audioBytes;
    if (bytes == null) return;
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(BytesSource(bytes));
      }
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _stateSubscription.cancel();
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.chatVoiceMessage,
          onPressed: _loaded ? _togglePlayback : null,
          icon: Icon(
            _playerState == PlayerState.playing
                ? Icons.pause
                : _loadFailed
                ? Icons.volume_off_outlined
                : _loaded
                ? Icons.play_arrow
                : Icons.graphic_eq,
          ),
        ),
        Text(l10n.chatVoiceMessage),
        const SizedBox(width: 8),
        Text(
          _formatChatDuration(_position, _duration),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

String _formatChatDuration(Duration position, Duration? duration) {
  final remaining = duration == null
      ? position
      : duration - position < Duration.zero
      ? Duration.zero
      : duration - position;
  final minutes = remaining.inMinutes.toString().padLeft(2, '0');
  final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
