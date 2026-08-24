import 'dart:convert';

import '../../core/storage/key_value_store.dart';

/// Local-only "Continue watching" / recently-played history (UI convenience;
/// no backend). Players write an entry on load; Home reads the most recent.
class PlaybackEntry {
  final String id;
  final String kind; // live | movie | episode
  final String title;
  final String subtitle;
  final String? image;
  final double progress; // 0..1 (0 for live)
  final int updatedAt;

  PlaybackEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.image,
    this.progress = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'title': title, 'subtitle': subtitle,
        'image': image, 'progress': progress, 'updatedAt': updatedAt,
      };

  static PlaybackEntry fromJson(Map m) => PlaybackEntry(
        id: '${m['id']}',
        kind: '${m['kind']}',
        title: '${m['title']}',
        subtitle: '${m['subtitle']}',
        image: m['image'] as String?,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackHistoryRepository {
  final KeyValueStore store;
  PlaybackHistoryRepository(this.store);
  static const _key = 'playback_history_v1';

  Future<List<PlaybackEntry>> recent({int limit = 20}) async {
    final raw = await store.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).whereType<Map>().map(PlaybackEntry.fromJson).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> record(PlaybackEntry entry) async {
    final all = await recent(limit: 100);
    all.removeWhere((e) => e.id == entry.id && e.kind == entry.kind);
    all.insert(0, entry);
    await store.setString(_key, jsonEncode(all.take(50).map((e) => e.toJson()).toList()));
  }
}
