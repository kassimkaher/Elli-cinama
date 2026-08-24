class SeriesCategory {
  final String id;
  final String name;
  final String? icon;
  final int? streamCount;
  final String? catOrder;
  final String? parentId;
  final bool isLocked;

  const SeriesCategory({
    required this.id,
    required this.name,
    this.icon,
    this.streamCount,
    this.catOrder,
    this.parentId,
    this.isLocked = false,
  });
}

class SeriesListItem {
  final String id;
  final String title;
  final String? icon;
  final String? categoryId;
  final String? iconBig;
  final String? backdrop;
  final String? genre;
  final String? plot;
  final String? cast;
  final String? rating;
  final String? director;
  final String? releaseDate;
  final int? viewOrder;

  const SeriesListItem({
    required this.id,
    required this.title,
    this.icon,
    this.categoryId,
    this.iconBig,
    this.backdrop,
    this.genre,
    this.plot,
    this.cast,
    this.rating,
    this.director,
    this.releaseDate,
    this.viewOrder,
  });
}

class SeriesDetail {
  final String title;
  final String? plot;
  final String? cast;
  final String? genre;
  final String? rating;
  final String? director;
  final String? releaseDate;
  final String? trailer;
  final String? icon;
  final List<String> backdrops;

  const SeriesDetail({
    required this.title,
    this.plot,
    this.cast,
    this.genre,
    this.rating,
    this.director,
    this.releaseDate,
    this.trailer,
    this.icon,
    this.backdrops = const [],
  });
}

class Episode {
  final String? episodeNum;
  final String? episodeName;
  final String? streamUrl; // used verbatim

  const Episode({this.episodeNum, this.episodeName, this.streamUrl});
}

class Season {
  final int seasonNum;
  final List<Episode> episodes;
  const Season({required this.seasonNum, this.episodes = const []});
}

class SeriesInfo {
  final SeriesDetail? info;
  final List<Season> seasons;
  const SeriesInfo({this.info, this.seasons = const []});
}
