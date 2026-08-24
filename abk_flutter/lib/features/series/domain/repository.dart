import '../../../core/utils/result.dart';
import 'entities.dart';

abstract class SeriesRepository {
  Future<Result<List<SeriesCategory>>> getCategories();
  Future<Result<List<SeriesListItem>>> getSeries();
  Future<Result<SeriesInfo>> getSeriesInfo(String seriesId);
}
