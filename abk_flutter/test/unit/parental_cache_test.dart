import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/core/storage/secure_store.dart';
import 'package:abk_player/features/favorites/parental_lock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// SecureStore that counts reads/writes so we can assert the Keychain is only
/// touched once for the PIN, not on every play path.
class _CountingSecureStore implements SecureStore {
  final Map<String, String> _m = {};
  int reads = 0, writes = 0, deletes = 0;
  @override
  Future<String?> read(String key) async {
    reads++;
    return _m[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    _m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    _m.remove(key);
  }

  @override
  Future<void> deleteAll() async => _m.clear();
}

void main() {
  test('PIN is read from secure storage once, then served from memory', () async {
    final secure = _CountingSecureStore();
    await secure.write('parental_pin', '4321'); // pre-existing PIN
    secure.writes = 0; // reset after seeding

    final repo = ParentalLockRepository(secure: secure, store: InMemoryKeyValueStore());

    // Simulate many content-open / play paths.
    for (var i = 0; i < 20; i++) {
      await repo.hasPin();
      await repo.verify('0000');
    }
    await repo.warmUp();

    expect(secure.reads, 1, reason: 'exactly one Keychain read regardless of call count');
    expect(await repo.hasPin(), isTrue);
    expect(await repo.verify('4321'), isTrue);
    expect(secure.reads, 1, reason: 'still one — verify/hasPin served from cache');
  });

  test('setPin / clearPin update the cache and write once, no extra reads', () async {
    final secure = _CountingSecureStore();
    final repo = ParentalLockRepository(secure: secure, store: InMemoryKeyValueStore());

    await repo.setPin('1111');
    expect(secure.writes, 1);
    expect(await repo.hasPin(), isTrue);
    expect(await repo.verify('1111'), isTrue);
    expect(secure.reads, 0, reason: 'setPin seeds the cache — no read needed');

    await repo.clearPin();
    expect(secure.deletes, 1);
    expect(await repo.hasPin(), isFalse);
    expect(secure.reads, 0, reason: 'clearPin clears the cache — still no read');
  });

  test('locked-id checks never touch secure storage (prefs only)', () async {
    final secure = _CountingSecureStore();
    final repo = ParentalLockRepository(secure: secure, store: InMemoryKeyValueStore());
    await repo.setLocked('live', '7', true);
    expect(await repo.isLocked('live', '7'), isTrue);
    expect(secure.reads, 0);
    expect(secure.writes, 0);
  });
}
