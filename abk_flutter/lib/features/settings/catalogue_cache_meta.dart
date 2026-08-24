import '../../core/storage/key_value_store.dart';

/// Tracks per-domain catalogue freshness for the large-catalogue cache
/// strategy. TTLs mirror the confirmed refresh cadence (live 24h,
/// movies/series 15min). `now` is injectable for tests.
class CatalogueCacheMeta {
  final KeyValueStore store;
  final DateTime Function() now;

  CatalogueCacheMeta(this.store, {DateTime Function()? now})
      : now = now ?? DateTime.now;

  static const Duration liveTtl = Duration(hours: 24);
  static const Duration moviesTtl = Duration(minutes: 15);
  static const Duration seriesTtl = Duration(minutes: 15);

  String _key(String domain) => 'cache_updated_$domain';

  Future<DateTime?> lastUpdated(String domain) async {
    final raw = await store.getString(_key(domain));
    final ms = int.tryParse(raw ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markUpdated(String domain) =>
      store.setString(_key(domain), now().millisecondsSinceEpoch.toString());

  Future<bool> isStale(String domain, Duration ttl) async {
    final last = await lastUpdated(domain);
    if (last == null) return true;
    return now().difference(last) >= ttl;
  }
}
