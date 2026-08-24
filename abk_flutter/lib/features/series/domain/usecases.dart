import '../../../core/utils/result.dart';
import 'entities.dart';
import 'repository.dart';

class GetSeriesCategories {
  final SeriesRepository repo;
  GetSeriesCategories(this.repo);
  Future<Result<List<SeriesCategory>>> call() => repo.getCategories();
}

class GetSeries {
  final SeriesRepository repo;
  GetSeries(this.repo);
  Future<Result<List<SeriesListItem>>> call() => repo.getSeries();
}

class GetSeriesInfo {
  final SeriesRepository repo;
  GetSeriesInfo(this.repo);
  Future<Result<SeriesInfo>> call(String seriesId) => repo.getSeriesInfo(seriesId);
}

/// Episode URL is used verbatim.
class ResolveEpisodeUrl {
  String? call(Episode episode) => episode.streamUrl;
}
