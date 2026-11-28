import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'debug_settings.dart';
import 'flight_data.dart';
import 'flight_recorder.dart';
import 'location_share_throttler.dart';
import 'flight_state.dart';
import 'live_tracking_settings.dart';
import 'parabeacon_account_service.dart';
import 'pilot_avatar.dart';
import 'profile_image_url.dart';
import 'live_tracking_config.dart';
import 'live_tracking_proxy_auth_service.dart';
import 'user_agent_settings.dart';
import '../live/room_tracking_websocket_client.dart';

@immutable
class LiveTrackpoint {
  const LiveTrackpoint({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.groundSpeedMetersPerSecond,
    required this.timestamp,
    this.verticalSpeedMetersPerSecond,
    this.gpsAltitudeMeters,
    this.barometricAltitudeMeters,
    this.headingDegrees,
    this.bearingDegrees,
    this.windSpeedMetersPerSecond,
    this.windDirectionDegrees,
    this.gpsAccuracyMeters,
    this.satellites,
    this.pressureHpa,
    this.temperatureCelsius,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double groundSpeedMetersPerSecond;
  final DateTime timestamp;
  final double? verticalSpeedMetersPerSecond;
  final double? gpsAltitudeMeters;
  final double? barometricAltitudeMeters;
  final double? headingDegrees;
  final double? bearingDegrees;
  final double? windSpeedMetersPerSecond;
  final double? windDirectionDegrees;
  final double? gpsAccuracyMeters;
  final int? satellites;
  final double? pressureHpa;
  final double? temperatureCelsius;

  double get speedMetersPerSecond => groundSpeedMetersPerSecond;

  Map<String, Object?> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'altitude': altitudeMeters,
    'speed': groundSpeedMetersPerSecond,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (verticalSpeedMetersPerSecond != null)
      'vertical_speed': verticalSpeedMetersPerSecond,
    if (gpsAltitudeMeters != null) 'gps_altitude': gpsAltitudeMeters,
    if (barometricAltitudeMeters != null)
      'barometric_altitude': barometricAltitudeMeters,
    if (headingDegrees != null) 'heading': headingDegrees,
    if (bearingDegrees != null) 'bearing': bearingDegrees,
    if (windSpeedMetersPerSecond != null)
      'wind_speed': windSpeedMetersPerSecond,
    if (windDirectionDegrees != null) 'wind_direction': windDirectionDegrees,
    if (gpsAccuracyMeters != null) 'gps_accuracy': gpsAccuracyMeters,
    if (satellites != null) 'satellites': satellites,
    if (pressureHpa != null) 'pressure': pressureHpa,
    if (temperatureCelsius != null) 'temperature': temperatureCelsius,
  };

  static LiveTrackpoint? fromFlightData(
    FlightData data, {
    bool allowMockLocation = false,
  }) {
    if (!data.hasFix || (data.isMockLocation && !allowMockLocation)) {
      return null;
    }
    if (!data.latitude.isFinite ||
        !data.longitude.isFinite ||
        data.latitude < -90 ||
        data.latitude > 90 ||
        data.longitude < -180 ||
        data.longitude > 180) {
      return null;
    }
    final timestamp = data.gpsTimestamp ?? data.timestamp;
    if (timestamp == null) return null;
    final altitude = data.gpsAltitude ?? data.altitude;
    if (!altitude.isFinite || !data.groundSpeed.isFinite) return null;
    double? finite(double? value) =>
        value != null && value.isFinite ? value : null;
    double? degrees(double value) {
      if (!value.isFinite) return null;
      if (value >= 0 && value < 360) return value;
      return ((value % 360) + 360) % 360;
    }

    final heading = data.hasHeading ? degrees(data.heading) : null;
    final gpsAltitude = finite(data.gpsAltitude);
    final barometricAltitude = finite(data.baroAltitude);
    final windSpeed = finite(data.windSpeed);
    final windDirection = data.windDirection.isFinite
        ? degrees(data.windDirection)
        : null;
    final accuracy = finite(data.gpsAccuracy);
    final pressure = finite(data.pressure);
    final temperature = finite(data.temperature);
    return LiveTrackpoint(
      latitude: data.latitude,
      longitude: data.longitude,
      altitudeMeters: altitude,
      groundSpeedMetersPerSecond: (data.groundSpeed / 3.6)
          .clamp(0, 200)
          .toDouble(),
      timestamp: timestamp.toUtc(),
      verticalSpeedMetersPerSecond: finite(data.verticalSpeed),
      gpsAltitudeMeters: gpsAltitude,
      barometricAltitudeMeters: barometricAltitude,
      headingDegrees: heading,
      bearingDegrees: heading,
      windSpeedMetersPerSecond: windSpeed == null
          ? null
          : (windSpeed / 3.6).clamp(0, 200).toDouble(),
      windDirectionDegrees: windDirection,
      gpsAccuracyMeters: accuracy != null && accuracy >= 0 ? accuracy : null,
      satellites: data.satellites,
      pressureHpa: pressure,
      temperatureCelsius: temperature,
    );
  }

  static LiveTrackpoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    double? number(Object? item) => item is num ? item.toDouble() : null;
    double? optionalNumber(String key) {
      final raw = value[key];
      if (raw == null) return null;
      final parsed = number(raw);
      return parsed != null && parsed.isFinite ? parsed : null;
    }

    final lat = number(value['lat']);
    final lon = number(value['lon']);
    final altitude = number(value['altitude']);
    final speed = number(value['speed'] ?? value['ground_speed']);
    final rawBearing = value['bearing'];
    final bearing = number(rawBearing);
    final timestampValue = value['timestamp'];
    final timestamp = timestampValue is String
        ? DateTime.tryParse(timestampValue)
        : null;
    if (lat == null ||
        lon == null ||
        altitude == null ||
        speed == null ||
        timestamp == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        !altitude.isFinite ||
        !speed.isFinite ||
        (rawBearing != null &&
            (bearing == null ||
                !bearing.isFinite ||
                bearing < 0 ||
                bearing >= 360)) ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    final satellitesValue = value['satellites'];
    if (satellitesValue != null && satellitesValue is! int) return null;
    return LiveTrackpoint(
      latitude: lat,
      longitude: lon,
      altitudeMeters: altitude,
      groundSpeedMetersPerSecond: speed,
      timestamp: timestamp.toUtc(),
      verticalSpeedMetersPerSecond: optionalNumber('vertical_speed'),
      gpsAltitudeMeters: optionalNumber('gps_altitude'),
      barometricAltitudeMeters: optionalNumber('barometric_altitude'),
      headingDegrees: optionalNumber('heading'),
      bearingDegrees: bearing,
      windSpeedMetersPerSecond: optionalNumber('wind_speed'),
      windDirectionDegrees: optionalNumber('wind_direction'),
      gpsAccuracyMeters: optionalNumber('gps_accuracy'),
      satellites: satellitesValue as int?,
      pressureHpa: optionalNumber('pressure'),
      temperatureCelsius: optionalNumber('temperature'),
    );
  }
}

@immutable
class PublicPilotLocation {
  const PublicPilotLocation({
    required this.pilotName,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    this.liveRoomId,
    this.pilotNumber,
    this.channelNumber = 0,
    this.avatarId = PilotAvatar.defaultId,
    this.profileImageUrl,
    this.headingDegrees,
    this.altitudeMeters,
    this.groundSpeedMetersPerSecond,
    this.verticalSpeedMetersPerSecond,
    this.isOnline = true,
    this.path = const [],
  });

