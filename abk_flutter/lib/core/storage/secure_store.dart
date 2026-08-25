import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Encrypted storage for secrets (credentials, server-returned credentials,
/// session). Behind an interface so unit tests use an in-memory fake and no
/// secret ever touches shared preferences, logs, or fixtures.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// macOS secret store backed by an obfuscated file inside the app's **App
/// Sandbox container** (Application Support), NOT the Keychain.
///
/// The macOS legacy Keychain prompts for the system password whenever the
/// reading process's code signature differs from the item's owner — which is
/// every rebuild of a locally/ad-hoc-signed app, causing the owner's repeated
/// "enter password" prompts. The App Sandbox container is already private to
/// this app (the OS isolates it), so storing secrets there needs no Keychain
/// and never prompts. The XOR layer is defence-in-depth over that boundary.
class MacOsFileSecureStore implements SecureStore {
  static const _fileName = 'abk_secure.dat';
  // Fixed obfuscation key (the real boundary is the sandbox container).
  static final List<int> _xor = utf8.encode('abk#macos-sbx#v1');

  Map<String, String>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, String>> _all() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file();
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        final plain = utf8.decode(_crypt(bytes), allowMalformed: true);
        final map = jsonDecode(plain) as Map;
        _cache = map.map((k, v) => MapEntry('$k', '$v'));
      } else {
        _cache = {};
      }
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      final bytes = _crypt(Uint8List.fromList(utf8.encode(jsonEncode(_cache))));
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // best-effort; degrades to a non-persistent session
    }
  }

  Uint8List _crypt(List<int> data) {
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ _xor[i % _xor.length];
    }
    return out;
  }

  @override
  Future<String?> read(String key) async => (await _all())[key];

  @override
  Future<void> write(String key, String value) async {
    (await _all())[key] = value;
    await _persist();
  }

  @override
  Future<void> delete(String key) async {
    (await _all()).remove(key);
    await _persist();
  }

  @override
  Future<void> deleteAll() async {
    (await _all()).clear();
    await _persist();
  }
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
