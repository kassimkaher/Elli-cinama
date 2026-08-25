import '../../core/storage/key_value_store.dart';
import '../../core/storage/secure_store.dart';

/// Local-only parental lock. The PIN is stored in secure storage (no default —
/// unlike the legacy app's hard-coded 12345). Locked ids live in prefs.
///
/// The PIN is read from the Keychain/secure store **at most once** and then
/// served from an in-memory cache. Content-open and playback paths call
/// [hasPin]/[verify] frequently; without the cache each call was a Keychain
/// read, which on macOS triggered a repeated system-password prompt. Only
/// [setPin]/[clearPin] write to secure storage.
class ParentalLockRepository {
  final SecureStore secure;
  final KeyValueStore store;
  ParentalLockRepository({required this.secure, required this.store});

  static const _pinKey = 'parental_pin';
  String _lockKey(String kind) => 'locked_$kind';

  String? _cachedPin;
  bool _pinLoaded = false;

  /// One-time secure read into memory. Safe to call eagerly at startup so the
  /// single Keychain access happens up front rather than on a play path.
  Future<void> warmUp() => _ensurePinLoaded();

  Future<void> _ensurePinLoaded() async {
    if (_pinLoaded) return;
    try {
      _cachedPin = await secure.read(_pinKey);
    } catch (_) {
      _cachedPin = null;
    }
    _pinLoaded = true;
  }

  Future<bool> hasPin() async {
    await _ensurePinLoaded();
    return _cachedPin != null && _cachedPin!.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await secure.write(_pinKey, pin);
    _cachedPin = pin;
    _pinLoaded = true;
  }

  Future<void> clearPin() async {
    await secure.delete(_pinKey);
    _cachedPin = null;
    _pinLoaded = true;
  }

  Future<bool> verify(String pin) async {
    await _ensurePinLoaded();
    return _cachedPin == pin;
  }

  Future<Set<String>> lockedIds(String kind) => store.getStringSet(_lockKey(kind));

  Future<bool> isLocked(String kind, String id) async =>
      (await store.getStringSet(_lockKey(kind))).contains(id);

  Future<void> setLocked(String kind, String id, bool locked) async {
    final s = await store.getStringSet(_lockKey(kind));
    locked ? s.add(id) : s.remove(id);
    await store.setStringSet(_lockKey(kind), s);
  }
}
