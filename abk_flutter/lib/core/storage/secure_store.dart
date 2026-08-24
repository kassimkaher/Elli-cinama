import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for secrets (credentials, server-returned credentials,
/// session). Behind an interface so unit tests use an in-memory fake and no
/// secret ever touches shared preferences, logs, or fixtures.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStore implements SecureStore {
  final FlutterSecureStorage storage;
  FlutterSecureStore([FlutterSecureStorage? s])
      : storage = s ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              // macOS/iOS: use the legacy keychain so a locally-signed dev
              // build (no development certificate) can access the keychain
              // without the keychain-access-groups entitlement (which requires
              // a paid Apple team). Avoids error -34018 under App Sandbox.
              mOptions: MacOsOptions(useDataProtectionKeyChain: false),
              iOptions: IOSOptions(),
            );

  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
  @override
  Future<void> deleteAll() => storage.deleteAll();
}

class InMemorySecureStore implements SecureStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> deleteAll() async => _m.clear();
}
