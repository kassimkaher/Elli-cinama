class MovieCategory {
  final String id;
  final String name;
  final String? icon;
  final int? streamCount;
  final String? catOrder;
  final String? parentId;
  final bool isLocked;

  const MovieCategory({
    required this.id,
    required this.name,
    this.icon,
    this.streamCount,
    this.catOrder,
    this.parentId,
    this.isLocked = false,
  });
}

class MovieListItem {
  final String id;
  final String name;
  final String? categoryId;
  final String? icon;
  final String? backdrop;
  final String? plot;
  final String? rating;
  final String? genre;
  final String? cast;
  final String? year;
  final String? viewOrder;

  const MovieListItem({
    required this.id,
    required this.name,
    this.categoryId,
    this.icon,
    this.backdrop,
    this.plot,
    this.rating,
    this.genre,
    this.cast,
    this.year,
    this.viewOrder,
  });
}

/// movies_info `stream_url` is an OBJECT (not a string). Absent qualities are
/// "" (never null) per the contract.
class StreamQualities {
  final String? p480;
  final String? p720;
  final String? p1080;
  final String? p4k;

  const StreamQualities({this.p480, this.p720, this.p1080, this.p4k});

  /// Best available, preference 4k -> 1080p -> 720p -> 480p; used verbatim.
  String? get best {
    for (final q in [p4k, p1080, p720, p480]) {
      if (q != null && q.isNotEmpty) return q;
    }
    return null;
  }
}

class MovieInfo {
  final String? id;
  final String title;
  final String? trailer;
  final String? icon;
  final String? genre;
  final String? mpaa;
  final String? releaseDate;
  final String? plot;
  final String? cast;
  final String? duration;
  final String? rating;
  final String? year;
  final StreamQualities streamUrl;

  const MovieInfo({
    required this.id,
    required this.title,
    required this.streamUrl,
    this.trailer,
    this.icon,
    this.genre,
    this.mpaa,
    this.releaseDate,
    this.plot,
    this.cast,
    this.duration,
    this.rating,
    this.year,
  });
}
