import '../../../core/errors/failures.dart';
import '../../../core/network/content_client.dart';
import '../../../core/network/request_builder.dart';
import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import 'models.dart';

class MovieRemoteDataSource {
  final ContentClient client;
  final ContentRequestBuilder builder;

  MovieRemoteDataSource({required this.client, required this.builder});

  Future<Result<List<MovieCategory>>> getCategories() => client.callList(
        payload: builder.build('movies_cat'),
        itemDecoder: (j) => MovieModels.categoryFromJson(j as Map),
      );

  Future<Result<List<MovieListItem>>> getMovies() => client.callList(
        payload: builder.build('movies_list'),
        itemDecoder: (j) => MovieModels.listItemFromJson(j as Map),
      );

  /// movies_info returns an ARRAY; the client reads element [0].
  Future<Result<MovieInfo>> getMovieInfo(String movieId) async {
    final res = await client.callList<MovieInfo>(
      payload: builder.build('movies_info', extra: {'movie_id': movieId}),
      itemDecoder: (j) => MovieModels.infoFromJson(j as Map),
    );
    switch (res) {
      case Ok(:final value):
        if (value.isEmpty) {
          return Err(const EmptyResultFailure(message: 'No movie info returned'));
        }
        return Ok(value.first);
      case Err(:final failure):
        return Err(failure);
    }
  }
}
