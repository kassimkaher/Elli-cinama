import '../../../core/utils/result.dart';
import 'entities.dart';

abstract class EpgRepository {
  /// Returns listings; an empty list is a valid, expected result.
  Future<Result<List<EpgListing>>> getShortEpg(int streamId);
}
