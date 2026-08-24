import '../../core/storage/key_value_store.dart';

/// Local-only favourites (no backend endpoint). `kind` is one of
/// 'live' | 'movie' | 'series'; ids are the stable content ids.
class FavoritesRepository {
  final KeyValueStore store;
  FavoritesRepository(this.store);

  String _key(String kind) => 'fav_$kind';

  Future<Set<String>> getFavorites(String kind) => store.getStringSet(_key(kind));

  Future<bool> isFavorite(String kind, String id) async =>
      (await store.getStringSet(_key(kind))).contains(id);

  Future<void> add(String kind, String id) async {
    final s = await store.getStringSet(_key(kind));
    s.add(id);
    await store.setStringSet(_key(kind), s);
  }

  Future<void> remove(String kind, String id) async {
    final s = await store.getStringSet(_key(kind));
    s.remove(id);
    await store.setStringSet(_key(kind), s);
  }

  Future<bool> toggle(String kind, String id) async {
    final s = await store.getStringSet(_key(kind));
    final now = !s.contains(id);
    now ? s.add(id) : s.remove(id);
    await store.setStringSet(_key(kind), s);
    return now;
  }
}
