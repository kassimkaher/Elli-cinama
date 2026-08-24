import '../../../core/utils/json_utils.dart';
import '../domain/entities.dart';

class MovieModels {
  static MovieCategory categoryFromJson(Map json) {
    final m = asMap(json);
    return MovieCategory(
      id: asString(m['id']),
      name: asString(m['category_name']),
      icon: asStringOrNull(m['category_icon']),
      streamCount: asIntOrNull(m['stream_count']),
      catOrder: asStringOrNull(m['cat_order']),
      parentId: asStringOrNull(m['parent_id']),
      isLocked: asBoolOrNull(m['isLocked']) ?? false,
    );
  }

  static MovieListItem listItemFromJson(Map json) {
    final m = asMap(json);
    return MovieListItem(
      id: asString(m['id']),
      name: asString(m['stream_display_name']),
      categoryId: asStringOrNull(m['category_id']),
      icon: asStringOrNull(m['stream_icon']),
      backdrop: asStringOrNull(m['backdrop']),
      plot: asStringOrNull(m['plot']),
      rating: asStringOrNull(m['rating']),
      genre: asStringOrNull(m['genre']),
      cast: asStringOrNull(m['cast']),
      year: asStringOrNull(m['year']),
      viewOrder: asStringOrNull(m['view_order']),
    );
  }

  static StreamQualities qualitiesFromJson(Object? raw) {
    final m = asMap(raw);
    return StreamQualities(
      p480: asStringOrNull(m['480p']),
      p720: asStringOrNull(m['720p']),
      p1080: asStringOrNull(m['1080p']),
      p4k: asStringOrNull(m['4k']),
    );
  }

  static MovieInfo infoFromJson(Map json) {
    final m = asMap(json);
    return MovieInfo(
      id: asStringOrNull(m['id']),
      title: asString(m['title']),
      trailer: asStringOrNull(m['trailer']),
      icon: asStringOrNull(m['icon']),
      genre: asStringOrNull(m['genre']),
      mpaa: asStringOrNull(m['MPAA']),
      releaseDate: asStringOrNull(m['release_date']),
      plot: asStringOrNull(m['plot']),
      cast: asStringOrNull(m['cast']),
      duration: asStringOrNull(m['duration']),
      rating: asStringOrNull(m['rating']),
      year: asStringOrNull(m['year']),
      streamUrl: qualitiesFromJson(m['stream_url']),
    );
  }
}
