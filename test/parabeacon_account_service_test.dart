import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/parabeacon_account_service.dart';
import 'package:parabeacon/data/profile_image_url.dart';
import 'package:parabeacon/data/parabeacon_server_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registers pending email verification without storing a session',
    () async {
      final store = _MemorySessionStore();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/register');
        expect(jsonDecode(request.body), {
          'username': 'pilot_one',
          'email': 'pilot@example.com',
          'password': 'abc123',
        });
        return http.Response(
          jsonEncode({'status': 'verification_required'}),
          202,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = ParaBeaconAccountService(
        client: client,
        sessionStore: store,
      );
      addTearDown(service.dispose);

      final accepted = await service.register(
        username: 'pilot_one',
        email: 'pilot@example.com',
        password: 'abc123',
      );

      expect(accepted, isTrue);
      expect(requests, hasLength(1));
      expect(service.isSignedIn, isFalse);
      expect(service.user, isNull);
      expect(service.pendingVerificationEmail, 'pilot@example.com');
      expect(service.verificationEmailRequested, isTrue);
      expect(service.errorCode, isNull);
      expect(store.values, isEmpty);
      final logs = service.debugLog.join('\n');
      expect(logs, contains('Registration response received (HTTP 202).'));
      expect(logs, isNot(contains('pilot_one')));
      expect(logs, isNot(contains('pilot@example.com')));
      expect(logs, isNot(contains('abc123')));
    },
  );

  test(
    'requires a valid email and username before sending registration',
    () async {
      final store = _MemorySessionStore();
      final service = ParaBeaconAccountService(
        client: MockClient(
          (request) async => fail('Unexpected request: ${request.url}'),
        ),
        sessionStore: store,
      );
      addTearDown(service.dispose);

      expect(
        await service.register(
          username: 'pilot_one',
          email: '',
          password: 'abc123',
        ),
        isFalse,
      );
      expect(service.errorCode, 'accountInvalidInput');
      expect(
        await service.register(
          username: 'invalid-name',
          email: 'pilot@example.com',
          password: 'abc123',
        ),
        isFalse,
      );
      expect(service.errorCode, 'accountInvalidInput');
      expect(store.values, isEmpty);
    },
  );

  test('resends verification after an unverified login response', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response('{"error":"email address is not verified"}', 403);
      }
      expect(request.url.path, '/api/v1/auth/resend-verification');
      expect(jsonDecode(request.body), {'email': 'pilot@example.com'});
      return http.Response(
        jsonEncode({'status': 'verification_email_requested'}),
        202,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    expect(
      await service.login(identifier: 'pilot@example.com', password: 'abc123'),
      isFalse,
    );
    expect(service.errorCode, 'accountEmailNotVerified');
    expect(service.isSignedIn, isFalse);
    expect(store.values, isEmpty);

    expect(
      await service.resendVerificationEmail(email: 'pilot@example.com'),
      isTrue,
    );
    expect(requests.map((request) => request.url.path), [
      '/api/v1/auth/login',
      '/api/v1/auth/resend-verification',
    ]);
    expect(service.pendingVerificationEmail, 'pilot@example.com');
    expect(service.verificationEmailRequested, isTrue);
    expect(service.errorCode, isNull);
    expect(store.values, isEmpty);
  });

  test('updates and persists the account frequency channel', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'channel-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'channel-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/user/profile');
      expect(request.headers['authorization'], 'Bearer channel-token');
      expect(jsonDecode(request.body), {'channel_number': 483920});
      return http.Response(
        jsonEncode({
          'user': {..._userJson, 'channel_number': 483920},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );
    expect(await service.updateChannelNumber(-1), isFalse);
    expect(requests, hasLength(1));
    expect(await service.updateChannelNumber(483920), isTrue);
    expect(service.user?.channelNumber, 483920);
    final stored =
        jsonDecode(store.values['parabeacon_account_user']!)
            as Map<String, dynamic>;
    expect(stored['channel_number'], 483920);
  });

  test('uploads and removes the saved profile image', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'profile-image-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'profile-image-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.headers['authorization'], 'Bearer profile-image-token');
      if (request.method == 'POST') {
        expect(request.url.path, '/api/v1/user/profile-image');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        return http.Response(
          jsonEncode({
            'user': {
              ..._userJson,
              'profile_image_url':
                  '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/v1/user/profile-image');
      return http.Response(jsonEncode({'user': _userJson}), 200);
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );
    expect(
      await service.uploadProfileImage(bytes: List<int>.filled(256, 7)),
      isTrue,
    );
    expect(
      service.user?.profileImageUrl,
      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(
      ProfileImageUrl.resolve(service.user?.profileImageUrl)?.origin,
      'https://www.parabeacon.icu',
    );
    final cached =
        jsonDecode(store.values['parabeacon_account_user']!)
            as Map<String, dynamic>;
    expect(cached['profile_image_url'], service.user?.profileImageUrl);

    expect(await service.removeProfileImage(), isTrue);
    expect(service.user?.profileImageUrl, isNull);
    expect(requests.map((request) => request.method), [
      'POST',
      'POST',
      'DELETE',
    ]);
  });

  test('rejects profile image URLs outside the ParaBeacon image route', () {
    expect(
      ParaBeaconUser.fromJson({
        ..._userJson,
        'profile_image_url': 'https://attacker.example/avatar.jpg',
      }),
      isNull,
    );
    expect(
      ProfileImageUrl.resolve('/api/v1/profile-images/not-a-uuid'),
      isNull,
    );
  });

  test('updates and persists the account live-tracking display name', () async {
    final store = _MemorySessionStore();
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'profile-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'profile-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.headers['authorization'], 'Bearer profile-token');
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/user/profile');
      expect(jsonDecode(request.body), {'display_name': 'Sky Pilot'});
      return http.Response(
        jsonEncode({
          'user': {..._userJson, 'display_name': 'Sky Pilot'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);
    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );
    expect(await service.updateDisplayName('  Sky Pilot  '), isTrue);
    expect(service.user?.displayName, 'Sky Pilot');
    final stored =
        jsonDecode(store.values['parabeacon_account_user']!)
            as Map<String, dynamic>;
    expect(stored['display_name'], 'Sky Pilot');
    expect(ParaBeaconAccountService.isValidDisplayName(''), isTrue);
    expect(ParaBeaconAccountService.isValidDisplayName('A'), isTrue);
    expect(ParaBeaconAccountService.isValidDisplayName('A' * 49), isFalse);
    expect(ParaBeaconAccountService.isValidDisplayName('Bad\nName'), isFalse);
  });

  test('updates and persists introduction, gender, and birthday', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'details-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'details-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/user/profile');
      expect(jsonDecode(request.body), {
        'introduction': 'Ridge pilot',
        'gender': 'female',
        'birthday': '1990-05-06',
      });
      return http.Response(
        jsonEncode({
          'user': {
            ..._userJson,
            'introduction': 'Ridge pilot',
            'gender': 'female',
            'birthday': '1990-05-06',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);
    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );
    expect(
      await service.updateProfileDetails(
        introduction: ' Ridge pilot ',
        gender: 'Female',
        birthday: '1990-05-06',
      ),
      isTrue,
    );
    expect(service.user?.introduction, 'Ridge pilot');
    expect(service.user?.gender, 'female');
    expect(service.user?.birthday, '1990-05-06');
    final stored =
        jsonDecode(store.values['parabeacon_account_user']!)
            as Map<String, dynamic>;
    expect(stored['introduction'], 'Ridge pilot');
    expect(stored['gender'], 'female');
    expect(stored['birthday'], '1990-05-06');
    expect(await service.updateProfileDetails(gender: 'unknown'), isFalse);
    expect(await service.updateProfileDetails(birthday: '2035-15-55'), isFalse);
    expect(requests, hasLength(2));
  });

  test('updates and persists the account channel number', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'channel-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'channel-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/user/profile');
      expect(request.headers['authorization'], 'Bearer channel-token');
      expect(jsonDecode(request.body), {'channel_number': 483920});
      return http.Response(
        jsonEncode({
          'user': {..._userJson, 'channel_number': 483920},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);
    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );
    expect(await service.updateChannelNumber(-1), isFalse);
    expect(requests, hasLength(1));
    expect(await service.updateChannelNumber(483920), isTrue);
    expect(service.user?.channelNumber, 483920);
    final stored =
        jsonDecode(store.values['parabeacon_account_user']!)
            as Map<String, dynamic>;
    expect(stored['channel_number'], 483920);
  });

  test('changes password and locally clears the revoked session', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'password-change-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'password-change-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': _userJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/api/v1/user/change-password');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer password-change-token');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['new_password'], 'new-pass-456');
      if (payload['current_password'] == 'wrong-pass') {
        return http.Response('{"error":"current password is incorrect"}', 401);
      }
      expect(payload['current_password'], 'old-pass-123');
      return http.Response('', 204);
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    expect(
      await service.login(identifier: 'pilot_one', password: 'old-pass-123'),
      isTrue,
    );
    expect(
      await service.changePassword(
        currentPassword: 'old-pass-123',
        newPassword: 'short',
      ),
      isFalse,
    );
    expect(
      requests,
      hasLength(1),
      reason: 'invalid new passwords are rejected before sending',
    );
    expect(
      await service.changePassword(
        currentPassword: 'wrong-pass',
        newPassword: 'new-pass-456',
      ),
      isFalse,
    );
    expect(service.errorCode, 'accountCurrentPasswordIncorrect');
    expect(service.isSignedIn, isTrue);

    expect(
      await service.changePassword(
        currentPassword: 'old-pass-123',
        newPassword: 'new-pass-456',
      ),
      isTrue,
    );
    expect(service.isSignedIn, isFalse);
    expect(service.user, isNull);
    expect(store.values, isEmpty);
    final logs = service.debugLog.join('\\n');
    expect(logs, isNot(contains('old-pass-123')));
    expect(logs, isNot(contains('new-pass-456')));
  });

  test('keeps account sessions isolated between server origins', () async {
    final previousServer = ParaBeaconServerConfig.apiBaseUri;
    ParaBeaconServerConfig.configureBaseUri(
      ParaBeaconServerConfig.defaultApiBaseUri,
    );
    addTearDown(() {
      if (ParaBeaconServerConfig.isValidUserOrigin(previousServer)) {
        ParaBeaconServerConfig.configureBaseUri(previousServer);
      }
    });
    final store = _MemorySessionStore()
      ..values['parabeacon_access_token'] = 'default-server-token'
      ..values['parabeacon_refresh_token'] = 'default-server-refresh-token';
    final client = MockClient((request) async {
      expect(request.url.scheme, 'http');
      expect(request.url.host, '8.8.8.8');
      expect(request.url.port, 8080);
      expect(request.url.path, '/api/v1/auth/login');
      expect(request.headers['authorization'], isNull);
      return http.Response(
        jsonEncode({
          'access_token': 'custom-server-token',
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
          'refresh_token': 'custom-server-refresh-token-long-value',
          'refresh_expires_at': null,
          'user': _userJson,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    expect(
      await service.switchServer(Uri.parse('http://8.8.8.8:8080')),
      isTrue,
    );
    expect(service.isSignedIn, isFalse);
    expect(
      await service.login(identifier: 'pilot_one', password: 'abc123'),
      isTrue,
    );

    expect(store.values['parabeacon_access_token'], 'default-server-token');
    expect(
      store.values['parabeacon_refresh_token'],
      'default-server-refresh-token',
    );
    expect(
      store.values.entries.any(
        (entry) =>
            entry.key.startsWith('parabeacon_access_token_') &&
            entry.value == 'custom-server-token',
      ),
      isTrue,
    );
  });

  test(
    'rejects passwords shorter than six characters before sending',
    () async {
      final service = ParaBeaconAccountService(
        client: MockClient(
          (request) async => fail('Unexpected request: ${request.url}'),
        ),
        sessionStore: _MemorySessionStore(),
      );
      addTearDown(service.dispose);

      final succeeded = await service.register(
        username: 'pilot_one',
        email: 'pilot@example.com',
        password: 'abc12',
      );

      expect(succeeded, isFalse);
      expect(service.errorCode, 'accountInvalidInput');
    },
  );

  test(
    'restores and refreshes a saved profile using its bearer token',
    () async {
      final store = _MemorySessionStore()
        ..values['parabeacon_access_token'] = 'saved-token'
        ..values['parabeacon_access_token_expires_at'] = DateTime.now()
            .add(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String()
        ..values['parabeacon_account_user'] = jsonEncode(_userJson);
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/user/profile');
        expect(request.headers['Authorization'], 'Bearer saved-token');
        return http.Response(
          jsonEncode({
            'user': {..._userJson, 'username': 'updated_pilot'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = ParaBeaconAccountService(
        client: client,
        sessionStore: store,
      );
      addTearDown(service.dispose);

      await service.load();

      expect(service.isLoaded, isTrue);
      expect(service.isSignedIn, isTrue);
      expect(service.user?.username, 'updated_pilot');
    },
  );

  test('rotates refresh tokens before access-token expiry', () async {
    final store = _MemorySessionStore()
      ..values['parabeacon_access_token'] = 'old-access-token'
      ..values['parabeacon_access_token_expires_at'] = DateTime.now()
          .add(const Duration(seconds: 30))
          .toUtc()
          .toIso8601String()
      ..values['parabeacon_refresh_token'] =
          'old-refresh-token-value-long-enough'
      ..values['parabeacon_refresh_token_expires_at'] = DateTime.now()
          .subtract(const Duration(days: 20))
          .toUtc()
          .toIso8601String()
      ..values['parabeacon_account_user'] = jsonEncode(_userJson);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/refresh') {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'refresh_token': 'old-refresh-token-value-long-enough',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'new-access-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'new-refresh-token-value-long-enough',
            'refresh_expires_at': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/api/v1/user/profile');
      expect(request.headers['Authorization'], 'Bearer new-access-token');
      return http.Response(jsonEncode({'user': _userJson}), 200);
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    final headers = await service.authorizationHeaders();

    expect(headers['Authorization'], 'Bearer new-access-token');
    expect(store.values['parabeacon_access_token'], 'new-access-token');
    expect(
      store.values['parabeacon_refresh_token'],
      'new-refresh-token-value-long-enough',
    );
    expect(store.values['parabeacon_refresh_token_expires_at'], isNull);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/auth/refresh',
      '/api/v1/user/profile',
    ]);
  });

  test('maps invalid credentials without storing a session', () async {
    final store = _MemorySessionStore();
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/login');
      return http.Response(
        jsonEncode({'error': 'invalid email or password'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ParaBeaconAccountService(
      client: client,
      sessionStore: store,
    );
    addTearDown(service.dispose);

    final succeeded = await service.login(
      identifier: 'pilot_one',
      password: 'wrong-password',
    );

    expect(succeeded, isFalse);
    expect(service.errorCode, 'accountInvalidCredentials');
    expect(service.isSignedIn, isFalse);
    expect(store.values, isEmpty);
  });
}

const _userJson = {
  'id': 'user-123',
  'username': 'pilot_one',
  'display_name': 'Sky Rider',
  'introduction': '',
  'gender': '',
  'birthday': '',
  'pilot_number': 123456,
  'channel_number': 0,
  'avatar_id': 0,
  'email': 'pilot@example.com',
  'created_at': '2026-01-01T12:00:00Z',
};

class _MemorySessionStore implements AccountSessionStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