  final String pilotName;
  final double latitude;
  final double longitude;
  final DateTime observedAt;
  final String? liveRoomId;
  final int? pilotNumber;
  final int channelNumber;
  final int avatarId;
  final String? profileImageUrl;

  /// Whether the server still considers the sharing session online. Pilots
  /// that drop off the network keep sharing their last known position with
  /// [isOnline] set to false until they stop sharing explicitly.
  final bool isOnline;

  /// GPS course over ground in degrees clockwise from north, when available.
  final double? headingDegrees;
  final double? altitudeMeters;
  final double? groundSpeedMetersPerSecond;
  final double? verticalSpeedMetersPerSecond;
  final List<LiveTrackpoint> path;

  String get trackingIdentity =>
      liveRoomId ??
      (pilotNumber == null ? 'name:$pilotName' : 'pilot:$pilotNumber');

  bool belongsToLiveRoom(String? roomId) =>
      roomId != null && liveRoomId == roomId;

  bool isVisibleOnMap({
    required DateTime now,
    String? ownLiveRoomId,
    bool showOfflinePilots = false,
  }) {
    if (belongsToLiveRoom(ownLiveRoomId)) return false;
    final currentTime = now.toUtc();
    final observedAtUtc = observedAt.toUtc();
    if (observedAtUtc.isAfter(currentTime.add(const Duration(seconds: 5)))) {
      return false;
    }
    if (showOfflinePilots) return true;
    final age = currentTime.difference(observedAtUtc);
    return isOnline && age <= const Duration(seconds: 90);
  }

  static PublicPilotLocation? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final name = value['pilot_name'];
    final latitude = value['lat'];
    final longitude = value['lon'];
    final timestamp = value['observed_at'];
    final liveRoomId = value['live_room_id'];
    final rawPilotNumber = value['pilot_number'];
    final rawChannelNumber = value['channel_number'] ?? 0;
    final rawAvatarId = value['avatar_id'] ?? PilotAvatar.defaultId;
    final rawProfileImageUrl = value['profile_image_url'];
    final profileImageUrl = rawProfileImageUrl == null
        ? null
        : rawProfileImageUrl is String &&
              ProfileImageUrl.resolve(rawProfileImageUrl) != null
        ? rawProfileImageUrl
        : null;
    final heading = value['heading'];
    if ((rawProfileImageUrl != null && profileImageUrl == null) ||
        name is! String ||
        name.trim().isEmpty ||
        latitude is! num ||
        longitude is! num ||
        timestamp is! String ||
        (liveRoomId != null && liveRoomId is! String) ||
        (rawPilotNumber != null &&
            (rawPilotNumber is! int ||
                rawPilotNumber < 100000 ||
                rawPilotNumber > 999999)) ||
        rawChannelNumber is! int ||
        rawChannelNumber < 0 ||
        rawChannelNumber > 999999 ||
        rawAvatarId is! int ||
        !PilotAvatar.isValid(rawAvatarId) ||
        (heading != null && heading is! num)) {
      return null;
    }
    final lat = latitude.toDouble();
    final lon = longitude.toDouble();
    final observedAt = DateTime.tryParse(timestamp);
    final headingValue = heading?.toDouble();
    double? optionalNumber(String key) {
      final raw = value[key];
      if (raw is! num) return null;
      final parsed = raw.toDouble();
      return parsed.isFinite ? parsed : null;
    }

    final rawPath = value['path'];
    final path = rawPath is List
        ? (rawPath
              .map(LiveTrackpoint.fromJson)
              .whereType<LiveTrackpoint>()
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
        : const <LiveTrackpoint>[];
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180 ||
        observedAt == null ||
        (headingValue != null &&
            (!headingValue.isFinite ||
                headingValue < 0 ||
                headingValue >= 360))) {
      return null;
    }
    return PublicPilotLocation(
      pilotName: name.trim(),
      latitude: lat,
      longitude: lon,
      observedAt: observedAt.toUtc(),
      liveRoomId: liveRoomId is String && liveRoomId.isNotEmpty
          ? liveRoomId
          : null,
      pilotNumber: rawPilotNumber as int?,
      channelNumber: rawChannelNumber,
      avatarId: rawAvatarId,
      profileImageUrl: profileImageUrl,
      headingDegrees: headingValue,
      altitudeMeters: optionalNumber('altitude'),
      groundSpeedMetersPerSecond: optionalNumber('speed'),
      verticalSpeedMetersPerSecond: optionalNumber('vertical_speed'),
      isOnline: value['is_online'] is bool ? value['is_online'] as bool : true,
      path: List.unmodifiable(path),
    );
  }
}

abstract interface class LiveTrackingProxyPointStore {
  Future<List<QueuedProxyPoint>> load();

