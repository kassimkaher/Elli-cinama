import '../../../core/network/request_builder.dart';
import '../../../core/utils/result.dart';
import 'entities.dart';
import 'repository.dart';

class GetLiveCategories {
  final LiveRepository repo;
  GetLiveCategories(this.repo);
  Future<Result<List<LiveCategory>>> call() => repo.getCategories();
}

class GetLiveChannels {
  final LiveRepository repo;
  GetLiveChannels(this.repo);
  Future<Result<List<LiveChannel>>> call() => repo.getChannels();
}

/// Resolves the playable live URL from the server-supplied template using
/// LITERAL {user}/{pass} replacement (Dart String.replaceAll on a String
/// pattern is literal for both pattern and replacement — no regex, unlike the
/// legacy Java client). Never logs the resolved URL.
class ResolveLiveStreamUrl {
  final CredentialSource credentials;
  ResolveLiveStreamUrl(this.credentials);

  String? call(LiveChannel channel) {
    final t = channel.streamUrlTemplate;
    if (t == null || t.isEmpty) return null;
    final u = credentials.username ?? '';
    final p = credentials.password ?? '';
    return t.replaceAll('{user}', u).replaceAll('{pass}', p);
  }
}
