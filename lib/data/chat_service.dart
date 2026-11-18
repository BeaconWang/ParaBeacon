import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../live/ws_connect.dart';
import 'parabeacon_account_service.dart';
import 'parabeacon_server_config.dart';
import 'user_agent_settings.dart';

enum ChatConnectionState { disconnected, connecting, connected, reconnecting }

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
  });

  final String id;
  final String scope;
  final int senderPilotNumber;
  final String senderName;
  final int? channelNumber;
  final int? recipientPilotNumber;
  final String text;
  final DateTime createdAt;

  static ChatMessage? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final scope = raw['scope'];
    final senderNumber = raw['sender_pilot_number'];
    final senderName = raw['sender_name'];
    final text = raw['text'];
    final timestamp = raw['created_at'];
    final channel = raw['channel_number'];
    final recipient = raw['recipient_pilot_number'];
    if (id is! String ||
        id.isEmpty ||
        (scope != 'public' && scope != 'channel' && scope != 'direct') ||
        senderNumber is! int ||
        senderNumber < 100000 ||
        senderNumber > 999999 ||
        senderName is! String ||
        senderName.trim().isEmpty ||
        text is! String ||
        text.trim().isEmpty ||
        text.runes.length > 1000 ||
        timestamp is! String ||
        (channel != null &&
            (channel is! int || channel < 0 || channel > 999999)) ||
        (recipient != null &&
            (recipient is! int || recipient < 100000 || recipient > 999999))) {
      return null;
    }
    final createdAt = DateTime.tryParse(timestamp);
    if (createdAt == null) return null;
    return ChatMessage(
      id: id,
      scope: scope as String,
      senderPilotNumber: senderNumber,
      senderName: senderName.trim(),
      channelNumber: channel as int?,
      recipientPilotNumber: recipient as int?,
      text: text,
      createdAt: createdAt.toUtc(),
    );
  }
}

class ChatService extends ChangeNotifier {
  ChatService({
    required ParaBeaconAccountService accountService,
    http.Client? httpClient,
  }) : _account = accountService,
       _http = UserAgentHttpClient(innerClient: httpClient) {
    _ownsHttpClient = httpClient == null;
    _account.addListener(_onAccountChanged);
  }

  static final ChatService instance = ChatService(
    accountService: ParaBeaconAccountService.instance,
  );

  final ParaBeaconAccountService _account;
  late final http.Client _http;
  late final bool _ownsHttpClient;
  final List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatConnectionState _state = ChatConnectionState.disconnected;
  ChatConnectionState get state => _state;
  String? _lastError;
  String? get lastError => _lastError;
  String _scope = 'public';
  String get scope => _scope;
  int _channelNumber = 0;
  int get channelNumber => _channelNumber;
  int _pilotNumber = 0;
  int get pilotNumber => _pilotNumber;
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

  Uri get _apiBase => ParaBeaconServerConfig.apiBaseUri;

  void _onAccountChanged() {
    if (!_account.isSignedIn) {
      if (_desiredConnection) unawaited(disconnect());
      return;
    }
    if (_desiredConnection && _state == ChatConnectionState.disconnected) {
      unawaited(_connect());
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
    final active = _historyFuture;
    if (active != null) return active;
    final future = _loadHistoryOnce();
    _historyFuture = future;
    return future.whenComplete(() {
      if (identical(_historyFuture, future)) _historyFuture = null;
    });
  }

  Future<void> _loadHistoryOnce() async {
    final query = <String, String>{'scope': _scope};
    if (_scope == 'channel') {
      query['channel_number'] = _channelNumber.toString();
    }
    if (_scope == 'direct') query['pilot_number'] = _pilotNumber.toString();
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
      final loaded = (decoded['messages'] as List)
          .map(ChatMessage.fromJson)
          .whereType<ChatMessage>();
      _mergeMessages(loaded);
      _lastError = null;
      _notify();
    } on Object catch (error) {
      _lastError = _errorCode(error);
      _notify();
      rethrow;
    }
  }

  Future<void> send(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.runes.length > 1000) {
      throw const ChatException('invalid_message');
    }
    final channel = _channel;
    if (channel == null || _state != ChatConnectionState.connected) {
      throw const ChatException('chat_disconnected');
    }
    final payload = <String, Object>{
      'type': 'send',
      'scope': _scope,
      'text': normalized,
    };
    if (_scope == 'channel') payload['channel_number'] = _channelNumber;
    if (_scope == 'direct') payload['pilot_number'] = _pilotNumber;
    try {
      channel.sink.add(jsonEncode(payload));
    } on Object catch (error) {
      _lastError = _errorCode(error);
      _scheduleReconnect(error);
      _notify();
      rethrow;
    }
  }

  Future<http.Response> _sendRequest(String method, Uri uri) async {
    if (uri.scheme != 'https' ||
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
      unawaited(loadHistory().catchError((Object _) {}));
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
    if (_scope == 'channel') payload['channel_number'] = _channelNumber;
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
      if (message == null || !_matchesConversation(message)) return;
      _lastError = null;
      _mergeMessages([message]);
      _notify();
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
    super.dispose();
  }
}

class ChatException implements Exception {
  const ChatException(this.code);
  final String code;
  @override
  String toString() => code;
}