  Future<void> save(List<QueuedProxyPoint> points);
}

class SharedPreferencesLiveTrackingProxyPointStore
    implements LiveTrackingProxyPointStore {
  SharedPreferencesLiveTrackingProxyPointStore({
    this.storageKey = 'pb.liveTracking.proxyQueue.v1',
  });

  final String storageKey;

  @override
  Future<List<QueuedProxyPoint>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(QueuedProxyPoint.fromJson)
          .whereType<QueuedProxyPoint>()
          .toList(growable: true);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<QueuedProxyPoint> points) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(points.map((point) => point.toJson()).toList()),
    );
  }
}

class SQLiteLiveTrackingProxyPointStore implements LiveTrackingProxyPointStore {
  static const _legacyStorageKey = 'pb.liveTracking.proxyQueue.v1';
  static Future<Database>? _databaseFuture;

  Future<Database> get _database async {
    final current = _databaseFuture;
    if (current != null) return current;
    final opening = _openDatabase();
    _databaseFuture = opening;
    try {
      return await opening;
    } on Object {
      if (identical(_databaseFuture, opening)) _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'parabeacon_tracking_queue.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE pending_points ('
          'sequence INTEGER PRIMARY KEY AUTOINCREMENT, '
          'payload TEXT NOT NULL)',
        );
      },
    );
  }

  @override
  Future<List<QueuedProxyPoint>> load() async {
    try {
      final database = await _database;
      final rows = await database.query(
        'pending_points',
        columns: const ['payload'],
        orderBy: 'sequence ASC',
      );
      final points = <QueuedProxyPoint>[];
      for (final row in rows) {
        try {
          final parsed = QueuedProxyPoint.fromJson(
            jsonDecode(row['payload'] as String),
          );
          if (parsed != null) points.add(parsed);
        } on Object {
          continue;
        }
      }
      if (points.isNotEmpty) return points;

      final legacyStore = SharedPreferencesLiveTrackingProxyPointStore(
        storageKey: _legacyStorageKey,
      );
      final legacyPoints = await legacyStore.load();
      if (legacyPoints.isNotEmpty) {
        try {
          await _saveToDatabase(database, legacyPoints);
          final preferences = await SharedPreferences.getInstance();
          await preferences.remove(_legacyStorageKey);
        } on Object {
          return legacyPoints;
        }
      }
      return legacyPoints;
    } on Object {
      return SharedPreferencesLiveTrackingProxyPointStore(
        storageKey: _legacyStorageKey,
      ).load();
    }
  }

  @override
  Future<void> save(List<QueuedProxyPoint> points) async {
    try {
      final database = await _database;
      await _saveToDatabase(database, points);
    } on Object {
      await SharedPreferencesLiveTrackingProxyPointStore(
        storageKey: _legacyStorageKey,
      ).save(points);
    }
  }

  Future<void> _saveToDatabase(
    Database database,
    List<QueuedProxyPoint> points,
  ) async {
    await database.transaction((transaction) async {
      await transaction.delete('pending_points');
      final batch = transaction.batch();
      for (final point in points) {
        batch.insert('pending_points', {'payload': jsonEncode(point.toJson())});
      }
      await batch.commit(noResult: true);
    });
  }
}

LiveTrackingProxyPointStore _defaultLiveTrackingProxyPointStore() {
  const sqlitePlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  };
  if (!kIsWeb && sqlitePlatforms.contains(defaultTargetPlatform)) {
    return SQLiteLiveTrackingProxyPointStore();
  }
  return SharedPreferencesLiveTrackingProxyPointStore();
}

@immutable
class QueuedProxyPoint {
  const QueuedProxyPoint({required this.sessionId, required this.point});

  final String sessionId;
  final LiveTrackpoint point;

  Map<String, Object> toJson() => {
    'session_id': sessionId,
    'point': point.toJson(),
  };

  static QueuedProxyPoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sessionId = value['session_id'];
    final point = LiveTrackpoint.fromJson(value['point']);
    if (sessionId is! String || sessionId.isEmpty || point == null) return null;
    return QueuedProxyPoint(sessionId: sessionId, point: point);
  }
}

enum LiveTrackingConnectionState {
  idle,
  connecting,
  active,
  reconnecting,
  disconnected,
}

/// Sends authenticated flight sessions and batched telemetry points directly
/// to the ParaBeacon Server REST API.
class LiveTrackingService extends ChangeNotifier {
  static const _pendingLocationDeletionKeyPrefix =
      'ParaBeacon.LiveTracking.PendingLocationDeletion.v1';
  LiveTrackingService({
    required LiveTrackingConfig config,
    required LiveTrackingProxyAuthProvider authProvider,
    LiveTrackingProxyPointStore? pointStore,
    http.Client? httpClient,
  }) : _config = config,
       _configured = true,
       _authProvider = authProvider,
       _pointStore = pointStore ?? _defaultLiveTrackingProxyPointStore(),
       _httpClient = httpClient == null
           ? UserAgentHttpClient()
           : UserAgentHttpClient(innerClient: httpClient),
       _ownsHttpClient = httpClient == null;

  LiveTrackingService._singleton()
    : _authProvider = ParaBeaconAccountService.instance,
      _pointStore = _defaultLiveTrackingProxyPointStore(),
      _httpClient = UserAgentHttpClient(),
      _ownsHttpClient = true;

  static final LiveTrackingService instance = LiveTrackingService._singleton();

  late LiveTrackingConfig _config;
  bool _configured = false;
  final LiveTrackingProxyAuthProvider _authProvider;
  final LiveTrackingProxyPointStore _pointStore;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<QueuedProxyPoint> _pending = [];
  final LocationShareThrottler _locationThrottler = LocationShareThrottler();
  RoomTrackingWebSocketClient? _roomSocket;

