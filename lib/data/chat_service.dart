import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../live/ws_connect.dart';
import 'parabeacon_account_service.dart';
import 'parabeacon_server_config.dart';
import 'pilot_avatar.dart';
import 'profile_image_url.dart';
import 'user_agent_settings.dart';

enum ChatConnectionState { disconnected, connecting, connected, reconnecting }

@immutable
class ChatTarget {
  const ChatTarget({
    required this.scope,
    this.channelNumber = 0,
    this.pilotNumber = 0,
    this.accountId,
  });

  final String scope;
  final int channelNumber;
  final int pilotNumber;
  final String? accountId;
}

@immutable
class ChatAccount {
  const ChatAccount({
    required this.pilotNumber,
    required this.username,
    required this.displayName,
    this.avatarId = PilotAvatar.defaultId,
    this.profileImageUrl,
  });

  final int pilotNumber;
  final String username;
  final String displayName;
  final int avatarId;
  final String? profileImageUrl;

  String get title => displayName.isNotEmpty ? displayName : username;

  static ChatAccount? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final pilotNumber = raw['pilot_number'];
    final username = raw['username'];
    final displayName = raw['display_name'] ?? '';
    final avatarId = raw['avatar_id'] ?? PilotAvatar.defaultId;
    final rawProfileImageUrl = raw['profile_image_url'];
    final profileImageUrl = rawProfileImageUrl == null
        ? null
        : rawProfileImageUrl is String &&
              ProfileImageUrl.resolve(rawProfileImageUrl) != null
        ? rawProfileImageUrl
        : null;
    if ((rawProfileImageUrl != null && profileImageUrl == null) ||
        pilotNumber is! int ||
        pilotNumber < 100000 ||
        pilotNumber > 999999 ||
        username is! String ||
        username.trim().isEmpty ||
        displayName is! String ||
        avatarId is! int ||
        !PilotAvatar.isValid(avatarId)) {
      return null;
    }
    return ChatAccount(
      pilotNumber: pilotNumber,
      username: username.trim(),
      displayName: displayName.trim(),
      avatarId: avatarId,
      profileImageUrl: profileImageUrl,
    );
  }
}

@immutable
class ChatAccountPage {
  const ChatAccountPage({required this.accounts, this.nextCursor});

  final List<ChatAccount> accounts;
  final String? nextCursor;
}

@immutable
class ChatConversation {
  const ChatConversation({
    required this.account,
    required this.online,
    required this.pinned,
    this.unreadCount = 0,
    this.lastChatAt,
  });

  final ChatAccount account;
  final bool online;
  final bool pinned;
  final int unreadCount;
  final DateTime? lastChatAt;

  static ChatConversation? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final account = ChatAccount.fromJson(raw);
    final online = raw['online'];
    final pinned = raw['pinned'];
    final rawUnreadCount = raw['unread_count'] ?? 0;
    final rawLastChatAt = raw['last_chat_at'];
    if (account == null ||
        online is! bool ||
        pinned is! bool ||
        rawUnreadCount is! int ||
        rawUnreadCount < 0) {
      return null;
    }
    final lastChatAt = rawLastChatAt == null
        ? null
        : rawLastChatAt is String
        ? DateTime.tryParse(rawLastChatAt)?.toUtc()
        : null;
    if (rawLastChatAt != null && lastChatAt == null) return null;
    return ChatConversation(
      account: account,
      online: online,
      pinned: pinned,
      unreadCount: rawUnreadCount,
      lastChatAt: lastChatAt,
    );
  }
}

@immutable
class ChatConversationPage {
  const ChatConversationPage({required this.conversations, this.nextCursor});

  final List<ChatConversation> conversations;
  final String? nextCursor;
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.scope,
    required this.senderPilotNumber,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.channelNumber,
    this.recipientPilotNumber,
    this.senderAvatarId = PilotAvatar.defaultId,
    this.senderProfileImageUrl,
    this.recipientHasRead,
    this.readerCount,
    this.kind = 'text',
    this.mediaId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String scope;
  final int senderPilotNumber;
  final String senderName;
  final int? channelNumber;
  final int? recipientPilotNumber;
  final int senderAvatarId;
  final String? senderProfileImageUrl;
  final bool? recipientHasRead;
  final int? readerCount;
  final String text;
  final DateTime createdAt;
  final String kind;
  final String? mediaId;
  final double? latitude;
  final double? longitude;

