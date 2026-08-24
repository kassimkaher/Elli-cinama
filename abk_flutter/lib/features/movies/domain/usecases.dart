import '../../../core/utils/result.dart';
import 'entities.dart';
import 'repository.dart';

class GetMovieCategories {
  final MovieRepository repo;
  GetMovieCategories(this.repo);
  Future<Result<List<MovieCategory>>> call() => repo.getCategories();
}

class GetMovies {
  final MovieRepository repo;
  GetMovies(this.repo);
  Future<Result<List<MovieListItem>>> call() => repo.getMovies();
}

class GetMovieInfo {
  final MovieRepository repo;
  GetMovieInfo(this.repo);
  Future<Result<MovieInfo>> call(String movieId) => repo.getMovieInfo(movieId);
}

/// Movie URL used verbatim (no {user}/{pass} substitution).
class SelectMovieQuality {
  String? call(MovieInfo info) => info.streamUrl.best;
}
