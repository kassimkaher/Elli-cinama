import '../../../core/utils/json_utils.dart';
import '../domain/entities.dart';

class SeriesModels {
  static SeriesCategory categoryFromJson(Map json) {
    final m = asMap(json);
    return SeriesCategory(
      id: asString(m['id']),
      name: asString(m['category_name']),
      icon: asStringOrNull(m['category_icon']),
      streamCount: asIntOrNull(m['stream_count']),
      catOrder: asStringOrNull(m['cat_order']),
      parentId: asStringOrNull(m['parent_id']),
      isLocked: asBoolOrNull(m['isLocked']) ?? false,
    );
  }

  static SeriesListItem listItemFromJson(Map json) {
    final m = asMap(json);
    return SeriesListItem(
      id: asString(m['id']),
      title: asString(m['title']),
      icon: asStringOrNull(m['icon']),
      categoryId: asStringOrNull(m['catid']),
      iconBig: asStringOrNull(m['icon_big']),
      backdrop: asStringOrNull(m['backdrop']),
      genre: asStringOrNull(m['genre']),
      plot: asStringOrNull(m['plot']),
      cast: asStringOrNull(m['cast']),
      rating: asStringOrNull(m['rating']),
      director: asStringOrNull(m['director']),
      releaseDate: asStringOrNull(m['releaseDate']),
      viewOrder: asIntOrNull(m['view_order']),
    );
  }

  static SeriesDetail detailFromJson(Map json) {
    final m = asMap(json);
    // backdrop is a List<String> in series_info (contrast series_list String).
    final rawBackdrop = m['backdrop'];
    final backdrops = rawBackdrop is List
        ? rawBackdrop.map((e) => e.toString()).toList()
        : (rawBackdrop is String && rawBackdrop.isNotEmpty ? [rawBackdrop] : <String>[]);
    return SeriesDetail(
      title: asString(m['title']),
      plot: asStringOrNull(m['plot']),
      cast: asStringOrNull(m['cast']),
      genre: asStringOrNull(m['genre']),
      rating: asStringOrNull(m['rating']),
      director: asStringOrNull(m['director']),
      releaseDate: asStringOrNull(m['releaseDate']),
      trailer: asStringOrNull(m['trailer']),
      icon: asStringOrNull(m['icon']),
      backdrops: backdrops,
    );
  }

  static Episode episodeFromJson(Map json) {
    final m = asMap(json);
    return Episode(
      episodeNum: asStringOrNull(m['episode_num']),
      episodeName: asStringOrNull(m['episode_name']),
      streamUrl: asStringOrNull(m['stream_url']),
    );
  }

  static Season seasonFromJson(Map json) {
    final m = asMap(json);
    final eps = asList(m['episodes'])
        .whereType<Map>()
        .map(episodeFromJson)
        .toList(growable: false);
    return Season(seasonNum: asInt(m['season_num']), episodes: eps);
  }

  static SeriesInfo infoFromJson(Map json) {
    final m = asMap(json);
    final info = m['info'] is Map ? detailFromJson(m['info'] as Map) : null;
    final seasons = asList(m['seasons'])
        .whereType<Map>()
        .map(seasonFromJson)
        .toList(growable: false);
    return SeriesInfo(info: info, seasons: seasons);
  }
}
