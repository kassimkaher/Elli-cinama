import '../../../core/utils/result.dart';
import 'entities.dart';

abstract class LiveRepository {
  Future<Result<List<LiveCategory>>> getCategories();
  Future<Result<List<LiveChannel>>> getChannels();
}
