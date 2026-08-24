import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/utils/result.dart';
import '../epg/domain/entities.dart';
import '../favorites/playback_history_repository.dart';
import '../live/domain/entities.dart';
import '../movies/domain/entities.dart';
import '../series/domain/entities.dart';

/// Presentation data layer: caches the confirmed use-case results as
/// [AsyncValue]s. No networking logic lives in widgets. Refresh = invalidate.
T _unwrap<T>(Result<T> r) => r.fold((v) => v, (f) => throw f);

// ---- Live -------------------------------------------------------------------
final liveCategoriesProvider = FutureProvider<List<LiveCategory>>((ref) async =>
    _unwrap(await ref.read(getLiveCategoriesProvider).call()));

final liveChannelsProvider = FutureProvider<List<LiveChannel>>((ref) async =>
    _unwrap(await ref.read(getLiveChannelsProvider).call()));

/// Channels grouped by category id (built once off the big list).
final channelsByCategoryProvider = FutureProvider<Map<int, List<LiveChannel>>>((ref) async {
  final channels = await ref.watch(liveChannelsProvider.future);
  final map = <int, List<LiveChannel>>{};
  for (final ch in channels) {
    (map[ch.categoryId ?? -1] ??= []).add(ch);
  }
  return map;
});

// ---- Movies -----------------------------------------------------------------
final movieCategoriesProvider = FutureProvider<List<MovieCategory>>((ref) async =>
    _unwrap(await ref.read(getMovieCategoriesProvider).call()));

final moviesProvider = FutureProvider<List<MovieListItem>>((ref) async =>
    _unwrap(await ref.read(getMoviesProvider).call()));

final movieInfoProvider = FutureProvider.family<MovieInfo, String>((ref, id) async =>
    _unwrap(await ref.read(getMovieInfoProvider).call(id)));

// ---- Series -----------------------------------------------------------------
final seriesCategoriesProvider = FutureProvider<List<SeriesCategory>>((ref) async =>
    _unwrap(await ref.read(getSeriesCategoriesProvider).call()));

final seriesListProvider = FutureProvider<List<SeriesListItem>>((ref) async =>
    _unwrap(await ref.read(getSeriesProvider).call()));

final seriesInfoProvider = FutureProvider.family<SeriesInfo, String>((ref, id) async =>
    _unwrap(await ref.read(getSeriesInfoProvider).call(id)));

// ---- EPG (optional; empty is normal) ---------------------------------------
final shortEpgProvider = FutureProvider.family<List<EpgListing>, int>((ref, streamId) async {
  final res = await ref.read(getShortEpgProvider).call(streamId);
  return res.fold((l) => l, (_) => const []);
});

// ---- Local: favourites live-refresh ----------------------------------------
/// Bumped whenever a local set (favourites/locks/history) changes so dependent
/// UI recomputes without a backend call.
final localRevisionProvider = StateProvider<int>((_) => 0);

final favoriteChannelsProvider = FutureProvider<List<LiveChannel>>((ref) async {
  ref.watch(localRevisionProvider);
  final ids = await ref.read(favoritesRepositoryProvider).getFavorites('live');
  if (ids.isEmpty) return const [];
  final channels = await ref.watch(liveChannelsProvider.future);
  final set = ids.map(int.tryParse).whereType<int>().toSet();
  return channels.where((ch) => set.contains(ch.id)).toList();
});

// ---- Local: continue watching ----------------------------------------------
final playbackHistoryRepositoryProvider =
    Provider((ref) => PlaybackHistoryRepository(ref.watch(keyValueStoreProvider)));

final continueWatchingProvider = FutureProvider<List<PlaybackEntry>>((ref) async {
  ref.watch(localRevisionProvider);
  return ref.read(playbackHistoryRepositoryProvider).recent();
});

// ---- Home featured (deterministic, local — no recommendation backend) ------
final featuredProvider = FutureProvider<MovieListItem?>((ref) async {
  final movies = await ref.watch(moviesProvider.future);
  final candidates = movies
      .where((m) => (m.backdrop ?? '').isNotEmpty && (m.plot ?? '').isNotEmpty)
      .toList();
  if (candidates.isEmpty) return null;
  // Stable within a session, rotated daily.
  final seed = DateTime.now().difference(DateTime(2020)).inDays;
  return candidates[seed % candidates.length];
});
