import '../../core/storage/key_value_store.dart';
import '../../core/storage/secure_store.dart';

/// Local-only parental lock. The PIN is stored in secure storage (no default —
/// unlike the legacy app's hard-coded 12345). Locked ids live in prefs.
class ParentalLockRepository {
  final SecureStore secure;
  final KeyValueStore store;
  ParentalLockRepository({required this.secure, required this.store});

  static const _pinKey = 'parental_pin';
  String _lockKey(String kind) => 'locked_$kind';

  Future<bool> hasPin() async {
    final p = await secure.read(_pinKey);
    return p != null && p.isNotEmpty;
  }

  Future<void> setPin(String pin) => secure.write(_pinKey, pin);

  Future<void> clearPin() => secure.delete(_pinKey);

  Future<bool> verify(String pin) async => (await secure.read(_pinKey)) == pin;

  Future<Set<String>> lockedIds(String kind) => store.getStringSet(_lockKey(kind));

  Future<bool> isLocked(String kind, String id) async =>
      (await store.getStringSet(_lockKey(kind))).contains(id);

  Future<void> setLocked(String kind, String id, bool locked) async {
    final s = await store.getStringSet(_lockKey(kind));
    locked ? s.add(id) : s.remove(id);
    await store.setStringSet(_lockKey(kind), s);
  }
}
