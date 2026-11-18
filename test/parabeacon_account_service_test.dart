import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/parabeacon_account_service.dart';
import 'package:parabeacon/data/parabeacon_server_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registers then signs in and stores only the session and public user',
    () async {
      final store = _MemorySessionStore();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/register') {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'username': 'pilot_one',
            'email': 'pilot@example.com',
            'password': 'abc123',
          });
          return http.Response(
            jsonEncode({'user': _userJson}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/auth/login') {
          expect(jsonDecode(request.body), {
            'identifier': 'pilot_one',
            'password': 'abc123',
          });
          return http.Response(
            jsonEncode({
              'access_token': 'test-access-token',
              'expires_at': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .toUtc()
                  .toIso8601String(),
              'refresh_token': 'test-refresh-token-long-enough-value',
              'refresh_expires_at': null,
              'user': _userJson,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('Unexpected request: ${request.url}');
      });
      final service = ParaBeaconAccountService(
        client: client,
        sessionStore: store,
      );
      addTearDown(service.dispose);

      final succeeded = await service.register(
        username: 'pilot_one',
        email: 'pilot@example.com',
        password: 'abc123',
      );

      expect(succeeded, isTrue);
      expect(requests, hasLength(2));
      expect(service.isSignedIn, isTrue);
      expect(service.user?.username, 'pilot_one');
      expect(service.user?.displayName, 'Sky Rider');
      expect(service.user?.pilotNumber, 123456);
      expect(store.values['parabeacon_access_token'], 'test-access-token');
      expect(
        store.values['parabeacon_refresh_token'],
        'test-refresh-token-long-enough-value',
      );
      expect(store.values['parabeacon_refresh_token_expires_at'], isNull);
      expect(store.values.toString(), isNot(contains('abc123')));
      final logs = service.debugLog.join('\n');
      expect(logs, contains('Registration response received (HTTP 201).'));
      expect(logs, contains('Sign-in succeeded; session stored securely.'));
      expect(logs, isNot(contains('pilot_one')));
      expect(logs, isNot(contains('pilot@example.com')));
      expect(logs, isNot(contains('abc123')));
      expect(logs, isNot(contains('test-access-token')));
    },
  );

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
    ParaBeaconServerConfig.configureBaseUri(Uri.parse('https://8.8.8.8'));
    addTearDown(() {
      if (ParaBeaconServerConfig.isValidUserOrigin(previousServer)) {
        ParaBeaconServerConfig.configureBaseUri(previousServer);
      }
    });
    final store = _MemorySessionStore()
      ..values['parabeacon_access_token'] = 'default-server-token'
      ..values['parabeacon_refresh_token'] = 'default-server-refresh-token';
    final client = MockClient((request) async {
      expect(request.url.host, '8.8.8.8');
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

    await service.load();
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
        email: '',
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
  'pilot_number': 123456,
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