  LiveTrackingConnectionState _state = LiveTrackingConnectionState.idle;
  LiveTrackingConnectionState get state => _state;
  int get pendingPointCount => _pending.length;
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;
  String? _sessionId;
  String? get sessionId => _sessionId;
  bool _manualLocationDataDeletion = false;
  Future<void>? _locationDataDeletionFuture;
  Timer? _locationDataDeletionRetryTimer;
  int _locationDataDeletionRetryAttempt = 0;
  bool _sessionIsGroundPresence = false;
  DateTime? _lastGroundPresenceSentAt;
  bool get isConfigured => _configured;
  Uri? get apiBaseUri => _configured ? _config.apiBaseUri : null;

  Future<bool> canChangeServer() async {
    if (!_configured) return false;
    await _loadQueue();
    return _sessionId == null &&
        !_starting &&
        _endingSessions.isEmpty &&
        _pending.isEmpty &&
        _uploadFuture == null &&
        _flightState?.isFlying != true;
  }

  Future<List<PublicPilotLocation>> loadPublicPilotLocations({
    required double west,
    required double south,
    required double east,
    required double north,
    String? taskOwnerId,
  }) async {
    if (!_configured) {
      throw const LiveTrackingProxyException('tracking_config_unavailable');
    }
    if (!west.isFinite ||
        !east.isFinite ||
        !south.isFinite ||
        !north.isFinite ||
        west < -180 ||
        west > 180 ||
        east < -180 ||
        east > 180 ||
        south < -90 ||
        south > 90 ||
        north < -90 ||
        north > 90 ||
        south >= north) {
      throw ArgumentError('Invalid public pilot map bounds.');
    }
    final endpoint = _config.apiBaseUri.resolve('/api/v1/map/active-locations');
    final locations = <PublicPilotLocation>[];
    final cursors = <String>{};
    String? cursor;
    do {
      final query = <String, String>{
        'west': west.toStringAsPrecision(12),
        'south': south.toStringAsPrecision(12),
        'east': east.toStringAsPrecision(12),
        'north': north.toStringAsPrecision(12),
        // Offline pilots keep sharing their last known position; fetch them
        // too and let the map overlay decide whether to render them.
        'show_offline': 'true',
        ...?(taskOwnerId == null ? null : {'task_owner_id': taskOwnerId}),
        ...?(cursor == null ? null : {'cursor': cursor}),
      };
      final response = await _sendAuthorizedGet(
        endpoint.replace(queryParameters: query),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveTrackingProxyException(
          'public_locations_http_${response.statusCode}',
        );
      }
      final decoded = _decodeResponse(response.body);
      final rawLocations = decoded?['locations'];
      if (rawLocations is! List) {
        throw const LiveTrackingProxyException('invalid_public_locations');
      }
      for (final raw in rawLocations) {
        final location = PublicPilotLocation.fromJson(raw);
        if (location != null) locations.add(location);
      }
      final nextCursor = decoded?['next_cursor'];
      if (nextCursor is! String || nextCursor.isEmpty) break;
      if (!cursors.add(nextCursor)) {
        throw const LiveTrackingProxyException(
          'invalid_public_locations_cursor',
        );
      }
      cursor = nextCursor;
    } while (true);
    return locations;
  }

  void configure(LiveTrackingConfig? config) {
    if (_sessionId != null ||
        _starting ||
        _endingSessions.isNotEmpty ||
        _pending.isNotEmpty ||
        _flightState?.isFlying == true) {
      throw StateError(
        'Cannot replace live-tracking config while flight data is active or queued.',
      );
    }
    if (config == null) {
      _configured = false;
      _flushWhileIdle = false;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _lastErrorCode = 'config_load_failed';
      _setState(LiveTrackingConnectionState.disconnected);
      return;
    }
    _config = config;
    _configured = true;
    _lastErrorCode = null;
    _setState(LiveTrackingConnectionState.idle);
    _queueLifecycleSync();
  }

  FlightDataView? _data;
  FlightState? _flightState;
  FlightSampleSource? _flightSampleSource;
  Listenable? _eligibilitySource;
  bool Function()? _isEnabled;
  String? Function()? _pilotId;
  String? Function()? _pilotDisplayName;
  bool Function()? _isPubliclyShared;
  bool? _sessionPubliclyShared;
  bool _loadedQueue = false;
  Future<void>? _queueLoadFuture;
  bool _starting = false;
  bool _uploading = false;
  bool _flushWhileIdle = false;
  Future<void>? _uploadFuture;
  final Set<String> _endingSessions = <String>{};
  Future<void> _sessionEndTail = Future<void>.value();
  bool _disposed = false;
  int _retryAttempt = 0;
  int _bindingEpoch = 0;
  DateTime? _lastPointTimestamp;
  int _flightSampleCursor = 0;
  Timer? _uploadTimer;
  Timer? _retryTimer;
  Future<void> _syncTail = Future<void>.value();
  Future<void> _saveTail = Future<void>.value();

  void bind({
    required FlightDataView data,
    required FlightState flightState,
    required bool Function() isEnabled,
    required String? Function() pilotId,
    String? Function()? pilotDisplayName,
    bool Function()? isPubliclyShared,
    Listenable? eligibilitySource,
    FlightSampleSource? flightSampleSource,
  }) {
    unbind();
    _data = data;
    _flightState = flightState;
    _isEnabled = isEnabled;
    _pilotId = pilotId;
    _pilotDisplayName = pilotDisplayName;
    _isPubliclyShared = isPubliclyShared;
    _flightSampleSource = flightSampleSource;
    _eligibilitySource = eligibilitySource;
    data.addListener(_onDataChanged);
    flightSampleSource?.addListener(_onFlightSamplesChanged);
    flightState.addListener(_queueLifecycleSync);
    eligibilitySource?.addListener(_queueLifecycleSync);
    unawaited(_loadQueue());
    _queueLifecycleSync();
  }

  void _scheduleLocationDataDeletionRetry() {
    if (_disposed || _locationDataDeletionRetryTimer != null) return;
    final delaySeconds = (1 << _locationDataDeletionRetryAttempt.clamp(0, 6))
        .clamp(1, 60);
    _locationDataDeletionRetryAttempt++;
    _locationDataDeletionRetryTimer = Timer(
      Duration(seconds: delaySeconds),
      () {
        _locationDataDeletionRetryTimer = null;
        if (_manualLocationDataDeletion || _disposed) return;
        unawaited(_retryLocationDataDeletion());
      },
    );
  }

