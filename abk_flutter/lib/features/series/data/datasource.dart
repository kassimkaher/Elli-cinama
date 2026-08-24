import '../../../core/network/content_client.dart';
import '../../../core/network/request_builder.dart';
import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import 'models.dart';

class SeriesRemoteDataSource {
  final ContentClient client;
  final ContentRequestBuilder builder;

  SeriesRemoteDataSource({required this.client, required this.builder});

  Future<Result<List<SeriesCategory>>> getCategories() => client.callList(
        payload: builder.build('series_cat'),
        itemDecoder: (j) => SeriesModels.categoryFromJson(j as Map),
      );

  Future<Result<List<SeriesListItem>>> getSeries() => client.callList(
        payload: builder.build('series_list'),
        itemDecoder: (j) => SeriesModels.listItemFromJson(j as Map),
      );

  /// series_info returns an OBJECT `{info, seasons[]}`.
  Future<Result<SeriesInfo>> getSeriesInfo(String seriesId) => client.callObject(
        payload: builder.build('series_info', extra: {'series_id': seriesId}),
        decoder: (j) => SeriesModels.infoFromJson(j as Map),
      );
}
