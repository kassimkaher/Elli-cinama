import '../../../core/network/content_client.dart';
import '../../../core/network/request_builder.dart';
import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import 'models.dart';

class LiveRemoteDataSource {
  final ContentClient client;
  final ContentRequestBuilder builder;

  LiveRemoteDataSource({required this.client, required this.builder});

  Future<Result<List<LiveCategory>>> getCategories() => client.callList(
        payload: builder.build('packages'),
        itemDecoder: (j) => LiveModels.categoryFromJson(j as Map),
      );

  Future<Result<List<LiveChannel>>> getChannels() => client.callList(
        payload: builder.build('channels'),
        itemDecoder: (j) => LiveModels.channelFromJson(j as Map),
      );
}
