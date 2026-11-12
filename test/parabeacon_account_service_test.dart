import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/parabeacon_account_service.dart';

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
      expect(store.values['parabeacon_access_token'], 'test-access-token');
      expect(store.values.toString(), isNot(contains('abc123')));
    },
  );

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