  static final _mediaIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static ChatMessage? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final scope = raw['scope'];
    final senderNumber = raw['sender_pilot_number'];
    final senderName = raw['sender_name'];
    final text = raw['text'];
    final kind = raw['kind'] ?? 'text';
    final mediaId = raw['media_id'];
    final rawLatitude = raw['latitude'];
    final rawLongitude = raw['longitude'];
    final latitude = rawLatitude is num ? rawLatitude.toDouble() : null;
    final longitude = rawLongitude is num ? rawLongitude.toDouble() : null;
    final timestamp = raw['created_at'];
    final channel = raw['channel_number'];
    final recipient = raw['recipient_pilot_number'];
    final recipientHasRead = raw['recipient_has_read'];
    final readerCount = raw['reader_count'];
    final senderAvatarId = raw['sender_avatar_id'] ?? PilotAvatar.defaultId;
    final rawSenderProfileImageUrl = raw['sender_profile_image_url'];
    final senderProfileImageUrl = rawSenderProfileImageUrl == null
        ? null
        : rawSenderProfileImageUrl is String &&
              ProfileImageUrl.resolve(rawSenderProfileImageUrl) != null
        ? rawSenderProfileImageUrl
        : null;
    final validText = text is String && text.runes.length <= 1000;
    final validMediaID =
        mediaId is String &&
        _mediaIdPattern.hasMatch(mediaId) &&
        mediaId != '00000000-0000-0000-0000-000000000000';
    final validContent = switch (kind) {
      'text' =>
        validText &&
            text.trim().isNotEmpty &&
            mediaId == null &&
            rawLatitude == null &&
            rawLongitude == null,
      'image' || 'voice' =>
        validText &&
            validMediaID &&
            rawLatitude == null &&
            rawLongitude == null,
      'location' =>
        validText &&
            mediaId == null &&
            rawLatitude is num &&
            rawLongitude is num &&
            latitude!.isFinite &&
            longitude!.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180,
      _ => false,
    };
    if ((rawSenderProfileImageUrl != null && senderProfileImageUrl == null) ||
        id is! String ||
        id.isEmpty ||
        (scope != 'public' && scope != 'channel' && scope != 'direct') ||
        senderNumber is! int ||
        senderNumber < 100000 ||
        senderNumber > 999999 ||
        senderName is! String ||
        senderName.trim().isEmpty ||
        senderAvatarId is! int ||
        !PilotAvatar.isValid(senderAvatarId) ||
        !validContent ||
        text is! String ||
        timestamp is! String ||
        (channel != null &&
            (channel is! int || channel < 0 || channel > 999999)) ||
        (recipient != null &&
            (recipient is! int || recipient < 100000 || recipient > 999999)) ||
        (recipientHasRead != null && recipientHasRead is! bool) ||
        (readerCount != null && (readerCount is! int || readerCount < 0))) {
      return null;
    }
    final createdAt = DateTime.tryParse(timestamp);
    if (createdAt == null) return null;
    return ChatMessage(
      id: id,
      scope: scope as String,
      senderPilotNumber: senderNumber,
      senderName: senderName.trim(),
      senderAvatarId: senderAvatarId,
      senderProfileImageUrl: senderProfileImageUrl,
      recipientHasRead: recipientHasRead as bool?,
      readerCount: readerCount as int?,
      channelNumber: channel as int?,
      recipientPilotNumber: recipient as int?,
      text: text,
      createdAt: createdAt.toUtc(),
      kind: kind as String,
      mediaId: mediaId as String?,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class ChatService extends ChangeNotifier {
  static const maxImageUploadBytes = 8 * 1024 * 1024;
  static const maxVoiceUploadBytes = 12 * 1024 * 1024;

  ChatService({
    required ParaBeaconAccountService accountService,
    http.Client? httpClient,
  }) : _account = accountService,
       _http = UserAgentHttpClient(innerClient: httpClient) {
    _ownsHttpClient = httpClient == null;
    _lastAccountProfileImageUrl = _account.user?.profileImageUrl;
    _lastAccountChannelNumber = _account.user?.channelNumber;
    _account.addListener(_onAccountChanged);
  }

  static final ChatService instance = ChatService(
    accountService: ParaBeaconAccountService.instance,
  );

  final ParaBeaconAccountService _account;
  late final http.Client _http;
  late final bool _ownsHttpClient;
  final List<ChatMessage> _messages = <ChatMessage>[];
  final StreamController<ChatMessage> _incomingChatMessages =
      StreamController<ChatMessage>.broadcast(sync: true);
  final Queue<String> _incomingMessageOrder = Queue<String>();
  final Set<String> _incomingMessageIds = <String>{};
  final LinkedHashMap<String, Uint8List> _mediaCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _mediaRequests =
      <String, Future<Uint8List>>{};
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Stream<ChatMessage> get incomingChatMessages => _incomingChatMessages.stream;

  ChatConnectionState _state = ChatConnectionState.disconnected;
  ChatConnectionState get state => _state;
  String? _lastError;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;
  String _scope = 'public';
  String get scope => _scope;
  int _channelNumber = 0;
  int get channelNumber => _channelNumber;
  int _pilotNumber = 0;
  int get pilotNumber => _pilotNumber;
  ChatTarget get currentTarget => ChatTarget(
    scope: _scope,
    channelNumber: _channelNumber,
    pilotNumber: _pilotNumber,
    accountId: _account.user?.id,
  );
  bool isCurrentTarget(ChatTarget target) =>
      target.scope == _scope &&
      target.channelNumber == _channelNumber &&
      target.pilotNumber == _pilotNumber &&
      target.accountId == _account.user?.id;
  bool? _partnerSharingLocation;
  bool? get partnerSharingLocation => _partnerSharingLocation;
  int _conversationEpoch = 0;
  bool _disposed = false;
  bool _connecting = false;
  bool _desiredConnection = false;
  int _attempt = 0;
  int _connectionGeneration = 0;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _stableTimer;
  Future<void>? _historyFuture;
  int _historyEpoch = -1;
  String? _lastAccountProfileImageUrl;
  int? _lastAccountChannelNumber;

  Uri get _apiBase => ParaBeaconServerConfig.apiBaseUri;

  Future<void> maintainPresence() async {
    if (!_account.isSignedIn) await _account.load();
    if (!_account.isSignedIn || _desiredConnection) return;
    await openPresence();
  }

  void _onAccountChanged() {
    _mediaCache.clear();
    final currentProfileImageUrl = _account.user?.profileImageUrl;
    final profileImageChanged =
        currentProfileImageUrl != _lastAccountProfileImageUrl;
    _lastAccountProfileImageUrl = currentProfileImageUrl;
    final currentChannelNumber = _account.user?.channelNumber ?? 0;
    final channelChanged = currentChannelNumber != _lastAccountChannelNumber;
    _lastAccountChannelNumber = currentChannelNumber;
    if (profileImageChanged && _desiredConnection && _scope != 'presence') {
      unawaited(loadHistory().catchError((Object _) {}));
    }
    if (channelChanged &&
        _desiredConnection &&
        _state == ChatConnectionState.connected) {
      _subscribeCurrent();
    }
    if (!_account.isSignedIn) {
      if (_desiredConnection) unawaited(disconnect());
      return;
    }
    if (_desiredConnection && _state == ChatConnectionState.disconnected) {
      unawaited(_connect());
    }
  }

  Future<void> openPresence() async {
    _conversationEpoch++;
    _scope = 'presence';
    _channelNumber = 0;
    _pilotNumber = 0;
    _partnerSharingLocation = null;
    _messages.clear();
    _notify();
    _desiredConnection = true;
    if (_state != ChatConnectionState.connected) {
      await _connect();
    } else {
      _subscribeCurrent();
    }
  }

  Future<void> openPublic() => openConversation(scope: 'public');

  Future<void> openChannel(int channelNumber) {
    if (channelNumber < 0 || channelNumber > 999999) {
      throw ArgumentError.value(channelNumber, 'channelNumber');
    }
    return openConversation(scope: 'channel', channelNumber: channelNumber);
  }

  Future<void> openDirect(int pilotNumber) {
    if (pilotNumber < 100000 || pilotNumber > 999999) {
      throw ArgumentError.value(pilotNumber, 'pilotNumber');
    }
    return openConversation(scope: 'direct', pilotNumber: pilotNumber);
  }

  Future<void> openConversation({
    required String scope,
    int channelNumber = 0,
    int pilotNumber = 0,
  }) async {
    if (scope != 'public' && scope != 'channel' && scope != 'direct') {
      throw ArgumentError.value(scope, 'scope');
    }
    if (scope == 'public' && (channelNumber != 0 || pilotNumber != 0) ||
        scope == 'channel' &&
            (channelNumber < 0 || channelNumber > 999999 || pilotNumber != 0) ||
        scope == 'direct' &&
            (channelNumber != 0 ||
                pilotNumber < 100000 ||
                pilotNumber > 999999)) {
      throw ArgumentError('Invalid chat conversation address.');
    }
    _conversationEpoch++;
    _scope = scope;
    _channelNumber = channelNumber;
    _pilotNumber = pilotNumber;
    _partnerSharingLocation = null;
    _messages.clear();
    _notify();
    if (scope == 'direct') {
      unawaited(refreshPartnerLocationStatus(pilotNumber: pilotNumber));
    }
    _desiredConnection = true;
    if (_state != ChatConnectionState.connected) {
      await _connect();
    } else {
      _subscribeCurrent();
      await loadHistory();
    }
  }

  Future<void> refreshPartnerLocationStatus({int? pilotNumber}) async {
    final target = pilotNumber ?? _pilotNumber;
    if (_scope != 'direct' || target < 100000 || target > 999999) {
      _partnerSharingLocation = null;
      _notify();
      return;
    }
    final epoch = _conversationEpoch;
    final uri = _apiBase.resolve('/api/v1/chat/pilots/$target/location-status');
    try {
      final response = await _sendRequest(
        'GET',
        uri,
      ).timeout(const Duration(seconds: 8));
      final decoded = response.statusCode == 200
          ? jsonDecode(response.body)
          : null;
      final status = parsePartnerLocationStatus(decoded);
      if (epoch != _conversationEpoch ||
          _scope != 'direct' ||
          target != _pilotNumber) {
        return;
      }
      _partnerSharingLocation = status;
      _notify();
    } on Object {
      if (epoch != _conversationEpoch || target != _pilotNumber) return;
      _partnerSharingLocation = null;
      _notify();
    }
  }

  static bool? parsePartnerLocationStatus(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final status = value['actively_sharing_location'];
    return status is bool ? status : null;
  }

  Future<void> loadHistory() {
    if (_scope == 'presence') return Future<void>.value();
    final active = _historyFuture;
    if (active != null && _historyEpoch == _conversationEpoch) return active;
    final epoch = _conversationEpoch;
    final scope = _scope;
    final channelNumber = _channelNumber;
    final pilotNumber = _pilotNumber;
    final future = _loadHistoryOnce(epoch, scope, channelNumber, pilotNumber);
    _historyEpoch = epoch;
    _historyFuture = future;
    return future.whenComplete(() {
      if (identical(_historyFuture, future)) _historyFuture = null;
    });
  }

  Future<void> _loadHistoryOnce(
    int epoch,
    String scope,
    int channelNumber,
    int pilotNumber,
  ) async {
    final query = <String, String>{'scope': scope};
    if (scope == 'channel') {
      query['channel_number'] = channelNumber.toString();
    }
    if (scope == 'direct') query['pilot_number'] = pilotNumber.toString();
    final uri = _apiBase
        .resolve('/api/v1/chat/messages')
        .replace(queryParameters: query);
    try {
      final response = await _sendRequest(
        'GET',
        uri,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatException('history_http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['messages'] is! List) {
        throw const ChatException('invalid_history');
      }
      if (epoch != _conversationEpoch || scope != _scope) return;
      final loaded = (decoded['messages'] as List)
          .map(ChatMessage.fromJson)
          .whereType<ChatMessage>();
      _mergeMessages(loaded);
      _lastError = null;
      _notify();
      if (scope == 'direct') {
        await markConversationRead(
          pilotNumber: pilotNumber,
        ).catchError((Object _) {});
      }
    } on Object catch (error) {
      if (epoch != _conversationEpoch || scope != _scope) return;
      _lastError = _errorCode(error);
      _notify();
      rethrow;
    }
  }

  Future<void> send(
    String text, {
    String kind = 'text',
    String? mediaId,
    double? latitude,
    double? longitude,
    ChatTarget? target,
  }) async {
    final sendTarget = target ?? currentTarget;
    if (!isCurrentTarget(sendTarget)) {
      throw const ChatException('chat_conversation_changed');
    }
    final normalized = text.trim();
    final validText = normalized.runes.length <= 1000;
    final validContent = switch (kind) {
      'text' =>
        normalized.isNotEmpty &&
            mediaId == null &&
            latitude == null &&
            longitude == null,
      'image' || 'voice' =>
        mediaId != null &&
            ChatMessage._mediaIdPattern.hasMatch(mediaId) &&
            latitude == null &&
            longitude == null,
      'location' =>
        mediaId == null &&
            latitude != null &&
            longitude != null &&
            latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180,
      _ => false,
    };
    if (!validText || !validContent) {
      throw const ChatException('invalid_message');
    }
    final channel = _channel;
    if (channel == null || _state != ChatConnectionState.connected) {
      throw const ChatException('chat_disconnected');
    }
    final payload = <String, Object>{
      'type': 'send',
      'scope': sendTarget.scope,
      'text': normalized,
      'kind': kind,
    };
    if (mediaId != null) payload['media_id'] = mediaId;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (sendTarget.scope == 'channel') {
      payload['channel_number'] = sendTarget.channelNumber;
    }
    if (sendTarget.scope == 'direct') {
      payload['pilot_number'] = sendTarget.pilotNumber;
    }
    try {
      channel.sink.add(jsonEncode(payload));
    } on Object catch (error) {
      _lastError = _errorCode(error);
      _scheduleReconnect(error);
      _notify();
      rethrow;
    }
  }

  Future<String> uploadMedia({
    required String kind,
    required List<int> bytes,
    ChatTarget? target,
  }) async {
    final uploadTarget = target ?? currentTarget;
    if (!isCurrentTarget(uploadTarget)) {
      throw const ChatException('chat_conversation_changed');
    }
    final limit = switch (kind) {
      'image' => maxImageUploadBytes,
      'voice' => maxVoiceUploadBytes,
      _ => 0,
    };
    if (limit == 0 || bytes.isEmpty || bytes.length > limit) {
      throw const ChatException('chat_media_too_large');
    }
    if (!_account.isSignedIn || !_isTrustedApiUri(_apiBase)) {
      throw const ChatException('chat_media_unavailable');
    }
    final uri = _apiBase.resolve('/api/v1/chat/media');
    if (!_isTrustedApiUri(uri)) {
      throw const ChatException('untrusted_chat_uri');
    }
    final authorizationHeaders = await _account.authorizationHeaders();
    if (!isCurrentTarget(uploadTarget)) {
      throw const ChatException('chat_conversation_changed');
    }
    final request = http.MultipartRequest('POST', uri)
      ..followRedirects = false
      ..headers.addAll(authorizationHeaders)
      ..fields['kind'] = kind
      ..fields['scope'] = uploadTarget.scope;
    if (uploadTarget.scope == 'channel') {
      request.fields['channel_number'] = uploadTarget.channelNumber.toString();
    }
    if (uploadTarget.scope == 'direct') {
      request.fields['pilot_number'] = uploadTarget.pilotNumber.toString();
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: kind == 'image' ? 'chat-image.jpg' : 'chat-voice.m4a',
      ),
    );
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(const Duration(seconds: 15));
    if (!isCurrentTarget(uploadTarget)) {
      throw const ChatException('chat_conversation_changed');
    }
    if (response.statusCode != 201) {
      if (response.statusCode == 400 || response.statusCode == 413) {
        throw const ChatException('chat_media_too_large');
      }
      throw ChatException('chat_media_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final mediaId = decoded is Map<String, dynamic>
        ? decoded['media_id']
        : null;
    if (mediaId is! String || !ChatMessage._mediaIdPattern.hasMatch(mediaId)) {
      throw const ChatException('invalid_chat_media_response');
    }
    return mediaId;
  }

  Future<Uint8List> loadMedia(String mediaId) {
    if (!_account.isSignedIn) {
      return Future<Uint8List>.error(
        const ChatException('chat_media_unavailable'),
      );
    }
    if (!ChatMessage._mediaIdPattern.hasMatch(mediaId)) {
      return Future<Uint8List>.error(const ChatException('invalid_chat_media'));
    }
    final cached = _mediaCache.remove(mediaId);
    if (cached != null) {
      _mediaCache[mediaId] = cached;
      return Future<Uint8List>.value(cached);
    }
    final inFlight = _mediaRequests[mediaId];
    if (inFlight != null) return inFlight;
    final request = _fetchMedia(mediaId);
    _mediaRequests[mediaId] = request;
    return request.whenComplete(() => _mediaRequests.remove(mediaId));
  }

  Future<Uint8List> _fetchMedia(String mediaId) async {
    final accountID = _account.user?.id;
    if (!_account.isSignedIn || accountID == null) {
      throw const ChatException('chat_media_unavailable');
    }
    final uri = _apiBase.resolve('/api/v1/chat/media/$mediaId');
    if (!_isTrustedApiUri(uri)) {
      throw const ChatException('untrusted_chat_uri');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'image/jpeg, audio/mp4',
        ...await _account.authorizationHeaders(),
      });
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (!_account.isSignedIn || _account.user?.id != accountID) {
      throw const ChatException('chat_media_unavailable');
    }
    if (response.statusCode != 200) {
      throw ChatException('chat_media_http_${response.statusCode}');
    }
    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final limit = switch (contentType) {
      'image/jpeg' => maxImageUploadBytes,
      'audio/mp4' => maxVoiceUploadBytes,
      _ => 0,
    };
    if (limit == 0 ||
        response.contentLength != null && response.contentLength! > limit) {
      throw const ChatException('invalid_chat_media');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      builder.add(chunk);
      if (builder.length > limit) {
        throw const ChatException('invalid_chat_media');
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) throw const ChatException('invalid_chat_media');
    _mediaCache[mediaId] = bytes;
    while (_mediaCache.length > 4) {
      _mediaCache.remove(_mediaCache.keys.first);
    }
    return bytes;
  }

  bool _isTrustedApiUri(Uri uri) =>
      uri.scheme == _apiBase.scheme &&
      uri.host.toLowerCase() == _apiBase.host.toLowerCase() &&
      uri.port == _apiBase.port &&
      uri.userInfo.isEmpty;

  Future<void> markConversationRead({required int pilotNumber}) async {
    if (pilotNumber < 100000 || pilotNumber > 999999) {
      throw const ChatException('invalid_request');
    }
    final uri = _apiBase.resolve(
      '/api/v1/chat/conversations/$pilotNumber/read',
    );
    final response = await _sendRequest(
      'PUT',
      uri,
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException('read_http_${response.statusCode}');
    }
  }

  Future<ChatConversationPage> listConversations({
    String query = '',
    String? cursor,
    int limit = 30,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty && normalizedQuery.runes.length < 2) {
      throw const ChatException('account_search_query_too_short');
    }
    final parameters = <String, String>{
      'limit': limit.toString(),
      if (normalizedQuery.isNotEmpty) 'q': normalizedQuery,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = _apiBase
        .resolve('/api/v1/chat/conversations')
        .replace(queryParameters: parameters);
    final response = await _sendRequest(
      'GET',
      uri,
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException('conversations_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['conversations'] is! List) {
      throw const ChatException('invalid_conversations_response');
    }
    final conversations = (decoded['conversations'] as List)
        .map(ChatConversation.fromJson)
        .whereType<ChatConversation>()
        .toList(growable: false);
    final nextCursor = decoded['next_cursor'];
    if (nextCursor != null && nextCursor is! String) {
      throw const ChatException('invalid_conversations_response');
    }
    return ChatConversationPage(
      conversations: conversations,
      nextCursor: nextCursor is String && nextCursor.isNotEmpty
          ? nextCursor
          : null,
    );
  }

  Future<bool> setConversationPinned({
    required int pilotNumber,
    required bool pinned,
  }) async {
    if (pilotNumber < 100000 || pilotNumber > 999999) {
      throw const ChatException('invalid_request');
    }
    final uri = _apiBase.resolve('/api/v1/chat/conversations/$pilotNumber/pin');
    final response = await _sendRequest(
      'PUT',
      uri,
      body: {'pinned': pinned},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException('pin_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['pinned'] is! bool) {
      throw const ChatException('invalid_pin_response');
    }
    return decoded['pinned'] as bool;
  }

  Future<ChatAccountPage> searchAccounts({
    String query = '',
    String? cursor,
    int limit = 30,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty && normalizedQuery.runes.length < 2) {
      throw const ChatException('account_search_query_too_short');
    }
    final parameters = <String, String>{
      'limit': limit.toString(),
      if (normalizedQuery.isNotEmpty) 'q': normalizedQuery,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = _apiBase
        .resolve('/api/v1/chat/accounts')
        .replace(queryParameters: parameters);
    final response = await _sendRequest(
      'GET',
      uri,
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException('accounts_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['accounts'] is! List) {
      throw const ChatException('invalid_accounts_response');
    }
    final rawAccounts = decoded['accounts'] as List<dynamic>;
    final accounts = rawAccounts
        .map(ChatAccount.fromJson)
        .whereType<ChatAccount>()
        .toList(growable: false);
    final nextCursor = decoded['next_cursor'];
    if (nextCursor != null && nextCursor is! String) {
      throw const ChatException('invalid_accounts_response');
    }
    return ChatAccountPage(
      accounts: accounts,
      nextCursor: nextCursor is String && nextCursor.isNotEmpty
          ? nextCursor
          : null,
    );
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    Object? body,
  }) async {
    if (uri.scheme != _apiBase.scheme ||
        uri.host.toLowerCase() != _apiBase.host.toLowerCase() ||
        uri.port != _apiBase.port ||
        uri.userInfo.isNotEmpty) {
      throw const ChatException('untrusted_chat_uri');
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        ...await _account.authorizationHeaders(),
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 15));
    return http.Response.fromStream(streamed);
  }

  Future<String> _issueSocketTicket() async {
    final uri = _apiBase.resolve('/api/v1/chat/socket-ticket');
    final response = await _sendRequest('POST', uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException('ticket_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['ticket'] is! String ||
        (decoded['ticket'] as String).isEmpty) {
      throw const ChatException('invalid_ticket');
    }
    return decoded['ticket'] as String;
  }

  Future<void> _connect() async {
    if (_connecting ||
        !_desiredConnection ||
        _disposed ||
        !_account.isSignedIn) {
      return;
    }
    _connecting = true;
    final generation = ++_connectionGeneration;
    _setState(
      _attempt == 0
          ? ChatConnectionState.connecting
          : ChatConnectionState.reconnecting,
    );
    WebSocketChannel? socket;
    try {
      final ticket = await _issueSocketTicket();
      if (generation != _connectionGeneration ||
          !_desiredConnection ||
          _disposed) {
        return;
      }
      final base = _apiBase;
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/api/v1/chat/ws',
        queryParameters: {'ticket': ticket},
      );
      final connectedSocket = connectWebSocket(
        uri,
        pingInterval: const Duration(seconds: 25),
      );
      socket = connectedSocket;
      await connectedSocket.ready.timeout(const Duration(seconds: 12));
      if (generation != _connectionGeneration ||
          !_desiredConnection ||
          _disposed) {
        await connectedSocket.sink.close();
        return;
      }
      _channel = connectedSocket;
      _lastError = null;
      _attempt = 0;
      _setState(ChatConnectionState.connected);
      _subscription = connectedSocket.stream.listen(
        _onMessage,
        onError: (Object error) => _scheduleReconnect(error),
        onDone: () => _scheduleReconnect(null),
        cancelOnError: false,
      );
      _subscribeCurrent();
      _stableTimer?.cancel();
      _stableTimer = Timer(const Duration(seconds: 30), () => _attempt = 0);
      if (_scope != 'presence') {
        unawaited(loadHistory().catchError((Object _) {}));
      }
    } on Object catch (error) {
      if (generation == _connectionGeneration) {
        if (socket != null) await socket.sink.close();
        _scheduleReconnect(error);
      }
    } finally {
      _connecting = false;
      if (generation != _connectionGeneration &&
          _desiredConnection &&
          !_disposed) {
        unawaited(_connect());
      }
    }
  }

  void _subscribeCurrent() {
    final socket = _channel;
    if (socket == null) return;
    final payload = <String, Object>{'type': 'subscribe', 'scope': _scope};
    final accountChannelNumber = _account.user?.channelNumber ?? 0;
    final notificationChannelNumber = _scope == 'channel'
        ? _channelNumber
        : accountChannelNumber;
    if (notificationChannelNumber > 0) {
      payload['channel_number'] = notificationChannelNumber;
    }
    if (_scope == 'direct') payload['pilot_number'] = _pilotNumber;
    socket.sink.add(jsonEncode(payload));
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String
          ? raw
          : raw is List<int>
          ? utf8.decode(raw)
          : null;
      if (text == null) return;
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['type'] == 'error') {
        _lastError = decoded['error'] is String
            ? decoded['error'] as String
            : 'chat_error';
        _notify();
        return;
      }
      if (decoded['type'] != 'message') return;
      final message = ChatMessage.fromJson(decoded['message']);
      if (message == null) return;
      final myPilotNumber = _account.user?.pilotNumber;
      final isFromAnotherPilot =
          myPilotNumber != null && message.senderPilotNumber != myPilotNumber;
      final isIncomingMessage = switch (message.scope) {
        'public' || 'channel' => isFromAnotherPilot,
        'direct' =>
          isFromAnotherPilot && message.recipientPilotNumber == myPilotNumber,
        _ => false,
      };
      final messageScopeIsOpen = switch (message.scope) {
        'public' => _scope == 'public',
        'channel' =>
          _scope == 'channel' && message.channelNumber == _channelNumber,
        'direct' =>
          _scope == 'direct' && _pilotNumber == message.senderPilotNumber,
        _ => false,
      };
      final appIsResumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (isIncomingMessage &&
          !(appIsResumed && messageScopeIsOpen) &&
          _incomingMessageIds.add(message.id)) {
        _incomingChatMessages.add(message);
        _incomingMessageOrder.addLast(message.id);
        if (_incomingMessageOrder.length > 300) {
          _incomingMessageIds.remove(_incomingMessageOrder.removeFirst());
        }
      }
      if (!_matchesConversation(message)) return;
      _lastError = null;
      _mergeMessages([message]);
      _notify();
      if (_scope == 'direct' &&
          message.senderPilotNumber != _account.user?.pilotNumber) {
        unawaited(
          markConversationRead(
            pilotNumber: _pilotNumber,
          ).catchError((Object _) {}),
        );
      }
    } on Object catch (error) {
      _lastError = _errorCode(error);
      _notify();
    }
  }

  bool _matchesConversation(ChatMessage message) {
    switch (_scope) {
      case 'public':
        return message.scope == 'public';
      case 'channel':
        return message.scope == 'channel' &&
            message.channelNumber == _channelNumber;
      case 'direct':
        final myNumber = _account.user?.pilotNumber;
        return message.scope == 'direct' &&
            ((message.senderPilotNumber == myNumber &&
                    message.recipientPilotNumber == _pilotNumber) ||
                (message.senderPilotNumber == _pilotNumber &&
                    message.recipientPilotNumber == myNumber));
      default:
        return false;
    }
  }

  void _mergeMessages(Iterable<ChatMessage> messages) {
    final byID = <String, ChatMessage>{
      for (final message in _messages) message.id: message,
    };
    for (final message in messages) {
      byID[message.id] = message;
    }
    final sorted = byID.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length > 300) sorted.removeRange(0, sorted.length - 300);
    _messages
      ..clear()
      ..addAll(sorted);
  }

  void _scheduleReconnect(Object? error) {
    if (!_desiredConnection || _disposed || _reconnectTimer != null) return;
    _stableTimer?.cancel();
    _stableTimer = null;
    if (error != null) _lastError = _errorCode(error);
    _subscription?.cancel();
    _subscription = null;
    final previous = _channel;
    _channel = null;
    if (previous != null) unawaited(previous.sink.close());
    final seconds = (1 << _attempt.clamp(0, 6)).clamp(1, 60);
    _attempt++;
    _setState(ChatConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  String _errorCode(Object error) =>
      error is ChatException ? error.code : error.runtimeType.toString();

  void _setState(ChatConnectionState value) {
    if (_state == value) return;
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> disconnect() async {
    _conversationEpoch++;
    _partnerSharingLocation = null;
    _desiredConnection = false;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stableTimer?.cancel();
    _stableTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _channel;
    _channel = null;
    await socket?.sink.close();
    _attempt = 0;
    _messages.clear();
    _setState(ChatConnectionState.disconnected);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _account.removeListener(_onAccountChanged);
    _disposed = true;
    _desiredConnection = false;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _stableTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    if (_ownsHttpClient) _http.close();
    unawaited(_incomingChatMessages.close());
    super.dispose();
  }
}

class ChatException implements Exception {
  const ChatException(this.code);
  final String code;
  @override
  String toString() => code;
}
