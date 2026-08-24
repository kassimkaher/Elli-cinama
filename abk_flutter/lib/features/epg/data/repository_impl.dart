import '../../../core/utils/result.dart';
import '../domain/entities.dart';
import '../domain/repository.dart';
import 'datasource.dart';

class EpgRepositoryImpl implements EpgRepository {
  final EpgRemoteDataSource remote;
  EpgRepositoryImpl(this.remote);

  @override
  Future<Result<List<EpgListing>>> getShortEpg(int streamId) =>
      remote.getShortEpg(streamId);
}
