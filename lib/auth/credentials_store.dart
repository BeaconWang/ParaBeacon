/// Where username / password / token live.
///
/// The APK keeps all four values in the SECURE SharedPreferences group
/// (config/n2.smali:65-77). The default implementation here is in-memory only:
/// the password is never written to disk. Swap in `flutter_secure_storage`
/// (or Keychain/Keystore) by extending [CredentialsStore].
library;

import 'auth_config.dart';

abstract class CredentialsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);

  Future<String?> get username => read(kPrefUsername);
  Future<void> setUsername(String? v) => write(kPrefUsername, v);

  Future<String?> get password => read(kPrefPassword);
  Future<void> setPassword(String? v) => write(kPrefPassword, v);

  Future<String?> get token => read(kPrefAuthToken);
  Future<void> setToken(String? v) => write(kPrefAuthToken, v);

  Future<String?> get uid => read(kPrefUid);
  Future<void> setUid(String? v) => write(kPrefUid, v);

  /// Mirrors config/t0.W(token, uid): stores both, or clears both on logout.
  Future<void> saveSession(String? token, String? uid) async {
    await setToken(token);
    await setUid(uid);
  }
}

/// Default: process memory only. Nothing is persisted.
class MemoryCredentialsStore extends CredentialsStore {
  final Map<String, String?> _values = <String, String?>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async => _values[key] = value;
}
