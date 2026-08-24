/// Local-only search over already-loaded catalogues (the backend has no search
/// endpoint). Case-insensitive substring match on a name selector. Pure and
/// synchronous — callers may run it via `compute` for very large lists.
class LocalSearch {
  static List<T> filter<T>(
    List<T> items,
    String query,
    String Function(T item) nameOf, {
    int? limit,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return limit == null ? items : items.take(limit).toList();
    final out = <T>[];
    for (final item in items) {
      if (nameOf(item).toLowerCase().contains(q)) {
        out.add(item);
        if (limit != null && out.length >= limit) break;
      }
    }
    return out;
  }
}
