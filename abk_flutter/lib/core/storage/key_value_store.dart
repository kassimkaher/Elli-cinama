import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive key/value storage (prefs + local features). Behind an
/// interface so unit tests use an in-memory fake with no plugin binding.
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);
  Future<Set<String>> getStringSet(String key);
  Future<void> setStringSet(String key, Set<String> values);
  Future<void> remove(String key);
}

class SharedPrefsKeyValueStore implements KeyValueStore {
  final SharedPreferences prefs;
  SharedPrefsKeyValueStore(this.prefs);

  @override
  Future<String?> getString(String key) async => prefs.getString(key);
  @override
  Future<void> setString(String key, String value) async => prefs.setString(key, value);
  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async =>
      prefs.getBool(key) ?? defaultValue;
  @override
  Future<void> setBool(String key, bool value) async => prefs.setBool(key, value);
  @override
  Future<Set<String>> getStringSet(String key) async =>
      (prefs.getStringList(key) ?? const <String>[]).toSet();
  @override
  Future<void> setStringSet(String key, Set<String> values) async =>
      prefs.setStringList(key, values.toList());
  @override
  Future<void> remove(String key) async => prefs.remove(key);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _m = {};
  @override
  Future<String?> getString(String key) async => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async =>
      (_m[key] as bool?) ?? defaultValue;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Future<Set<String>> getStringSet(String key) async =>
      (_m[key] as Set<String>?) ?? <String>{};
  @override
  Future<void> setStringSet(String key, Set<String> values) async => _m[key] = values;
  @override
  Future<void> remove(String key) async => _m.remove(key);
}
