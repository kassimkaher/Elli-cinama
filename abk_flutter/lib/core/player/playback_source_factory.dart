import '../config/app_config.dart';
import '../network/runtime_session.dart';
import 'playback_service.dart';

/// Builds [PlaybackSource]s with the correct streaming headers (User-Agent) and
/// a container hint. Never logs the URL.
class PlaybackSourceFactory {
  final RuntimeSession session;
  PlaybackSourceFactory(this.session);

  Map<String, String> get _headers {
    final ua = (session.roles.userAgent?.isNotEmpty ?? false)
        ? session.roles.userAgent!
        : AppConstants.defaultStreamingUserAgent;
    return {'User-Agent': ua};
  }

  PlaybackSource fromUrl(String url, {String? title}) => PlaybackSource(
        url: url,
        headers: _headers,
        container: detectContainer(url),
        title: title,
      );
}
