import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import '../domain/repository.dart';
import 'datasource.dart';

class LiveRepositoryImpl implements LiveRepository {
  final LiveRemoteDataSource remote;
  LiveRepositoryImpl(this.remote);

  @override
  Future<Result<List<LiveCategory>>> getCategories() => remote.getCategories();

  @override
  Future<Result<List<LiveChannel>>> getChannels() => remote.getChannels();
}
