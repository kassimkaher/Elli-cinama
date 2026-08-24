import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import '../domain/repository.dart';
import 'datasource.dart';

class SeriesRepositoryImpl implements SeriesRepository {
  final SeriesRemoteDataSource remote;
  SeriesRepositoryImpl(this.remote);

  @override
  Future<Result<List<SeriesCategory>>> getCategories() => remote.getCategories();

  @override
  Future<Result<List<SeriesListItem>>> getSeries() => remote.getSeries();

  @override
  Future<Result<SeriesInfo>> getSeriesInfo(String seriesId) => remote.getSeriesInfo(seriesId);
}
