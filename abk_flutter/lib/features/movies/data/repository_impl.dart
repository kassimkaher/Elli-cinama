import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import '../domain/repository.dart';
import 'datasource.dart';

class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource remote;
  MovieRepositoryImpl(this.remote);

  @override
  Future<Result<List<MovieCategory>>> getCategories() => remote.getCategories();

  @override
  Future<Result<List<MovieListItem>>> getMovies() => remote.getMovies();

  @override
  Future<Result<MovieInfo>> getMovieInfo(String movieId) => remote.getMovieInfo(movieId);
}
