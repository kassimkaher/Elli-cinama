import '../../../core/utils/result.dart';
import 'entities.dart';
import 'repository.dart';

class GetShortEpg {
  final EpgRepository repo;
  GetShortEpg(this.repo);
  Future<Result<List<EpgListing>>> call(int streamId) => repo.getShortEpg(streamId);
}
