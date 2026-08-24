import 'dart:convert';

import '../../core/storage/key_value_store.dart';

/// Local-only recent / resume positions (seconds) keyed by content id.
class ResumeRepository {
  final KeyValueStore store;
  ResumeRepository(this.store);

  static const _positions = 'resume_positions';
  static const _recent = 'recent_ids';

  Future<Map<String, int>> _all() async {
    final raw = await store.getString(_positions);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<int?> getPosition(String id) async => (await _all())[id];

  Future<void> setPosition(String id, int seconds) async {
    final map = await _all();
    map[id] = seconds;
    await store.setString(_positions, jsonEncode(map));
    await _pushRecent(id);
  }

  Future<void> clear(String id) async {
    final map = await _all();
    map.remove(id);
    await store.setString(_positions, jsonEncode(map));
  }

  Future<List<String>> _recentList() async {
    final raw = await store.getString(_recent);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _pushRecent(String id) async {
    final list = await _recentList();
    list.remove(id);
    list.insert(0, id);
    await store.setString(_recent, jsonEncode(list.take(50).toList()));
  }

  Future<List<String>> recentIds({int limit = 20}) async {
    final list = await _recentList();
    return list.take(limit).toList();
  }
}