  String? _pendingLocationDeletionPreferenceKey() {
    final accountID = ParaBeaconAccountService.instance.user?.id;
    if (accountID == null || accountID.isEmpty || !_configured) return null;
    return '$_pendingLocationDeletionKeyPrefix:${Uri.encodeComponent(_config.apiBaseUri.origin)}:$accountID';
  }

  Future<bool> _hasPendingLocationDataDeletion() async {
    final key = _pendingLocationDeletionPreferenceKey();
    if (key == null) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(key) == true;
    } on Object {
      return false;
    }
  }

  Future<void> _setPendingLocationDataDeletion(bool pending) async {
    final key = _pendingLocationDeletionPreferenceKey();
    if (key == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (pending) {
        await preferences.setBool(key, true);
      } else {
        await preferences.remove(key);
      }
    } on Object {
      return;
    }
  }

  Future<bool> _retryPendingLocationDataDeletion() async {
    if (_manualLocationDataDeletion || _locationDataDeletionFuture != null) {
      return true;
    }
    if (!await _hasPendingLocationDataDeletion()) return false;
    _manualLocationDataDeletion = true;
    try {
      await _retryLocationDataDeletion();
    } finally {
      _manualLocationDataDeletion = false;
    }
    return await _hasPendingLocationDataDeletion();
  }

  Future<void> _retryLocationDataDeletion() async {
    if (!_configured) {
      _scheduleLocationDataDeletionRetry();
      return;
    }
    try {
      final response = await _sendJson(
        method: 'DELETE',
        uri: _config.apiBaseUri.resolve('/api/v1/tracking/location-data'),
        body: const {},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveTrackingProxyException(
          'location_data_delete_http_${response.statusCode}',
        );
      }
      _locationDataDeletionRetryAttempt = 0;
      await _setPendingLocationDataDeletion(false);
      _lastErrorCode = null;
      _notify();
      if (!_manualLocationDataDeletion && !_disposed) _queueLifecycleSync();
    } on Object catch (error) {
      _lastErrorCode = _errorCode(error);
      _notify();
      _scheduleLocationDataDeletionRetry();
    }
  }

  Future<void> disableParaBeaconAndDeleteLocationData({
    required Future<void> Function() disableSetting,
  }) {
    final existing = _locationDataDeletionFuture;
    if (existing != null) return existing;
    _manualLocationDataDeletion = true;
    _bindingEpoch++;
    final operation = _disableAndDeleteLocationData(disableSetting);
    _locationDataDeletionFuture = operation;
    return operation;
  }

  Future<void> _disableAndDeleteLocationData(
    Future<void> Function() disableSetting,
  ) async {
    try {
      await _setPendingLocationDataDeletion(true);
      await disableSetting();
      _queueLifecycleSync();
      await _syncTail.catchError((Object _) {});
      final upload = _uploadFuture;
      if (upload != null) await upload.catchError((Object _) {});
      _sessionId = null;
      _sessionIsGroundPresence = false;
      _sessionPubliclyShared = null;
      _lastGroundPresenceSentAt = null;
      _lastPointTimestamp = null;
      _flushWhileIdle = false;
      _retryTimer?.cancel();
      _retryTimer = null;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _pending.clear();
      await _persistQueue();
      final socket = _roomSocket;
      if (socket != null) await socket.leaveRoom();
      _locationThrottler.reset();
      _setState(LiveTrackingConnectionState.disconnected);
      if (!_configured) {
        throw const LiveTrackingProxyException('tracking_config_unavailable');
      }
      final response = await _sendJson(
        method: 'DELETE',
        uri: _config.apiBaseUri.resolve('/api/v1/tracking/location-data'),
        body: const {},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveTrackingProxyException(
          'location_data_delete_http_${response.statusCode}',
        );
      }
      _locationDataDeletionRetryTimer?.cancel();
      _locationDataDeletionRetryTimer = null;
      _locationDataDeletionRetryAttempt = 0;
      await _setPendingLocationDataDeletion(false);
      _lastErrorCode = null;
    } on Object catch (error) {
      _lastErrorCode = _errorCode(error);
      _scheduleLocationDataDeletionRetry();
    } finally {
      _manualLocationDataDeletion = false;
      _locationDataDeletionFuture = null;
      _notify();
      if (!_disposed) _queueLifecycleSync();
    }
  }

  Future<void> closeForSignOut() async {
    if (_starting) await _syncTail.catchError((Object _) {});
    final sessionId = _sessionId;
    if (sessionId == null) {
      await _sessionEndTail.catchError((Object _) {});
      return;
    }
    _sessionId = null;
    _sessionIsGroundPresence = false;
    _flushWhileIdle = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _setState(LiveTrackingConnectionState.disconnected);
    _queueSessionEnd(sessionId);
    await _sessionEndTail.catchError((Object _) {});
  }

  void unbind() {
    _bindingEpoch++;
    final sessionId = _sessionId;
    if (sessionId != null) _queueSessionEnd(sessionId);
    _sessionId = null;
    _sessionIsGroundPresence = false;
    _lastGroundPresenceSentAt = null;
    _flushWhileIdle = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _data?.removeListener(_onDataChanged);
    _flightSampleSource?.removeListener(_onFlightSamplesChanged);
    _flightState?.removeListener(_queueLifecycleSync);
    _eligibilitySource?.removeListener(_queueLifecycleSync);
    _data = null;
    _flightState = null;
    _flightSampleSource = null;
    _eligibilitySource = null;
    _isEnabled = null;
    _pilotId = null;
    _pilotDisplayName = null;
    _isPubliclyShared = null;
    _sessionPubliclyShared = null;
    if (!_disposed) _setState(LiveTrackingConnectionState.idle);
  }

  Future<void> _loadQueue() {
    if (!_configured || _loadedQueue) return Future<void>.value();
    return _queueLoadFuture ??= _loadQueueOnce();
  }

  Future<void> _loadQueueOnce() async {
    try {
      final stored = await _pointStore.load();
      final retained = stored.length <= _config.maximumBufferedPoints
          ? stored
          : stored.sublist(stored.length - _config.maximumBufferedPoints);
      _pending
        ..clear()
        ..addAll(retained);
    } on Object {
      _lastErrorCode = 'queue_load_failed';
    } finally {
      _loadedQueue = true;
      _queueLoadFuture = null;
      _notify();
      _queueLifecycleSync();
    }
  }

  void _queueLifecycleSync() {
    if (_disposed) return;
    _syncTail = _syncTail
        .catchError((Object _) {})
        .then((_) => _syncLifecycle())
        .catchError((Object error) {
          _lastErrorCode = _errorCode(error);
          _setState(LiveTrackingConnectionState.reconnecting);
          if (!_manualLocationDataDeletion) _scheduleRetry();
        });
  }

  bool get _flightTrackingEnabled =>
      _configured &&
      _flightState?.isFlying == true &&
      (_isEnabled?.call() ?? false);

  bool get _groundPresenceEnabled =>
      _configured &&
      _flightState?.isFlying != true &&
      (_isEnabled?.call() ?? false) &&
      LiveTrackingSettings.instance.shareLocationWhileNotFlying &&
      LiveTrackingSettings.instance.shareLocationPublicly &&
      !LiveTrackingSettings.instance.temporaryDontShare;

  bool get _shouldTrack => _flightTrackingEnabled || _groundPresenceEnabled;

  bool get _currentModeIsGroundPresence =>
      _flightState?.isFlying != true && _groundPresenceEnabled;

  Future<void> _syncLifecycle() async {
    if (!_configured) return;
    if (_locationDataDeletionRetryTimer != null) {
      _locationDataDeletionRetryTimer?.cancel();
      _locationDataDeletionRetryTimer = null;
      await _retryLocationDataDeletion();
      return;
    }
    if (await _retryPendingLocationDataDeletion()) return;
    if (!_loadedQueue) {
      await _loadQueue();
      return;
    }
    if (_manualLocationDataDeletion) {
      _sessionId = null;
      _sessionIsGroundPresence = false;
      _lastGroundPresenceSentAt = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _leaveRoomSocket();
      _setState(LiveTrackingConnectionState.disconnected);
      return;
    }
    if (_shouldTrack) {
      if (_sessionId != null &&
          !_starting &&
          _sessionIsGroundPresence != _currentModeIsGroundPresence) {
        final previousSessionId = _sessionId!;
        _sessionId = null;
        _sessionIsGroundPresence = false;
        _queueSessionEnd(previousSessionId);
        await _sessionEndTail.catchError((Object _) {});
      }
      if (_sessionId == null && !_starting) {
        await _startSession();
      } else if (_sessionId != null) {
        await _syncPublicSharing();
      }
      return;
    }
    if (_sessionId != null || _starting) {
      _flushWhileIdle = _sessionId != null && (_isEnabled?.call() ?? false);
      final sessionId = _sessionId;
      if (sessionId != null) _queueSessionEnd(sessionId);
      _sessionId = null;
      _sessionIsGroundPresence = false;
      _lastGroundPresenceSentAt = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _setState(LiveTrackingConnectionState.disconnected);
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
      if (_state == LiveTrackingConnectionState.connecting ||
          _state == LiveTrackingConnectionState.reconnecting) {
        _setState(LiveTrackingConnectionState.disconnected);
      }
    }
  }

  Future<void> _syncPublicSharing() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final desired = _isPubliclyShared?.call() ?? false;
    if (_sessionPubliclyShared == desired) return;
    final uri = _config.apiBaseUri.resolve(
      '/api/v1/tracking/sessions/${Uri.encodeComponent(sessionId)}/public-sharing',
    );
    final response = await _sendJson(
      method: 'PATCH',
      uri: uri,
      body: {'publicly_share': desired},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LiveTrackingProxyException(
        'public_sharing_http_${response.statusCode}',
      );
    }
    _sessionPubliclyShared = desired;
    _lastErrorCode = null;
    _notify();
  }

  String _resolvePublicPilotName(String accountName) {
    if (!(_isPubliclyShared?.call() ?? false)) return accountName;
    final displayName =
        _pilotDisplayName?.call()?.trim() ??
        ParaBeaconAccountService.instance.user?.displayName.trim();
    return displayName == null || displayName.isEmpty
        ? accountName
        : displayName;
  }

  void _connectRoomSocket(String sessionId) {
    final endpoint = _config.webSocketUri;
    if (kIsWeb || endpoint == null) return;
    final socket = _roomSocket ??= RoomTrackingWebSocketClient(
      authProvider: _authProvider,
    );
    unawaited(_joinRoomSocket(socket, endpoint, sessionId));
  }

  Future<void> _joinRoomSocket(
    RoomTrackingWebSocketClient socket,
    Uri endpoint,
    String sessionId,
  ) async {
    try {
      await socket.joinRoom(endpoint: endpoint, roomId: sessionId);
    } on Object catch (error) {
      if (identical(_roomSocket, socket) && !_disposed) {
        _lastErrorCode = 'room_socket_${error.runtimeType}';
        _notify();
      }
    }
  }

  void _leaveRoomSocket() {
    final socket = _roomSocket;
    if (socket != null) unawaited(socket.leaveRoom());
  }

  void _disposeRoomSocket() {
    final socket = _roomSocket;
    _roomSocket = null;
    socket?.dispose();
  }

  Future<void> _startSession() async {
    if (_starting || !_shouldTrack) return;
    final bindingEpoch = _bindingEpoch;
    final pilotId = _pilotId?.call()?.trim();
    final groundPresence = _currentModeIsGroundPresence;
    final startTime = groundPresence
        ? DateTime.now().toUtc()
        : _flightState?.startedAt;
    final publiclyShare = groundPresence
        ? true
        : (_isPubliclyShared?.call() ?? false);

    if (pilotId == null || pilotId.isEmpty || startTime == null) {
      throw const LiveTrackingProxyException('pilot_or_start_time_missing');
    }
    final publicPilotName = _resolvePublicPilotName(pilotId);
    _starting = true;
    _setState(LiveTrackingConnectionState.connecting);
    try {
      final config = _config;
      final response = await _sendJson(
        method: 'POST',
        uri: config.sessionStartUri,
        body: {
          'pilot_name': publicPilotName,
          'start_time': startTime.toUtc().toIso8601String(),
          'publicly_share': publiclyShare,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveTrackingProxyException('session_http_${response.statusCode}');
      }
      final decoded = _decodeResponse(response.body);
      final sessionId = decoded?['session_id'];
      if (sessionId is! String || sessionId.trim().isEmpty) {
        throw const LiveTrackingProxyException('invalid_session_response');
      }
      if (bindingEpoch != _bindingEpoch ||
          !_shouldTrack ||
          groundPresence != _currentModeIsGroundPresence) {
        if (!_manualLocationDataDeletion) {
          _queueSessionEnd(sessionId.trim());
        }
        _setState(LiveTrackingConnectionState.disconnected);
        return;
      }
      final activeSessionId = sessionId.trim();
      final queuedPointCount = _pending.length;
      _pending.removeWhere((queued) => queued.sessionId != activeSessionId);
      if (_pending.length != queuedPointCount) await _persistQueue();
      _sessionId = activeSessionId;
      _sessionIsGroundPresence = groundPresence;
      _lastGroundPresenceSentAt = null;
      _connectRoomSocket(activeSessionId);
      _sessionPubliclyShared = publiclyShare;
      _flushWhileIdle = false;
      _lastPointTimestamp = null;
      _flightSampleCursor = 0;
      _locationThrottler.reset();
      _lastErrorCode = null;
      _retryAttempt = 0;
      _setState(LiveTrackingConnectionState.active);
      _uploadTimer?.cancel();
      _uploadTimer = Timer.periodic(_config.uploadInterval, (_) {
        unawaited(_flushPending());
      });
      if (!groundPresence && _flightSampleSource != null) {
        _onFlightSamplesChanged();
      } else {
        _onDataChanged();
      }
      unawaited(_flushPending());
    } finally {
      _starting = false;
    }
  }

  void _onFlightSamplesChanged() {
    final sessionId = _sessionId;
    final source = _flightSampleSource;
    if (!_shouldTrack ||
        _currentModeIsGroundPresence ||
        _sessionIsGroundPresence ||
        sessionId == null ||
        source == null) {
      return;
    }

    final flightStartedAt = _flightState?.startedAt;
    final samples = source.currentFlightSamples;
    final startIndex = _flightSampleCursor <= samples.length
        ? _flightSampleCursor
        : 0;
    _flightSampleCursor = samples.length;
    var addedPoint = false;
    for (var index = startIndex; index < samples.length; index++) {
      final sample = samples[index];
      if (flightStartedAt != null && sample.time.isBefore(flightStartedAt)) {
        continue;
      }
      final point = LiveTrackpoint.fromFlightData(
        sample.data,
        allowMockLocation: DebugSettings.instance.simulatorEnabled,
      );
      if (point == null) continue;
      final previous = _lastPointTimestamp;
      if (previous != null && !point.timestamp.isAfter(previous)) continue;

      _lastPointTimestamp = point.timestamp;
      _roomSocket?.sendLocation(point);
      _pending.add(QueuedProxyPoint(sessionId: sessionId, point: point));
      addedPoint = true;
    }
    if (!addedPoint) return;
    if (_pending.length > _config.maximumBufferedPoints) {
      _pending.removeRange(0, _pending.length - _config.maximumBufferedPoints);
      _lastErrorCode = 'queue_limit_reached';
    }
    _notify();
    unawaited(_persistQueue());
    if (_pending.length >= _config.maximumBatchPoints) {
      unawaited(_flushPending());
    }
  }

  void _onDataChanged() {
    if (!_shouldTrack || _sessionId == null) return;
    if (_sessionIsGroundPresence != _currentModeIsGroundPresence) return;
    if (!_sessionIsGroundPresence && _flightSampleSource != null) return;
    final snapshot = _data?.data;
    if (snapshot == null) return;
    final point = LiveTrackpoint.fromFlightData(
      snapshot,
      allowMockLocation: DebugSettings.instance.simulatorEnabled,
    );
    if (point == null) return;
    final now = DateTime.now().toUtc();
    if (_sessionIsGroundPresence &&
        (point.timestamp.isBefore(now.subtract(const Duration(seconds: 30))) ||
            point.timestamp.isAfter(now.add(const Duration(seconds: 5))))) {
      return;
    }
    final previous = _lastPointTimestamp;
    if (previous != null && !point.timestamp.isAfter(previous)) return;
    if (_sessionIsGroundPresence) {
      final previousAt = _lastGroundPresenceSentAt;
      if (previousAt != null &&
          point.timestamp.difference(previousAt) < const Duration(seconds: 5)) {
        return;
      }
    }
    _lastPointTimestamp = point.timestamp;
    if (!_locationThrottler.shouldTransmit(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
    )) {
      return;
    }
    if (_sessionIsGroundPresence) _lastGroundPresenceSentAt = point.timestamp;
    _roomSocket?.sendLocation(point);
    _pending.add(QueuedProxyPoint(sessionId: _sessionId!, point: point));
    if (_pending.length > _config.maximumBufferedPoints) {
      _pending.removeRange(0, _pending.length - _config.maximumBufferedPoints);
      _lastErrorCode = 'queue_limit_reached';
    }
    _notify();
    unawaited(_persistQueue());
    if (_pending.length >= _config.maximumBatchPoints) {
      unawaited(_flushPending());
    }
  }

  Future<void> _flushPending() {
    final active = _uploadFuture;
    if (active != null) return active;
    final task = _flushPendingOnce();
    _uploadFuture = task;
    return task.whenComplete(() {
      if (identical(_uploadFuture, task)) _uploadFuture = null;
    });
  }

  Future<void> _flushPendingOnce() async {
    if (_disposed ||
        _uploading ||
        _pending.isEmpty ||
        (!_shouldTrack && !_flushWhileIdle)) {
      return;
    }
    _uploading = true;
    try {
      while (_pending.isNotEmpty) {
        final sessionId = _pending.first.sessionId;
        final count = _pending
            .takeWhile((queued) => queued.sessionId == sessionId)
            .length
            .clamp(0, _config.maximumBatchPoints)
            .toInt();
        if (count == 0) return;
        final batch = List<QueuedProxyPoint>.unmodifiable(_pending.take(count));
        final response = await _sendJson(
          method: 'POST',
          uri: _config.pointsUri(sessionId),
          body: {
            'session_id': sessionId,
            'trackpoints': batch
                .map((queued) => queued.point.toJson())
                .toList(),
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw LiveTrackingProxyException(
            'points_http_${response.statusCode}',
          );
        }
        final prefixMatches =
            batch.length <= _pending.length &&
            List<bool>.generate(
              batch.length,
              (index) => identical(_pending[index], batch[index]),
            ).every((matches) => matches);
        if (!prefixMatches) return;
        _pending.removeRange(0, batch.length);
        _lastErrorCode = null;
        _retryAttempt = 0;
        _notify();
        await _persistQueue();
      }
      if (_pending.isEmpty) _flushWhileIdle = false;
      if (_state == LiveTrackingConnectionState.reconnecting) {
        _setState(
          _sessionId == null
              ? LiveTrackingConnectionState.disconnected
              : LiveTrackingConnectionState.active,
        );
      }
    } on Object catch (error) {
      _lastErrorCode = _errorCode(error);
      _setState(LiveTrackingConnectionState.reconnecting);
      _scheduleRetry();
    } finally {
      _uploading = false;
    }
  }

  void _queueSessionEnd(String sessionId) {
    if (sessionId.isEmpty || !_endingSessions.add(sessionId)) return;
    _leaveRoomSocket();
    final stopUri = _config.sessionStopUri(sessionId);
    _sessionEndTail = _sessionEndTail.then((_) async {
      try {
        _flushWhileIdle = true;
        await _flushPending();
        final pendingCount = _pending.length;
        _pending.removeWhere((queued) => queued.sessionId == sessionId);
        if (_pending.length != pendingCount) {
          _lastErrorCode ??= 'final_points_dropped';
          await _persistQueue();
        }
        final response = await _sendJson(
          method: 'POST',
          uri: stopUri,
          body: {
            'session_id': sessionId,
            'end_time': DateTime.now().toUtc().toIso8601String(),
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw LiveTrackingProxyException(
            'session_stop_http_${response.statusCode}',
          );
        }
      } on Object catch (error) {
        _lastErrorCode = _errorCode(error);
      } finally {
        _endingSessions.remove(sessionId);
        if (_pending.isEmpty) _flushWhileIdle = false;
        if (_sessionId == null) {
          _setState(LiveTrackingConnectionState.disconnected);
        }
        _notify();
      }
    });
  }

  Future<http.Response> _sendAuthorizedGet(Uri uri) async {
    if (!_isTrustedApiUri(uri)) {
      throw const LiveTrackingProxyException('untrusted_proxy_uri');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        ...await _authProvider.authorizationHeaders(),
      });
    final streamed = await _httpClient
        .send(request)
        .timeout(_config.requestTimeout);
    return http.Response.fromStream(streamed).timeout(_config.requestTimeout);
  }

  bool _isTrustedApiUri(Uri uri) =>
      uri.scheme == _config.apiBaseUri.scheme &&
      uri.host.toLowerCase() == _config.apiBaseUri.host.toLowerCase() &&
      uri.port == _config.apiBaseUri.port &&
      uri.userInfo.isEmpty;

  Future<http.Response> _sendJson({
    required String method,
    required Uri uri,
    required Map<String, Object?> body,
  }) async {
    if (!_isTrustedApiUri(uri)) {
      throw const LiveTrackingProxyException('untrusted_proxy_uri');
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _authProvider.authorizationHeaders(),
    };
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final streamed = await _httpClient
        .send(request)
        .timeout(_config.requestTimeout);
    return http.Response.fromStream(streamed).timeout(_config.requestTimeout);
  }

  Map<String, dynamic>? _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _persistQueue() {
    final snapshot = List<QueuedProxyPoint>.unmodifiable(_pending);
    _saveTail = _saveTail
        .catchError((Object _) {})
        .then((_) => _pointStore.save(snapshot))
        .catchError((Object error) {
          _lastErrorCode = 'queue_save_failed';
          _notify();
        });
    return _saveTail;
  }

  void _scheduleRetry() {
    if (_disposed || _retryTimer != null) return;
    final exponent = _retryAttempt.clamp(0, 5).toInt();
    final seconds = (2 * (1 << exponent)).clamp(2, 60).toInt();
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      if (_shouldTrack) _queueLifecycleSync();
      unawaited(_flushPending());
    });
  }

  String _errorCode(Object error) => error is LiveTrackingProxyException
      ? error.code
      : error is LiveTrackingProxyAuthException
      ? error.code
      : 'proxy_network_error';

  void _setState(LiveTrackingConnectionState next) {
    if (_state == next) return;
    _state = next;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> shutdown() async {
    unbind();
    _retryTimer?.cancel();
    _uploadTimer?.cancel();
    _locationDataDeletionRetryTimer?.cancel();
    _locationDataDeletionRetryTimer = null;
    await _sessionEndTail.catchError((Object _) {});
    await _saveTail.catchError((Object _) {});
    _disposeRoomSocket();
    if (_ownsHttpClient) _httpClient.close();
    _disposed = true;
    dispose();
  }

  @override
  void dispose() {
    if (!_disposed) {
      unbind();
      _disposed = true;
      _retryTimer?.cancel();
      _uploadTimer?.cancel();
      _locationDataDeletionRetryTimer?.cancel();
      _locationDataDeletionRetryTimer = null;
      _disposeRoomSocket();
      if (_ownsHttpClient) _httpClient.close();
    }
    super.dispose();
  }
}

class LiveTrackingProxyException implements Exception {
  const LiveTrackingProxyException(this.code);

  final String code;

  @override
  String toString() => 'LiveTrackingProxyException($code)';
}
