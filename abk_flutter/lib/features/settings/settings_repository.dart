import '../../core/storage/key_value_store.dart';

/// Local, non-sensitive app settings (player preference, last category, etc.).
class SettingsRepository {
  final KeyValueStore store;
  SettingsRepository(this.store);

  Future<String?> getString(String key) => store.getString(key);
  Future<void> setString(String key, String value) => store.setString(key, value);
  Future<bool> getFlag(String key, {bool defaultValue = false}) =>
      store.getBool(key, defaultValue: defaultValue);
  Future<void> setFlag(String key, bool value) => store.setBool(key, value);
}
