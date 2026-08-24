import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/core/storage/secure_store.dart';
import 'package:abk_player/features/favorites/favorites_repository.dart';
import 'package:abk_player/features/favorites/parental_lock_repository.dart';
import 'package:abk_player/features/favorites/resume_repository.dart';
import 'package:abk_player/features/settings/catalogue_cache_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FavoritesRepository add/remove/toggle/isFavorite', () async {
    final repo = FavoritesRepository(InMemoryKeyValueStore());
    expect(await repo.isFavorite('live', '1'), isFalse);
    await repo.add('live', '1');
    expect(await repo.isFavorite('live', '1'), isTrue);
    expect(await repo.toggle('live', '1'), isFalse); // now removed
    expect(await repo.isFavorite('live', '1'), isFalse);
    expect(await repo.toggle('live', '2'), isTrue); // added
    expect(await repo.getFavorites('live'), {'2'});
  });

  test('ResumeRepository positions + recent ordering', () async {
    final repo = ResumeRepository(InMemoryKeyValueStore());
    await repo.setPosition('m1', 120);
    await repo.setPosition('m2', 300);
    await repo.setPosition('m1', 200); // touch m1 -> most recent
    expect(await repo.getPosition('m1'), 200);
    expect(await repo.getPosition('m2'), 300);
    expect((await repo.recentIds()).first, 'm1');
    await repo.clear('m1');
    expect(await repo.getPosition('m1'), isNull);
  });

  test('ParentalLockRepository pin + locks', () async {
    final repo = ParentalLockRepository(
      secure: InMemorySecureStore(),
      store: InMemoryKeyValueStore(),
    );
    expect(await repo.hasPin(), isFalse);
    await repo.setPin('4321');
    expect(await repo.hasPin(), isTrue);
    expect(await repo.verify('0000'), isFalse);
    expect(await repo.verify('4321'), isTrue);
    await repo.setLocked('live', '7', true);
    expect(await repo.isLocked('live', '7'), isTrue);
    await repo.setLocked('live', '7', false);
    expect(await repo.isLocked('live', '7'), isFalse);
  });

  test('CatalogueCacheMeta staleness with injected clock', () async {
    var clock = DateTime(2026, 1, 1, 12);
    final meta = CatalogueCacheMeta(InMemoryKeyValueStore(), now: () => clock);
    expect(await meta.isStale('live', const Duration(hours: 24)), isTrue);
    await meta.markUpdated('live');
    expect(await meta.isStale('live', const Duration(hours: 24)), isFalse);
    clock = clock.add(const Duration(hours: 25));
    expect(await meta.isStale('live', const Duration(hours: 24)), isTrue);
  });
}
