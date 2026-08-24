import '../../../core/utils/result.dart';
import 'entities.dart';

abstract class MovieRepository {
  Future<Result<List<MovieCategory>>> getCategories();
  Future<Result<List<MovieListItem>>> getMovies();
  Future<Result<MovieInfo>> getMovieInfo(String movieId);
}
